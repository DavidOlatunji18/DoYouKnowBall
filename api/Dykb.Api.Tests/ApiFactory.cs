using System.Net.Http.Headers;
using System.Net.Http.Json;
using Dykb.Api.Data;
using Dykb.Api.Dtos;
using Dykb.Api.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Dykb.Api.Tests;

/// <summary>Runs the real API in memory, backed by its own EF Core in-memory database.</summary>
public class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _databaseName = $"dykb-tests-{Guid.NewGuid()}";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Default", "Server=unused-in-tests");
        builder.UseSetting("Jwt:Key", "integration-test-signing-key-at-least-32-bytes");

        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<AppDbContext>>();
            services.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase(_databaseName));
        });
    }

    public async Task<T> WithDbAsync<T>(Func<AppDbContext, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    /// <summary>Adds a sport with one category holding <paramref name="questionCount"/> questions.</summary>
    public Task<Category> SeedCategoryAsync(string sportName = "NBA", string categoryName = "History", int questionCount = 10) =>
        WithDbAsync(async db =>
        {
            var sport = await db.Sports.SingleOrDefaultAsync(s => s.Name == sportName) ?? new Sport { Name = sportName };
            var category = new Category { Sport = sport, Name = categoryName };
            for (var i = 0; i < questionCount; i++)
            {
                category.Questions.Add(new Question
                {
                    Text = $"{sportName} {categoryName} question {i}",
                    Option1 = "A", Option2 = "B", Option3 = "C", Option4 = "D",
                    CorrectIndex = i % 4,
                    Difficulty = 1 + i % 3,
                });
            }
            db.Categories.Add(category);
            await db.SaveChangesAsync();
            return category;
        });

    /// <summary>Registers a fresh user and returns a client that sends their JWT.</summary>
    public async Task<HttpClient> CreateAuthenticatedClientAsync(string? displayName = null)
    {
        var client = CreateClient();
        var response = await client.PostAsJsonAsync("/auth/register", new RegisterRequest(
            $"{Guid.NewGuid():N}@example.com", "hoops-and-dreams", displayName ?? $"player_{Guid.NewGuid():N}"[..19]));
        response.EnsureSuccessStatusCode();
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth!.Token);
        return client;
    }
}
