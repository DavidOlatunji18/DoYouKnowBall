namespace Dykb.Api.Models;

public class GameSession
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!;
    public int Score { get; set; }
    public int Total { get; set; }

    /// <summary>XP awarded for this round (see <c>Levels.ForRound</c>).</summary>
    public int XpEarned { get; set; }
    public DateTime PlayedAt { get; set; }
}
