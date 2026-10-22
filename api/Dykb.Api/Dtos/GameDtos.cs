using System.ComponentModel.DataAnnotations;

namespace Dykb.Api.Dtos;

public record AnswerDto(
    int QuestionId,
    [Range(0, 3, ErrorMessage = "selectedIndex must be between 0 and 3.")] int SelectedIndex);

public record SubmitGameRequest(
    int CategoryId,
    [Required] string SessionToken,
    [Required, MinLength(1, ErrorMessage = "Submit at least one answer.")] List<AnswerDto> Answers);

public record ReviewItemDto(int QuestionId, int CorrectIndex, int SelectedIndex, bool Correct);

public record GameResultResponse(int GameId, int Score, int Total, List<ReviewItemDto> Review);

public record HistoryItemDto(int GameId, string CategoryName, int Score, int Total, DateTime PlayedAt);

public record LeaderboardEntryDto(int Rank, string DisplayName, int BestScore, int GamesPlayed);
