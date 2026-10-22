using Dykb.Api.Data;
using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Services;

public class GameService(AppDbContext db, QuizSessionTokens sessionTokens)
{
    private const int HistoryLimit = 50;
    private const int MaxLeaderboardSize = 100;

    public async Task<GameResultResponse> SubmitAsync(int userId, SubmitGameRequest request)
    {
        var session = sessionTokens.Read(request.SessionToken)
            ?? throw ApiException.BadRequest("This quiz has expired. Please start a new one.");
        if (session.UserId != userId || session.CategoryId != request.CategoryId)
            throw ApiException.BadRequest("These answers don't match the quiz you were given.");

        var served = session.QuestionIds;
        var answers = request.Answers
            .GroupBy(a => a.QuestionId)
            .ToDictionary(g => g.Key, g => g.Count() == 1 ? g.Single().SelectedIndex : -1);
        if (answers.Count != served.Count || answers.Values.Contains(-1) || !served.All(answers.ContainsKey))
            throw ApiException.BadRequest("Answer each question in the quiz exactly once.");

        var correctById = await db.Questions
            .Where(q => served.Contains(q.Id))
            .ToDictionaryAsync(q => q.Id, q => q.CorrectIndex);
        if (correctById.Count != served.Count)
            throw ApiException.BadRequest("Some questions in this quiz are no longer available. Please start a new one.");

        var review = served
            .Select(id => new ReviewItemDto(id, correctById[id], answers[id], correctById[id] == answers[id]))
            .ToList();

        var game = new GameSession
        {
            UserId = userId,
            CategoryId = session.CategoryId,
            Score = review.Count(r => r.Correct),
            Total = review.Count,
            PlayedAt = DateTime.UtcNow,
        };
        db.GameSessions.Add(game);
        await db.SaveChangesAsync();

        return new GameResultResponse(game.Id, game.Score, game.Total, review);
    }

    public Task<List<HistoryItemDto>> GetHistoryAsync(int userId) =>
        db.GameSessions
            .Where(g => g.UserId == userId)
            .OrderByDescending(g => g.PlayedAt)
            .Take(HistoryLimit)
            .Select(g => new HistoryItemDto(g.Id, g.Category.Name, g.Score, g.Total, g.PlayedAt))
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
