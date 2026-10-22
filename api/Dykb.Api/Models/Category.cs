namespace Dykb.Api.Models;

public class Category
{
    public int Id { get; set; }
    public int SportId { get; set; }
    public Sport Sport { get; set; } = null!;
    public string Name { get; set; } = "";
    public List<Question> Questions { get; set; } = [];
}
