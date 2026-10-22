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
    public DateTime PlayedAt { get; set; }
}
