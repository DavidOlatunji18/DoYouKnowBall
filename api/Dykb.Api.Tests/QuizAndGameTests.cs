using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Dykb.Api.Dtos;
using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Tests;

public class QuizAndGameTests : IDisposable
{
    private readonly ApiFactory _factory = new();

    public void Dispose() => _factory.Dispose();

    [Fact]
    public async Task SportsAndCategories_ListSeededData()
    {
        var category = await _factory.SeedCategoryAsync("NBA", "History");
        await _factory.SeedCategoryAsync("NBA", "Players");
        var client = await _factory.CreateAuthenticatedClientAsync();

        var sports = await client.GetFromJsonAsync<List<SportDto>>("/sports");
        var categories = await client.GetFromJsonAsync<List<CategoryDto>>($"/sports/{category.SportId}/categories");

        Assert.Equal("NBA", Assert.Single(sports!).Name);
        Assert.Equal(["History", "Players"], categories!.Select(c => c.Name));
        Assert.All(categories!, c => Assert.Equal(category.SportId, c.SportId));
    }

    [Fact]
    public async Task Categories_UnknownSport_Returns404()
    {
        var client = await _factory.CreateAuthenticatedClientAsync();

        var response = await client.GetAsync("/sports/999/categories");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("Sport not found.", (await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Fact]
    public async Task Quiz_ReturnsQuestionsWithoutAnswers()
    {
        var category = await _factory.SeedCategoryAsync(questionCount: 15);
        var client = await _factory.CreateAuthenticatedClientAsync();

        var response = await client.GetAsync($"/quiz?categoryId={category.Id}&count=10");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("correct", json, StringComparison.OrdinalIgnoreCase);

        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        Assert.Equal(["sessionToken", "questions"], root.EnumerateObject().Select(p => p.Name));
        var questions = root.GetProperty("questions").EnumerateArray().ToList();
        Assert.Equal(10, questions.Count);
        Assert.Equal(10, questions.Select(q => q.GetProperty("id").GetInt32()).Distinct().Count());
        Assert.All(questions, q =>
        {
            Assert.Equal(["id", "text", "options"], q.EnumerateObject().Select(p => p.Name));
            Assert.Equal(4, q.GetProperty("options").GetArrayLength());
        });
    }

    [Fact]
    public async Task Quiz_CountIsCappedAtTen()
    {
        var category = await _factory.SeedCategoryAsync(questionCount: 30);
        var client = await _factory.CreateAuthenticatedClientAsync();

        var quiz = await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}&count=25");

        Assert.Equal(10, quiz!.Questions.Count);
    }

    [Fact]
    public async Task Quiz_MissingCategoryId_Returns400()
    {
        var client = await _factory.CreateAuthenticatedClientAsync();

        var response = await client.GetAsync("/quiz");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.NotNull((await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Fact]
    public async Task Answer_GivesInstantFeedbackAndARunningScore()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        var correct = await CorrectIndexesAsync(quiz);
        var first = quiz.Questions[0].Id;
        var second = quiz.Questions[1].Id;

        var right = await AnswerAsync(client, quiz, first, correct[first]);
        var wrong = await AnswerAsync(client, quiz, second, (correct[second] + 1) % 4);

        Assert.Equal(new AnswerResultDto(true, correct[first], Score: 1, Answered: 1, Total: 10), right);
        Assert.Equal(new AnswerResultDto(false, correct[second], Score: 1, Answered: 2, Total: 10), wrong);
    }

    [Fact]
    public async Task Answer_IsLockedIn_SecondAttemptReturns409()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        var correct = await CorrectIndexesAsync(quiz);
        var question = quiz.Questions[0].Id;

        await AnswerAsync(client, quiz, question, (correct[question] + 1) % 4);  // wrong, and now we know the answer
        var retry = await client.PostAsJsonAsync("/quiz/answer", new AnswerRequest(quiz.SessionToken, question, correct[question]));

        Assert.Equal(HttpStatusCode.Conflict, retry.StatusCode);
        var game = await SubmitAsync(client, quiz);
        Assert.Equal(0, game.Score);
    }

    [Fact]
    public async Task Answer_RecordsServerMeasuredTime()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;

        await Task.Delay(60);
        await AnswerAsync(client, quiz, quiz.Questions[0].Id, 0);

        var answer = await _factory.WithDbAsync(db => db.QuizAnswers.SingleAsync());
        Assert.InRange(answer.ElapsedMs, 50, 10_000);
    }

