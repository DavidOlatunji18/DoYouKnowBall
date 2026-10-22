using Dykb.Api.Data;
using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Services;

public class QuizService(AppDbContext db, QuizSessionTokens sessionTokens)
{
    public const int MaxQuestionsPerQuiz = 10;

    public Task<List<SportDto>> GetSportsAsync() =>
        db.Sports
            .OrderBy(s => s.Name)
            .Select(s => new SportDto(s.Id, s.Name))
            .ToListAsync();

    public async Task<List<CategoryDto>> GetCategoriesAsync(int sportId)
    {
        if (!await db.Sports.AnyAsync(s => s.Id == sportId))
            throw ApiException.NotFound("Sport not found.");

        return await db.Categories
            .Where(c => c.SportId == sportId)
            .OrderBy(c => c.Name)
            .Select(c => new CategoryDto(c.Id, c.Name, c.SportId))
            .ToListAsync();
    }

    public async Task<QuizResponse> CreateQuizAsync(int userId, int categoryId, int count)
    {
        count = Math.Clamp(count, 1, MaxQuestionsPerQuiz);

        if (!await db.Categories.AnyAsync(c => c.Id == categoryId))
            throw ApiException.NotFound("Category not found.");

        // Guid.NewGuid() translates to NEWID() on SQL Server, giving a fresh random order per query.
        var questions = await db.Questions
            .Where(q => q.CategoryId == categoryId)
            .OrderBy(q => Guid.NewGuid())
            .Take(count)
            .Select(q => new QuizQuestionDto(q.Id, q.Text, new[] { q.Option1, q.Option2, q.Option3, q.Option4 }))
            .ToListAsync();

        if (questions.Count == 0)
            throw ApiException.NotFound("This category has no questions yet.");

        var token = sessionTokens.Create(new QuizSession(userId, categoryId, questions.Select(q => q.Id).ToList()));
        return new QuizResponse(token, questions);
    }
}
