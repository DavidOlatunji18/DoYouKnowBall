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

public record GameResultResponse(int GameId, int Score, int Total, List<ReviewItemDto> Review);

public record HistoryItemDto(int GameId, string SportName, string CategoryName, int Score, int Total, DateTime PlayedAt);

public record LeaderboardEntryDto(int Rank, string DisplayName, int BestScore, int GamesPlayed);
