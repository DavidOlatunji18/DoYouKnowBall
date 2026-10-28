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

    /// <summary>
    /// How each question's options were shuffled for this round, comma-separated in the
    /// same order as <see cref="QuestionIds"/>. Each entry is four digits: the digit at
    /// position p is the stored option shown at position p (so "2013" shows Option3 first).
    /// Empty for rounds started before shuffling existed, which used the stored order.
    /// </summary>
    public string OptionOrders { get; set; } = "";

    public DateTime CreatedAt { get; set; }

    /// <summary>When the quiz started or the last answer arrived; answer times are measured from here.</summary>
    public DateTime LastActivityAt { get; set; }

    /// <summary>Set once the round is submitted; also guards against submitting twice.</summary>
    public DateTime? SubmittedAt { get; set; }

    public int? GameSessionId { get; set; }
    public GameSession? GameSession { get; set; }

    public List<QuizAnswer> Answers { get; set; } = [];

    public List<int> ServedQuestionIds() => QuestionIds.Split(',').Select(int.Parse).ToList();

    /// <summary>The stored option index shown at each position for a question in this round.</summary>
    public int[] OptionOrderFor(int questionId)
    {
        var position = ServedQuestionIds().IndexOf(questionId);
        var orders = OptionOrders.Split(',', StringSplitOptions.RemoveEmptyEntries);
        return position >= 0 && position < orders.Length
            ? orders[position].Select(c => c - '0').ToArray()
            : [0, 1, 2, 3];
    }

    /// <summary>Where the stored option <paramref name="storedIndex"/> was shown to the player.</summary>
    public int ShownIndexOf(int questionId, int storedIndex) =>
        Array.IndexOf(OptionOrderFor(questionId), storedIndex);
}
