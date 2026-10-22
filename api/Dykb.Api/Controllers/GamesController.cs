using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Dykb.Api.Controllers;

[ApiController]
[Route("games")]
public class GamesController(GameService games) : ControllerBase
{
    [HttpPost]
    public Task<GameResultResponse> Submit(SubmitGameRequest request) => games.SubmitAsync(User.GetUserId(), request);

    [HttpGet("history")]
    public Task<List<HistoryItemDto>> History() => games.GetHistoryAsync(User.GetUserId());
}
