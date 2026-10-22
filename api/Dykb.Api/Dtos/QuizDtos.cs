namespace Dykb.Api.Dtos;

public record SportDto(int Id, string Name);

public record CategoryDto(int Id, string Name, int SportId);

/// <summary>A question as sent to players: no correct answer.</summary>
public record QuizQuestionDto(int Id, string Text, string[] Options);

public record QuizResponse(string SessionToken, List<QuizQuestionDto> Questions);
