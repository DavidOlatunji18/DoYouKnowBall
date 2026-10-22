namespace Dykb.Api.Models;

public class Question
{
    public int Id { get; set; }
    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!;
    public string Text { get; set; } = "";
    public string Option1 { get; set; } = "";
    public string Option2 { get; set; } = "";
    public string Option3 { get; set; } = "";
    public string Option4 { get; set; } = "";

    /// <summary>Zero-based index (0-3) of the correct option. Never sent to clients before scoring.</summary>
    public int CorrectIndex { get; set; }

    /// <summary>1 = easy, 2 = medium, 3 = hard.</summary>
    public int Difficulty { get; set; }
}
