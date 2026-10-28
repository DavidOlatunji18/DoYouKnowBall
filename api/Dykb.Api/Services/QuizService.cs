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

    /// <summary>Questions from the player's last few rounds in a category are held back when possible.</summary>
    public const int RecentRoundsToAvoid = 3;

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

    /// <summary>
    /// Starts a round and records it as a new attempt. The questions are a random, balanced
    /// mix (see <see cref="PickQuestions"/>) that avoids the player's recent rounds when the
    /// pool allows, and each question's options are shuffled so answers can't be learned by
    /// position.
    /// </summary>
    public async Task<QuizResponse> CreateQuizAsync(int userId, int categoryId, int count)
    {
        count = Math.Clamp(count, 1, MaxQuestionsPerQuiz);

        if (!await db.Categories.AnyAsync(c => c.Id == categoryId))
            throw ApiException.NotFound("Category not found.");

        // A category holds about a hundred questions, so picking in memory is cheap.
        var pool = await db.Questions
            .Where(q => q.CategoryId == categoryId)
            .Select(q => new PoolQuestion(q.Id, q.Difficulty))
            .ToListAsync();
        if (pool.Count == 0)
            throw ApiException.NotFound("This category has no questions yet.");

        var recentIds = await db.QuizAttempts
            .Where(a => a.UserId == userId && a.CategoryId == categoryId)
            .OrderByDescending(a => a.CreatedAt)
            .Take(RecentRoundsToAvoid)
            .Select(a => a.QuestionIds)
            .ToListAsync();
        var recent = recentIds
            .SelectMany(ids => ids.Split(',', StringSplitOptions.RemoveEmptyEntries))
            .Select(int.Parse)
            .ToHashSet();

        var pickedIds = PickQuestions(pool, recent, count, Random.Shared);
        var byId = await db.Questions
            .Where(q => pickedIds.Contains(q.Id))
            .ToDictionaryAsync(q => q.Id);

        var questions = new List<QuizQuestionDto>();
        var orders = new List<int[]>();
        foreach (var id in pickedIds)
        {
            var q = byId[id];
            string[] stored = [q.Option1, q.Option2, q.Option3, q.Option4];
            var order = Shuffled([0, 1, 2, 3], Random.Shared);
            orders.Add(order);
            questions.Add(new QuizQuestionDto(q.Id, q.Text, order.Select(i => stored[i]).ToArray()));
        }

        var now = DateTime.UtcNow;
        var attempt = new QuizAttempt
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CategoryId = categoryId,
            QuestionIds = string.Join(',', pickedIds),
            OptionOrders = string.Join(',', orders.Select(o => string.Concat(o))),
            CreatedAt = now,
            LastActivityAt = now,
        };
        db.QuizAttempts.Add(attempt);
        await db.SaveChangesAsync();

        return new QuizResponse(attempt.Id.ToString("N"), questions);
    }

    public record PoolQuestion(int Id, int Difficulty);

    /// <summary>
    /// Picks <paramref name="count"/> question ids at random, aiming for 40% easy, 40% medium
    /// and 20% hard (4/4/2 in a round of 10). Within each difficulty, questions in
    /// <paramref name="recent"/> are only used once the fresh ones run out; a difficulty that
    /// runs short is topped up from the others, so the round is full whenever the pool is.
    /// </summary>
    public static List<int> PickQuestions(
        IReadOnlyList<PoolQuestion> pool, IReadOnlySet<int> recent, int count, Random random)
    {
        var hard = (int)Math.Round(count * 0.2);
        var easy = (int)Math.Round(count * 0.4);
        var targets = new Dictionary<int, int> { [1] = easy, [2] = count - easy - hard, [3] = hard };

        var fresh = Shuffled(pool.Where(q => !recent.Contains(q.Id)).ToArray(), random);
        var seen = Shuffled(pool.Where(q => recent.Contains(q.Id)).ToArray(), random);
        var picked = new List<PoolQuestion>();

        // 1. Fill each difficulty's quota from fresh questions, then from recent ones.
        foreach (var q in fresh.Concat(seen))
        {
            if (targets.GetValueOrDefault(q.Difficulty) > 0 && picked.Count < count)
            {
                picked.Add(q);
                targets[q.Difficulty]--;
            }
        }
        // 2. A difficulty ran short: top up with whatever is left, fresh before recent.
        foreach (var q in fresh.Concat(seen))
        {
            if (picked.Count == count) break;
            if (!picked.Contains(q)) picked.Add(q);
        }

        return Shuffled(picked.ToArray(), random).Select(q => q.Id).ToList();
    }

    private static T[] Shuffled<T>(T[] items, Random random)
    {
        var copy = (T[])items.Clone();
        random.Shuffle(copy);
        return copy;
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

        var storedCorrect = await db.Questions
            .Where(q => q.Id == request.QuestionId)
            .Select(q => (int?)q.CorrectIndex)
            .SingleOrDefaultAsync()
            ?? throw ApiException.BadRequest("That question is no longer available. Please start a new quiz.");
        // The player picks a position in their shuffled options; compare it with where the
        // correct option was shown.
        var correctIndex = attempt.ShownIndexOf(request.QuestionId, storedCorrect);

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
