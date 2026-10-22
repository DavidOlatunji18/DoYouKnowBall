using Dykb.Api.Dtos;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Dykb.Api.Controllers;

[ApiController]
[Route("sports")]
public class SportsController(QuizService quiz) : ControllerBase
{
    [HttpGet]
    public Task<List<SportDto>> GetSports() => quiz.GetSportsAsync();

    [HttpGet("{sportId:int}/categories")]
    public Task<List<CategoryDto>> GetCategories(int sportId) => quiz.GetCategoriesAsync(sportId);
}