    [Fact]
    public async Task Answer_ForQuestionNotInQuiz_Returns400()
    {
        var category = await _factory.SeedCategoryAsync(questionCount: 20);
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        var servedIds = quiz.Questions.Select(q => q.Id).ToHashSet();
        var otherId = await _factory.WithDbAsync(db => db.Questions.Where(q => !servedIds.Contains(q.Id)).Select(q => q.Id).FirstAsync());

        var response = await client.PostAsJsonAsync("/quiz/answer", new AnswerRequest(quiz.SessionToken, otherId, 0));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("That question isn't part of this quiz.", (await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Fact]
    public async Task Answer_SelectedIndexOutOfRange_Returns400()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;

        var response = await client.PostAsJsonAsync("/quiz/answer", new AnswerRequest(quiz.SessionToken, quiz.Questions[0].Id, 4));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData("/quiz/answer")]
    [InlineData("/games")]
    public async Task AnotherPlayersQuiz_IsRejected(string path)
    {
        var category = await _factory.SeedCategoryAsync();
        var alice = await _factory.CreateAuthenticatedClientAsync("alice");
        var bob = await _factory.CreateAuthenticatedClientAsync("bob");
        var quiz = (await alice.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;

        var response = path == "/games"
            ? await bob.PostAsJsonAsync(path, new SubmitGameRequest(quiz.SessionToken))
            : await bob.PostAsJsonAsync(path, new AnswerRequest(quiz.SessionToken, quiz.Questions[0].Id, 0));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("expired", (await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Fact]
    public async Task UnknownSessionToken_Returns400()
    {
        var client = await _factory.CreateAuthenticatedClientAsync();

        var response = await client.PostAsJsonAsync("/games", new SubmitGameRequest("not-a-real-token"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task SubmitGame_ScoresFromLockedAnswersAndSavesHistory()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        var correct = await CorrectIndexesAsync(quiz);

        // First 7 right, next 2 wrong, last one never answered.
        for (var i = 0; i < 9; i++)
        {
            var id = quiz.Questions[i].Id;
            await AnswerAsync(client, quiz, id, i < 7 ? correct[id] : (correct[id] + 1) % 4);
        }
        var result = await SubmitAsync(client, quiz);

        Assert.Equal(7, result.Score);
        Assert.Equal(10, result.Total);
        Assert.Equal(quiz.Questions.Select(q => q.Id), result.Review.Select(r => r.QuestionId));
        Assert.All(result.Review, r => Assert.Equal(correct[r.QuestionId], r.CorrectIndex));
        var unanswered = result.Review.Last();
        Assert.Equal(-1, unanswered.SelectedIndex);
        Assert.False(unanswered.Correct);

        var history = (await client.GetFromJsonAsync<List<HistoryItemDto>>("/games/history"))!;
        var entry = Assert.Single(history);
        Assert.Equal(result.GameId, entry.GameId);
        Assert.Equal("NBA", entry.SportName);
        Assert.Equal("History", entry.CategoryName);
        Assert.Equal(7, entry.Score);
        Assert.Equal(DateTimeKind.Utc, entry.PlayedAt.Kind);
    }

    [Fact]
    public async Task SubmitGame_Twice_Returns409AndCountsOnce()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        await SubmitAsync(client, quiz);

        var again = await client.PostAsJsonAsync("/games", new SubmitGameRequest(quiz.SessionToken));
        var lateAnswer = await client.PostAsJsonAsync("/quiz/answer", new AnswerRequest(quiz.SessionToken, quiz.Questions[0].Id, 0));

        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, lateAnswer.StatusCode);
        Assert.Equal(1, await _factory.WithDbAsync(db => db.GameSessions.CountAsync()));
    }

    [Fact]
    public async Task Leaderboard_OrdersByBestScorePerSport()
    {
        var nba = await _factory.SeedCategoryAsync("NBA", "History");
        var nfl = await _factory.SeedCategoryAsync("NFL", "History");

        var low = await _factory.CreateAuthenticatedClientAsync("LowScore");
        var high = await _factory.CreateAuthenticatedClientAsync("HighScore");
        var mid = await _factory.CreateAuthenticatedClientAsync("MidScore");
        var nflOnly = await _factory.CreateAuthenticatedClientAsync("NflOnly");

        await PlayAsync(low, nba.Id, correctCount: 3);
        await PlayAsync(high, nba.Id, correctCount: 9);
        await PlayAsync(high, nba.Id, correctCount: 2);   // a worse later game must not lower the best score
        await PlayAsync(mid, nba.Id, correctCount: 6);
        await PlayAsync(nflOnly, nfl.Id, correctCount: 10);

        var board = (await low.GetFromJsonAsync<List<LeaderboardEntryDto>>($"/leaderboard?sportId={nba.SportId}&top=20"))!;

        Assert.Equal(["highscore", "midscore", "lowscore"], board.Select(e => e.DisplayName));
        Assert.Equal([1, 2, 3], board.Select(e => e.Rank));
        Assert.Equal([9, 6, 3], board.Select(e => e.BestScore));
        Assert.Equal([2, 1, 1], board.Select(e => e.GamesPlayed));
    }

    [Fact]
    public async Task Leaderboard_TiedScoresShareRank_AndTopLimitsResults()
    {
        var category = await _factory.SeedCategoryAsync();
        foreach (var (name, score) in new[] { ("Ann", 8), ("Ben", 8), ("Cal", 5) })
            await PlayAsync(await _factory.CreateAuthenticatedClientAsync(name), category.Id, score);
        var client = await _factory.CreateAuthenticatedClientAsync();

        var full = (await client.GetFromJsonAsync<List<LeaderboardEntryDto>>($"/leaderboard?sportId={category.SportId}"))!;
        var top2 = (await client.GetFromJsonAsync<List<LeaderboardEntryDto>>($"/leaderboard?sportId={category.SportId}&top=2"))!;

        Assert.Equal([1, 1, 3], full.Select(e => e.Rank));
        Assert.Equal(2, top2.Count);
    }

    /// <summary>
    /// Where each question's correct option was shown in this round. Options are shuffled per
    /// round, so this finds the correct option's text among the options the player was sent.
    /// </summary>
    private async Task<Dictionary<int, int>> CorrectIndexesAsync(QuizResponse quiz)
    {
        var ids = quiz.Questions.Select(q => q.Id).ToList();
        var correctText = await _factory.WithDbAsync(db => db.Questions
            .Where(q => ids.Contains(q.Id))
            .ToDictionaryAsync(q => q.Id, q => new[] { q.Option1, q.Option2, q.Option3, q.Option4 }[q.CorrectIndex]));
        return quiz.Questions.ToDictionary(q => q.Id, q => Array.IndexOf(q.Options, correctText[q.Id]));
    }

    private static async Task<AnswerResultDto> AnswerAsync(HttpClient client, QuizResponse quiz, int questionId, int selectedIndex)
    {
        var response = await client.PostAsJsonAsync("/quiz/answer", new AnswerRequest(quiz.SessionToken, questionId, selectedIndex));
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AnswerResultDto>())!;
    }

    private static async Task<GameResultResponse> SubmitAsync(HttpClient client, QuizResponse quiz)
    {
        var response = await client.PostAsJsonAsync("/games", new SubmitGameRequest(quiz.SessionToken));
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<GameResultResponse>())!;
    }

    private async Task PlayAsync(HttpClient client, int categoryId, int correctCount)
    {
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={categoryId}"))!;
        var correct = await CorrectIndexesAsync(quiz);
        for (var i = 0; i < quiz.Questions.Count; i++)
        {
            var id = quiz.Questions[i].Id;
            await AnswerAsync(client, quiz, id, i < correctCount ? correct[id] : (correct[id] + 1) % 4);
        }
        await SubmitAsync(client, quiz);
    }
}
