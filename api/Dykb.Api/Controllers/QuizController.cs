using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Dykb.Api.Controllers;

[ApiController]
[Route("quiz")]
public class QuizController(QuizService quiz) : ControllerBase
{
    [HttpGet]
    public Task<QuizResponse> GetQuiz([BindRequired] int categoryId, int count = QuizService.MaxQuestionsPerQuiz) =>
        quiz.CreateQuizAsync(User.GetUserId(), categoryId, count);

    /// <summary>Checks one answer right away and locks it in.</summary>
    [HttpPost("answer")]
    public Task<AnswerResultDto> Answer(AnswerRequest request) => quiz.AnswerAsync(User.GetUserId(), request);
}
