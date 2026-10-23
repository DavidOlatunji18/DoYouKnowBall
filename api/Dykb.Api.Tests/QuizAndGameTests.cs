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
    public async Task SubmitGame_ScoresServerSideAndSavesHistory()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        var correct = await CorrectIndexesAsync(quiz);

        // Answer the first 7 correctly and the last 3 wrong.
        var answers = quiz.Questions
            .Select((q, i) => new AnswerDto(q.Id, i < 7 ? correct[q.Id] : (correct[q.Id] + 1) % 4))
            .ToList();
        var response = await client.PostAsJsonAsync("/games", new SubmitGameRequest(category.Id, quiz.SessionToken, answers));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var result = (await response.Content.ReadFromJsonAsync<GameResultResponse>())!;
        Assert.Equal(7, result.Score);
        Assert.Equal(10, result.Total);
        Assert.Equal(quiz.Questions.Select(q => q.Id), result.Review.Select(r => r.QuestionId));
        Assert.All(result.Review, r =>
        {
            Assert.Equal(correct[r.QuestionId], r.CorrectIndex);
            Assert.Equal(answers.Single(a => a.QuestionId == r.QuestionId).SelectedIndex, r.SelectedIndex);
            Assert.Equal(r.CorrectIndex == r.SelectedIndex, r.Correct);
        });

        var history = (await client.GetFromJsonAsync<List<HistoryItemDto>>("/games/history"))!;
        var entry = Assert.Single(history);
        Assert.Equal(result.GameId, entry.GameId);
        Assert.Equal("History", entry.CategoryName);
        Assert.Equal(7, entry.Score);
        Assert.Equal(10, entry.Total);
        Assert.Equal(DateTimeKind.Utc, entry.PlayedAt.Kind);
    }

    [Fact]
    public async Task SubmitGame_AnswersForQuestionsNotInQuiz_Returns400()
    {
        var category = await _factory.SeedCategoryAsync(questionCount: 20);
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        var servedIds = quiz.Questions.Select(q => q.Id).ToHashSet();
        var otherIds = await _factory.WithDbAsync(db => db.Questions
            .Where(q => !servedIds.Contains(q.Id)).Select(q => q.Id).Take(10).ToListAsync());

        var response = await client.PostAsJsonAsync("/games", new SubmitGameRequest(
            category.Id, quiz.SessionToken, otherIds.Select(id => new AnswerDto(id, 0)).ToList()));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, await _factory.WithDbAsync(db => db.GameSessions.CountAsync()));
    }

    [Fact]
    public async Task SubmitGame_WithAnotherUsersSessionToken_Returns400()
    {
        var category = await _factory.SeedCategoryAsync();
        var alice = await _factory.CreateAuthenticatedClientAsync("Alice");
        var bob = await _factory.CreateAuthenticatedClientAsync("Bob");
        var quiz = (await alice.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;

        var response = await bob.PostAsJsonAsync("/games", new SubmitGameRequest(
            category.Id, quiz.SessionToken, quiz.Questions.Select(q => new AnswerDto(q.Id, 0)).ToList()));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task SubmitGame_TamperedSessionToken_Returns400()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;

        var response = await client.PostAsJsonAsync("/games", new SubmitGameRequest(
            category.Id, quiz.SessionToken + "x", quiz.Questions.Select(q => new AnswerDto(q.Id, 0)).ToList()));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("expired", (await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Fact]
    public async Task SubmitGame_SelectedIndexOutOfRange_Returns400()
    {
        var category = await _factory.SeedCategoryAsync();
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;

        var response = await client.PostAsJsonAsync("/games", new SubmitGameRequest(
            category.Id, quiz.SessionToken, quiz.Questions.Select(q => new AnswerDto(q.Id, 4)).ToList()));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
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

    private Task<Dictionary<int, int>> CorrectIndexesAsync(QuizResponse quiz)
    {
        var ids = quiz.Questions.Select(q => q.Id).ToList();
        return _factory.WithDbAsync(db => db.Questions
            .Where(q => ids.Contains(q.Id))
            .ToDictionaryAsync(q => q.Id, q => q.CorrectIndex));
    }

    private async Task PlayAsync(HttpClient client, int categoryId, int correctCount)
    {
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={categoryId}"))!;
        var correct = await CorrectIndexesAsync(quiz);
        var answers = quiz.Questions
            .Select((q, i) => new AnswerDto(q.Id, i < correctCount ? correct[q.Id] : (correct[q.Id] + 1) % 4))
            .ToList();
        var response = await client.PostAsJsonAsync("/games", new SubmitGameRequest(categoryId, quiz.SessionToken, answers));
        response.EnsureSuccessStatusCode();
    }
}
