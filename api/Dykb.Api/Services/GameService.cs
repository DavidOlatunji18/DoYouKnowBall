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
    public const int DefaultLeaderboardSize = 10;

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

        var score = review.Count(r => r.Correct);
        var xp = Levels.ForRound(score, review.Count);
        var xpBefore = await TotalXpAsync(userId);

        var now = DateTime.UtcNow;
        var game = new GameSession
        {
            UserId = userId,
            CategoryId = attempt.CategoryId,
            Score = score,
            Total = review.Count,
            XpEarned = xp.Total,
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

        return new GameResultResponse(game.Id, game.Score, game.Total, review,
            xp, Levels.Progress(xpBefore), Levels.Progress(xpBefore + xp.Total));
    }

    public Task<List<HistoryItemDto>> GetHistoryAsync(int userId) =>
        db.GameSessions
            .Where(g => g.UserId == userId)
            .OrderByDescending(g => g.PlayedAt)
            .Take(HistoryLimit)
            .Select(g => new HistoryItemDto(g.Id, g.Category.Sport.Name, g.Category.Name, g.Score, g.Total, g.PlayedAt))
            .ToListAsync();

    public async Task<ProgressDto> GetProgressAsync(int userId) => Levels.Progress(await TotalXpAsync(userId));

    private Task<int> TotalXpAsync(int userId) =>
        db.GameSessions.Where(g => g.UserId == userId).SumAsync(g => g.XpEarned);

    /// <summary>
    /// The top players by XP, across all sports or in one (<paramref name="sportId"/>), plus the
    /// caller's own row. Players tied on XP share a rank (1, 2, 2, 4); more games played, then the
    /// name, decide the order within a tie. Levels shown are each player's overall level.
    /// </summary>
    public async Task<LeaderboardResponse> GetLeaderboardAsync(int userId, int? sportId, int top)
    {
        top = Math.Clamp(top, 1, MaxLeaderboardSize);
        if (sportId is int id && !await db.Sports.AnyAsync(s => s.Id == id))
            throw ApiException.NotFound("Sport not found.");

        var games = sportId is int sport
            ? db.GameSessions.Where(g => g.Category.SportId == sport)
            : db.GameSessions;
        var players = games
            .GroupBy(g => new { g.UserId, g.User.DisplayName })
            .Select(g => new
            {
                g.Key.UserId,
                g.Key.DisplayName,
                Xp = g.Sum(x => x.XpEarned),
                BestScore = g.Max(x => x.Score),
                GamesPlayed = g.Count(),
            });

        var topRows = await players
            .OrderByDescending(p => p.Xp)
            .ThenByDescending(p => p.GamesPlayed)
            .ThenBy(p => p.DisplayName)
            .Take(top)
            .ToListAsync();
        var mine = topRows.FirstOrDefault(p => p.UserId == userId)
            ?? await players.FirstOrDefaultAsync(p => p.UserId == userId);

        var ids = topRows.Select(p => p.UserId).Append(userId).ToList();
        var totalXp = await db.GameSessions
            .Where(g => ids.Contains(g.UserId))
            .GroupBy(g => g.UserId)
            .Select(g => new { UserId = g.Key, Xp = g.Sum(x => x.XpEarned) })
            .ToDictionaryAsync(x => x.UserId, x => x.Xp);

        LeaderboardEntryDto Entry(int rank, int user, string name, int xp, int best, int played)
        {
            var level = Levels.LevelFor(totalXp.GetValueOrDefault(user));
            return new LeaderboardEntryDto(rank, name, xp, level, Levels.RankFor(level),
                sportId is null ? null : best, played);
        }

        var entries = new List<LeaderboardEntryDto>(topRows.Count);
        for (var i = 0; i < topRows.Count; i++)
        {
            var row = topRows[i];
            var rank = i > 0 && row.Xp == topRows[i - 1].Xp ? entries[i - 1].Rank : i + 1;
            entries.Add(Entry(rank, row.UserId, row.DisplayName, row.Xp, row.BestScore, row.GamesPlayed));
        }

        LeaderboardEntryDto? me = null;
        if (mine is not null)
        {
            me = entries.FirstOrDefault(e => e.DisplayName == mine.DisplayName)
                ?? Entry(await players.CountAsync(p => p.Xp > mine.Xp) + 1,
                    mine.UserId, mine.DisplayName, mine.Xp, mine.BestScore, mine.GamesPlayed);
        }
        return new LeaderboardResponse(entries, me);
    }
}
