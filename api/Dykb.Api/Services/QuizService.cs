using Dykb.Api.Data;
using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Services;

public class QuizService(AppDbContext db)
{
    public const int MaxQuestionsPerQuiz = 10;

    /// <summary>A round must be finished within this long of starting it.</summary>
    public static readonly TimeSpan AttemptLifetime = TimeSpan.FromHours(1);

    public Task<List<SportDto>> GetSportsAsync() =>
        db.Sports
            .OrderBy(s => s.Name)
            .Select(s => new SportDto(s.Id, s.Name))
            .ToListAsync();

    public async Task<List<CategoryDto>> GetCategoriesAsync(int sportId)
    {
        if (!await db.Sports.AnyAsync(s => s.Id == sportId))
            throw ApiException.NotFound("Sport not found.");

        return await db.Categories
            .Where(c => c.SportId == sportId)
            .OrderBy(c => c.Name)
            .Select(c => new CategoryDto(c.Id, c.Name, c.SportId))
            .ToListAsync();
    }

    /// <summary>Starts a round: picks random questions and records them as a new attempt.</summary>
    public async Task<QuizResponse> CreateQuizAsync(int userId, int categoryId, int count)
    {
        count = Math.Clamp(count, 1, MaxQuestionsPerQuiz);

        if (!await db.Categories.AnyAsync(c => c.Id == categoryId))
            throw ApiException.NotFound("Category not found.");

        // Guid.NewGuid() translates to NEWID() on SQL Server, giving a fresh random order per query.
        var questions = await db.Questions
            .Where(q => q.CategoryId == categoryId)
            .OrderBy(q => Guid.NewGuid())
            .Take(count)
            .Select(q => new QuizQuestionDto(q.Id, q.Text, new[] { q.Option1, q.Option2, q.Option3, q.Option4 }))
            .ToListAsync();

        if (questions.Count == 0)
            throw ApiException.NotFound("This category has no questions yet.");

        var now = DateTime.UtcNow;
        var attempt = new QuizAttempt
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CategoryId = categoryId,
            QuestionIds = string.Join(',', questions.Select(q => q.Id)),
            CreatedAt = now,
            LastActivityAt = now,
        };
        db.QuizAttempts.Add(attempt);
        await db.SaveChangesAsync();

        return new QuizResponse(attempt.Id.ToString("N"), questions);
    }

    /// <summary>
    /// Checks one answer, locks it in, and says whether it was right. The time taken is
    /// measured on the server from when the question became current.
    /// </summary>
    public async Task<AnswerResultDto> AnswerAsync(int userId, AnswerRequest request)
    {
        var attempt = await GetOpenAttemptAsync(userId, request.SessionToken);
        var served = attempt.ServedQuestionIds();

        if (!served.Contains(request.QuestionId))
            throw ApiException.BadRequest("That question isn't part of this quiz.");
        if (attempt.Answers.Any(a => a.QuestionId == request.QuestionId))
            throw ApiException.Conflict("You already answered that question.");

        var correctIndex = await db.Questions
            .Where(q => q.Id == request.QuestionId)
            .Select(q => (int?)q.CorrectIndex)
            .SingleOrDefaultAsync()
            ?? throw ApiException.BadRequest("That question is no longer available. Please start a new quiz.");

        var now = DateTime.UtcNow;
        var answer = new QuizAnswer
        {
            QuestionId = request.QuestionId,
            SelectedIndex = request.SelectedIndex,
            Correct = request.SelectedIndex == correctIndex,
            AnsweredAt = now,
            ElapsedMs = (int)Math.Clamp((now - attempt.LastActivityAt).TotalMilliseconds, 0, int.MaxValue),
        };
        attempt.Answers.Add(answer);
        attempt.LastActivityAt = now;

        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // The same answer sent twice at once: the unique index lets only one in.
            throw ApiException.Conflict("You already answered that question.");
        }

        return new AnswerResultDto(
            answer.Correct,
            correctIndex,
            Score: attempt.Answers.Count(a => a.Correct),
            Answered: attempt.Answers.Count,
            Total: served.Count);
    }

    /// <summary>
    /// The player's own unfinished, unexpired round. Anything else (unknown token, someone
    /// else's round, too old) gets the same message, so tokens can't be probed.
    /// </summary>
    public async Task<QuizAttempt> GetOpenAttemptAsync(int userId, string sessionToken)
    {
        var expired = ApiException.BadRequest("This quiz has expired. Please start a new one.");
        if (!Guid.TryParse(sessionToken, out var id))
            throw expired;

        var attempt = await db.QuizAttempts
            .Include(a => a.Answers)
            .SingleOrDefaultAsync(a => a.Id == id && a.UserId == userId);

        if (attempt is null || DateTime.UtcNow - attempt.CreatedAt > AttemptLifetime)
            throw expired;
        if (attempt.SubmittedAt is not null)
            throw ApiException.Conflict("This quiz was already submitted.");
        return attempt;
    }
}
