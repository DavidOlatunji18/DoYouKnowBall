using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Dykb.Api.Controllers;

[ApiController]
[Route("leaderboard")]
public class LeaderboardController(GameService games) : ControllerBase
{
    /// <summary>Top players by XP: across all sports, or in one sport when sportId is given.</summary>
    [HttpGet]
    public Task<LeaderboardResponse> Get(int? sportId, int top = GameService.DefaultLeaderboardSize) =>
        games.GetLeaderboardAsync(User.GetUserId(), sportId, top);
}
