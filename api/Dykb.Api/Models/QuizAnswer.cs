namespace Dykb.Api.Models;

/// <summary>A locked-in answer to one question of a <see cref="QuizAttempt"/>.</summary>
public class QuizAnswer
{
    public int Id { get; set; }
    public Guid QuizAttemptId { get; set; }
    public QuizAttempt QuizAttempt { get; set; } = null!;

    /// <summary>Not a foreign key: seed updates may remove questions, but answers are history.</summary>
    public int QuestionId { get; set; }

    /// <summary>The position the player tapped, as shown in their shuffled round (0-3).</summary>
    public int SelectedIndex { get; set; }
    public bool Correct { get; set; }
    public DateTime AnsweredAt { get; set; }

    /// <summary>
    /// Time since the question became current (quiz start or previous answer), measured
    /// on the server so it can't be faked. Recorded now for future speed scoring.
    /// </summary>
    public int ElapsedMs { get; set; }
}
