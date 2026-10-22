namespace Dykb.Api.Models;

public class Sport
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public List<Category> Categories { get; set; } = [];
}
