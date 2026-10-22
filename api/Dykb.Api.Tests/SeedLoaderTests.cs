using System.Text.Json;
using Dykb.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Dykb.Api.Tests;

public class SeedLoaderTests : IDisposable
{
    private static readonly string RealSeedDirectory = Path.Combine(AppContext.BaseDirectory, "seed");

    private readonly ApiFactory _factory = new();
    private readonly string _tempDirectory = Directory.CreateTempSubdirectory("dykb-seed-").FullName;

    public void Dispose()
    {
        _factory.Dispose();
        Directory.Delete(_tempDirectory, recursive: true);
    }

    [Fact]
    public void RealSeedFiles_AreValid()
    {
        var questions = SeedLoader.ReadAndValidate(RealSeedDirectory);

        Assert.True(questions.Count >= 400, $"Expected at least 400 seed questions, found {questions.Count}");
        Assert.Equal(["NFL", "Soccer"], questions.Select(q => q.Sport).Distinct().Order());
    }

    [Fact]
    public async Task RealSeedFiles_LoadIdempotently()
    {
        var first = await LoadAsync(RealSeedDirectory);
        var second = await LoadAsync(RealSeedDirectory);

        Assert.Equal(first.Total, first.Added);
        Assert.Equal(new SeedResult(0, 0, 0, first.Total), second);
        Assert.Equal(first.Total, await _factory.WithDbAsync(db => db.Questions.CountAsync()));
        Assert.Equal(2, await _factory.WithDbAsync(db => db.Sports.CountAsync()));
    }

    [Fact]
    public async Task EditedSeed_UpdatesChangedQuestionsAndRemovesDeletedOnes()
    {
        WriteSeed("a.json", Q("Kept?", 0), Q("Edited?", 1), Q("Deleted?", 2));
        await LoadAsync(_tempDirectory);
        var editedId = await _factory.WithDbAsync(db => db.Questions.Where(q => q.Text == "Edited?").Select(q => q.Id).SingleAsync());

        WriteSeed("a.json", Q("Kept?", 0), Q("Edited?", 3), Q("New?", 1));
        var result = await LoadAsync(_tempDirectory);

        Assert.Equal(new SeedResult(Added: 1, Updated: 1, Removed: 1, Total: 3), result);
        var questions = await _factory.WithDbAsync(db => db.Questions.OrderBy(q => q.Text).ToListAsync());
        Assert.Equal(["Edited?", "Kept?", "New?"], questions.Select(q => q.Text));
        var edited = questions.Single(q => q.Text == "Edited?");
        Assert.Equal(editedId, edited.Id); // updated in place, not re-created
        Assert.Equal(3, edited.CorrectIndex);
    }

    [Theory]
    [InlineData("""[{"sport":"NFL","category":"X","text":"Q?","options":["a","b","c"],"correctIndex":0,"difficulty":1}]""")]
    [InlineData("""[{"sport":"NFL","category":"X","text":"Q?","options":["a","A","c","d"],"correctIndex":0,"difficulty":1}]""")]
    [InlineData("""[{"sport":"NFL","category":"X","text":"Q?","options":["a","b","c","d"],"correctIndex":4,"difficulty":1}]""")]
    [InlineData("""[{"sport":"NFL","category":"X","text":"Q?","options":["a","b","c","d"],"correctIndex":0,"difficulty":0}]""")]
    [InlineData("""[{"sport":"","category":"X","text":"Q?","options":["a","b","c","d"],"correctIndex":0,"difficulty":1}]""")]
    [InlineData("""[{"sport":"NFL","category":"X","text":"Q?","options":["a","b","c","d"],"correctIndex":0,"difficulty":1},{"sport":"NFL","category":"Y","text":"q?","options":["a","b","c","d"],"correctIndex":0,"difficulty":1}]""")]
    public async Task InvalidSeed_IsRejectedWithoutWritingAnything(string json)
    {
        File.WriteAllText(Path.Combine(_tempDirectory, "bad.json"), json);

        await Assert.ThrowsAsync<InvalidDataException>(() => LoadAsync(_tempDirectory));
        Assert.Equal(0, await _factory.WithDbAsync(db => db.Questions.CountAsync()));
    }

    private async Task<SeedResult> LoadAsync(string directory)
    {
        using var scope = _factory.Services.CreateScope();
        return await scope.ServiceProvider.GetRequiredService<SeedLoader>().LoadAsync(directory);
    }

    private static SeedQuestion Q(string text, int correctIndex) =>
        new("NFL", "Test", text, ["A", "B", "C", "D"], correctIndex, 1);

    private void WriteSeed(string name, params SeedQuestion[] questions) =>
        File.WriteAllText(Path.Combine(_tempDirectory, name),
            JsonSerializer.Serialize(questions, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
}
