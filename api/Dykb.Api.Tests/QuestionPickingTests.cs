using System.Net.Http.Json;
using Dykb.Api.Dtos;
using Dykb.Api.Models;
using Dykb.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Tests;

/// <summary>How a round's questions are chosen and how their options are shuffled.</summary>
public class QuestionPickingTests : IDisposable
{
    private readonly ApiFactory _factory = new();

    public void Dispose() => _factory.Dispose();

    private static List<QuizService.PoolQuestion> Pool(int perDifficulty) =>
        Enumerable.Range(0, perDifficulty * 3)
            .Select(i => new QuizService.PoolQuestion(i + 1, 1 + i / perDifficulty))
            .ToList();

    [Fact]
    public void PickQuestions_MixesFourEasyFourMediumTwoHard()
    {
        for (var seed = 0; seed < 50; seed++)
        {
            var pool = Pool(perDifficulty: 20);
            var picked = QuizService.PickQuestions(pool, new HashSet<int>(), 10, new Random(seed));

            var byDifficulty = picked.Select(id => pool.Single(q => q.Id == id).Difficulty)
                .GroupBy(d => d).ToDictionary(g => g.Key, g => g.Count());
            Assert.Equal(10, picked.Distinct().Count());
            Assert.Equal(new Dictionary<int, int> { [1] = 4, [2] = 4, [3] = 2 }, byDifficulty);
        }
    }

    [Fact]
    public void PickQuestions_AvoidsRecentQuestionsWhileFreshOnesRemain()
    {
        var pool = Pool(perDifficulty: 20);
        // Half of every difficulty was just played.
        var recent = pool.Where(q => q.Id % 2 == 0).Select(q => q.Id).ToHashSet();

        for (var seed = 0; seed < 50; seed++)
        {
            var picked = QuizService.PickQuestions(pool, recent, 10, new Random(seed));
            Assert.DoesNotContain(picked, recent.Contains);
        }
    }

    [Fact]
    public void PickQuestions_ReusesRecentQuestionsRatherThanCuttingTheRoundShort()
    {
        var pool = Pool(perDifficulty: 4);  // 12 questions
        var recent = pool.Take(10).Select(q => q.Id).ToHashSet();

        var picked = QuizService.PickQuestions(pool, recent, 10, new Random(1));

        Assert.Equal(10, picked.Distinct().Count());
        // Both fresh questions made it in.
        Assert.Contains(11, picked);
        Assert.Contains(12, picked);
    }

    [Fact]
    public void PickQuestions_TopsUpFromOtherDifficultiesWhenOneRunsShort()
    {
        // No hard questions at all.
        var pool = Enumerable.Range(1, 20).Select(i => new QuizService.PoolQuestion(i, 1 + i % 2)).ToList();

        var picked = QuizService.PickQuestions(pool, new HashSet<int>(), 10, new Random(3));

        Assert.Equal(10, picked.Distinct().Count());
    }

    [Fact]
    public async Task Quiz_NextRoundAvoidsTheQuestionsYouJustSaw()
    {
        var category = await _factory.SeedCategoryAsync(questionCount: 60);
        var client = await _factory.CreateAuthenticatedClientAsync();

        var first = await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}");
        var second = await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}");

        Assert.Empty(first!.Questions.Select(q => q.Id).Intersect(second!.Questions.Select(q => q.Id)));
    }

    [Fact]
    public async Task Quiz_OtherPlayersRoundsDontAffectYours()
    {
        var category = await _factory.SeedCategoryAsync(questionCount: 10);
        var you = await _factory.CreateAuthenticatedClientAsync();
        var someoneElse = await _factory.CreateAuthenticatedClientAsync();

        await someoneElse.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}");
        var quiz = await you.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}");

        Assert.Equal(10, quiz!.Questions.Count);
    }

    [Fact]
    public async Task Quiz_ShufflesOptionsAndScoresByWhatWasShown()
    {
        var category = await _factory.WithDbAsync(async db =>
        {
            var c = new Category { Sport = new Sport { Name = "NFL" }, Name = "Players" };
            c.Questions.Add(new Question
            {
                Text = "Most Super Bowl wins by a quarterback?",
                Option1 = "Joe Montana", Option2 = "Tom Brady", Option3 = "Terry Bradshaw", Option4 = "Patrick Mahomes",
                CorrectIndex = 1,
                Difficulty = 1,
            });
            db.Categories.Add(c);
            await db.SaveChangesAsync();
            return c;
        });
        var client = await _factory.CreateAuthenticatedClientAsync();

        var positions = new HashSet<int>();
        for (var round = 0; round < 24; round++)
        {
            var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
            var question = Assert.Single(quiz.Questions);
            Assert.Equal(["Joe Montana", "Patrick Mahomes", "Terry Bradshaw", "Tom Brady"], question.Options.Order());

            var shown = Array.IndexOf(question.Options, "Tom Brady");
            positions.Add(shown);

            var response = await client.PostAsJsonAsync("/quiz/answer", new AnswerRequest(quiz.SessionToken, question.Id, shown));
            var result = (await response.Content.ReadFromJsonAsync<AnswerResultDto>())!;
            Assert.True(result.Correct);
            Assert.Equal(shown, result.CorrectIndex);

            var game = (await (await client.PostAsJsonAsync("/games", new SubmitGameRequest(quiz.SessionToken)))
                .Content.ReadFromJsonAsync<GameResultResponse>())!;
            var review = Assert.Single(game.Review);
            Assert.Equal(shown, review.CorrectIndex);
            Assert.Equal(shown, review.SelectedIndex);
        }

        // Over 24 rounds the right answer should have moved around (odds of it never
        // moving are about 1 in 10^14).
        Assert.True(positions.Count > 1, "Tom Brady was always shown in the same position");
    }

    [Fact]
    public async Task Quiz_WrongPickReportsWhereTheRightAnswerWasShown()
    {
        var category = await _factory.SeedCategoryAsync(questionCount: 10);
        var client = await _factory.CreateAuthenticatedClientAsync();
        var quiz = (await client.GetFromJsonAsync<QuizResponse>($"/quiz?categoryId={category.Id}"))!;
        var question = quiz.Questions[0];
        var correctText = await _factory.WithDbAsync(db => db.Questions
            .Where(q => q.Id == question.Id)
            .Select(q => new[] { q.Option1, q.Option2, q.Option3, q.Option4 }[q.CorrectIndex])
            .SingleAsync());
        var shown = Array.IndexOf(question.Options, correctText);

        var response = await client.PostAsJsonAsync("/quiz/answer", new AnswerRequest(quiz.SessionToken, question.Id, (shown + 1) % 4));
        var result = (await response.Content.ReadFromJsonAsync<AnswerResultDto>())!;

        Assert.False(result.Correct);
        Assert.Equal(shown, result.CorrectIndex);
    }
}
