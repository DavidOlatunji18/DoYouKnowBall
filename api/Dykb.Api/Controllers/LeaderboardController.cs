using Dykb.Api.Dtos;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Dykb.Api.Controllers;

[ApiController]
[Route("leaderboard")]
public class LeaderboardController(GameService games) : ControllerBase
{
    [HttpGet]
    public Task<List<LeaderboardEntryDto>> Get([BindRequired] int sportId, int top = 20) =>
        games.GetLeaderboardAsync(sportId, top);
}
