using System.Text.Json;
using Dykb.Api.Data;
using Dykb.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Services;

public record SeedQuestion(string Sport, string Category, string Text, string[] Options, int CorrectIndex, int Difficulty);

public record SeedResult(int Added, int Updated, int Removed, int Total);

/// <summary>
/// Syncs the questions in the seed JSON files into the database. Safe to run repeatedly:
/// sports and categories are matched by name and questions by text within their category.
/// New questions are added, edited ones updated in place, and questions no longer in a
/// seeded category's file are removed. Sports and categories are never deleted.
/// </summary>
public class SeedLoader(AppDbContext db, ILogger<SeedLoader> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<SeedResult> LoadAsync(string directory)
    {
        var seed = ReadAndValidate(directory);
        var sports = await db.Sports.Include(s => s.Categories).ToListAsync();
        int added = 0, updated = 0, removed = 0;

        foreach (var byCategory in seed.GroupBy(q => (q.Sport, q.Category)))
        {
            var (sportName, categoryName) = byCategory.Key;

            var sport = sports.SingleOrDefault(s => s.Name == sportName);
            if (sport is null)
            {
                sport = new Sport { Name = sportName };
                sports.Add(sport);
                db.Sports.Add(sport);
            }

            var category = sport.Categories.SingleOrDefault(c => c.Name == categoryName);
            if (category is null)
            {
                category = new Category { Name = categoryName, Sport = sport };
                sport.Categories.Add(category);
            }

            var existing = category.Id == 0
                ? []
                : await db.Questions.Where(q => q.CategoryId == category.Id).ToListAsync();
            var existingByText = existing.ToDictionary(q => q.Text);

            foreach (var item in byCategory)
            {
                if (existingByText.Remove(item.Text, out var question))
                {
                    if (Apply(question, item))
                        updated++;
                }
                else
                {
                    question = new Question { Category = category, Text = item.Text };
                    Apply(question, item);
                    db.Questions.Add(question);
                    added++;
                }
            }

            // Whatever is left in the dictionary was deleted from the seed file.
            db.Questions.RemoveRange(existingByText.Values);
            removed += existingByText.Count;
        }

        await db.SaveChangesAsync();
        var result = new SeedResult(added, updated, removed, seed.Count);
        logger.LogInformation("Seeded questions: {Added} added, {Updated} updated, {Removed} removed ({Total} in seed files)",
            result.Added, result.Updated, result.Removed, result.Total);
        return result;
    }

    /// <summary>Copies seed values onto the entity; returns true if anything changed.</summary>
    private static bool Apply(Question q, SeedQuestion s)
    {
        var changed = q.Option1 != s.Options[0] || q.Option2 != s.Options[1] || q.Option3 != s.Options[2]
            || q.Option4 != s.Options[3] || q.CorrectIndex != s.CorrectIndex || q.Difficulty != s.Difficulty;
        (q.Option1, q.Option2, q.Option3, q.Option4) = (s.Options[0], s.Options[1], s.Options[2], s.Options[3]);
        q.CorrectIndex = s.CorrectIndex;
        q.Difficulty = s.Difficulty;
        return changed;
    }

    /// <summary>
    /// Reads every seed file and re-checks the rules from seed/validate.py, so bad data is
    /// rejected before anything is written.
    /// </summary>
    public static List<SeedQuestion> ReadAndValidate(string directory)
    {
        if (!Directory.Exists(directory))
            throw new DirectoryNotFoundException($"Seed directory not found: {directory}");

        var files = Directory.GetFiles(directory, "*.json", SearchOption.AllDirectories)
            .Where(f => !f.EndsWith(".schema.json", StringComparison.OrdinalIgnoreCase))
            .Order()
            .ToList();
        if (files.Count == 0)
            throw new InvalidDataException($"No seed files found in {directory}");

        var all = new List<SeedQuestion>();
        var seenText = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var file in files)
        {
            var items = JsonSerializer.Deserialize<List<SeedQuestion>>(File.ReadAllText(file), JsonOptions) ?? [];
            for (var i = 0; i < items.Count; i++)
            {
                var q = items[i];
                var where = $"{Path.GetRelativePath(directory, file)}[{i}]";
                if (string.IsNullOrWhiteSpace(q.Sport) || string.IsNullOrWhiteSpace(q.Category) || string.IsNullOrWhiteSpace(q.Text))
                    throw new InvalidDataException($"{where}: sport, category and text are required");
                if (q.Options is not { Length: 4 } || q.Options.Any(string.IsNullOrWhiteSpace)
                    || q.Options.Select(o => o.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).Count() != 4)
                    throw new InvalidDataException($"{where}: needs exactly 4 distinct, non-empty options");
                if (q.CorrectIndex is < 0 or > 3)
                    throw new InvalidDataException($"{where}: correctIndex must be 0-3");
                if (q.Difficulty is < 1 or > 3)
                    throw new InvalidDataException($"{where}: difficulty must be 1-3");
                if (!seenText.Add(q.Text.Trim()))
                    throw new InvalidDataException($"{where}: duplicate question text");
                all.Add(q);
            }
        }
        return all;
    }
}
