using Dykb.Api.Data;
using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Services;

public class GameService(AppDbContext db, QuizService quiz)
{
    private const int HistoryLimit = 50;
    private const int MaxLeaderboardSize = 100;

    /// <summary>
    /// Finishes a round, scored from the answers locked in by <see cref="QuizService.AnswerAsync"/>.
    /// Questions never answered count as wrong. A round can only be submitted once.
    /// </summary>
    public async Task<GameResultResponse> SubmitAsync(int userId, SubmitGameRequest request)
    {
        var attempt = await quiz.GetOpenAttemptAsync(userId, request.SessionToken);
        var served = attempt.ServedQuestionIds();

        var correctById = await db.Questions
            .Where(q => served.Contains(q.Id))
            .ToDictionaryAsync(q => q.Id, q => q.CorrectIndex);
        if (correctById.Count != served.Count)
            throw ApiException.BadRequest("Some questions in this quiz are no longer available. Please start a new one.");

        var locked = attempt.Answers.ToDictionary(a => a.QuestionId);
        // Indexes are positions as shown in this round's shuffled options.
        var review = served
            .Select(id =>
            {
                var shownCorrect = attempt.ShownIndexOf(id, correctById[id]);
                return locked.TryGetValue(id, out var a)
                    ? new ReviewItemDto(id, shownCorrect, a.SelectedIndex, a.Correct)
                    : new ReviewItemDto(id, shownCorrect, -1, false);
            })
            .ToList();

        var now = DateTime.UtcNow;
        var game = new GameSession
        {
            UserId = userId,
            CategoryId = attempt.CategoryId,
            Score = review.Count(r => r.Correct),
            Total = review.Count,
            PlayedAt = now,
        };
        db.GameSessions.Add(game);
        attempt.GameSession = game;
        attempt.SubmittedAt = now;

        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            // Another request submitted this round first; nothing from this one was saved.
            throw ApiException.Conflict("This quiz was already submitted.");
        }

        return new GameResultResponse(game.Id, game.Score, game.Total, review);
    }

    public Task<List<HistoryItemDto>> GetHistoryAsync(int userId) =>
        db.GameSessions
            .Where(g => g.UserId == userId)
            .OrderByDescending(g => g.PlayedAt)
            .Take(HistoryLimit)
            .Select(g => new HistoryItemDto(g.Id, g.Category.Sport.Name, g.Category.Name, g.Score, g.Total, g.PlayedAt))
            .ToListAsync();

    public async Task<List<LeaderboardEntryDto>> GetLeaderboardAsync(int sportId, int top)
    {
        top = Math.Clamp(top, 1, MaxLeaderboardSize);

        if (!await db.Sports.AnyAsync(s => s.Id == sportId))
            throw ApiException.NotFound("Sport not found.");

        var rows = await db.GameSessions
            .Where(g => g.Category.SportId == sportId)
            .GroupBy(g => new { g.UserId, g.User.DisplayName })
            .Select(g => new { g.Key.DisplayName, BestScore = g.Max(x => x.Score), GamesPlayed = g.Count() })
            .OrderByDescending(r => r.BestScore)
            .ThenByDescending(r => r.GamesPlayed)
            .ThenBy(r => r.DisplayName)
            .Take(top)
            .ToListAsync();

        // Standard competition ranking: players tied on best score share a rank (1, 2, 2, 4).
        var entries = new List<LeaderboardEntryDto>(rows.Count);
        for (var i = 0; i < rows.Count; i++)
        {
            var rank = i > 0 && rows[i].BestScore == rows[i - 1].BestScore ? entries[i - 1].Rank : i + 1;
            entries.Add(new LeaderboardEntryDto(rank, rows[i].DisplayName, rows[i].BestScore, rows[i].GamesPlayed));
        }
        return entries;
    }
}
