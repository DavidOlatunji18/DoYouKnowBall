namespace Dykb.Api.Models;

/// <summary>
/// One round in progress: which questions were served to which player, and each
/// answer as it's locked in. The final score comes from these locked answers, so a
/// player can't see the correct answer and then change their pick.
/// </summary>
public class QuizAttempt
{
    public Guid Id { get; set; }
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!;

    /// <summary>Comma-separated question ids, in the order they were served.</summary>
    public string QuestionIds { get; set; } = "";

    public DateTime CreatedAt { get; set; }

    /// <summary>When the quiz started or the last answer arrived; answer times are measured from here.</summary>
    public DateTime LastActivityAt { get; set; }

    /// <summary>Set once the round is submitted; also guards against submitting twice.</summary>
    public DateTime? SubmittedAt { get; set; }

    public int? GameSessionId { get; set; }
    public GameSession? GameSession { get; set; }

    public List<QuizAnswer> Answers { get; set; } = [];

    public List<int> ServedQuestionIds() => QuestionIds.Split(',').Select(int.Parse).ToList();
}
