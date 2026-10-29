using System.ComponentModel.DataAnnotations;

namespace Dykb.Api.Dtos;

public record AnswerRequest(
    [Required] string SessionToken,
    int QuestionId,
    [Range(0, 3, ErrorMessage = "selectedIndex must be between 0 and 3.")] int SelectedIndex);

/// <summary>Instant feedback for one answer, plus the running score.</summary>
public record AnswerResultDto(bool Correct, int CorrectIndex, int Score, int Answered, int Total);

/// <summary>Finishes a round; it's scored from the answers already locked in.</summary>
public record SubmitGameRequest([Required] string SessionToken);

/// <summary>SelectedIndex is -1 for a question that was never answered (it counts as wrong).</summary>
public record ReviewItemDto(int QuestionId, int CorrectIndex, int SelectedIndex, bool Correct);

/// <summary>Where the XP for a round came from.</summary>
public record XpEarnedDto(int Correct, int Round, int Perfect, int Total);

/// <summary>A player's XP and level. LevelXp is the XP gained since reaching this level, out of LevelXpNeeded.</summary>
public record ProgressDto(int Xp, int Level, int LevelXp, int LevelXpNeeded, string Rank);

/// <summary>A finished round, with the XP it earned and the player's progress before and after it.</summary>
public record GameResultResponse(int GameId, int Score, int Total, List<ReviewItemDto> Review,
    XpEarnedDto Xp, ProgressDto Before, ProgressDto After);

public record HistoryItemDto(int GameId, string SportName, string CategoryName, int Score, int Total, DateTime PlayedAt);

/// <summary>
/// One player on a leaderboard. Xp is what they earned in the board's scope (all sports, or
/// one); Level and RankName are their overall progress. BestScore is set on sport boards only.
/// </summary>
public record LeaderboardEntryDto(int Rank, string DisplayName, int Xp, int Level, string RankName, int? BestScore, int GamesPlayed);

/// <summary>The top players, plus the caller's own row (null if they haven't played in this scope).</summary>
public record LeaderboardResponse(List<LeaderboardEntryDto> Top, LeaderboardEntryDto? Me);
