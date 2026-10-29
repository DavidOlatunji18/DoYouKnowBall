using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Dykb.Api.Controllers;

/// <summary>The logged-in player: who they are (checked on launch) and their progress.</summary>
[ApiController]
[Route("me")]
public class MeController(AuthService auth, GameService games) : ControllerBase
{
    [HttpGet]
    public Task<UserDto> Get() => auth.GetUserAsync(User.GetUserId());

    /// <summary>The player's XP, level and rank.</summary>
    [HttpGet("progress")]
    public Task<ProgressDto> Progress() => games.GetProgressAsync(User.GetUserId());
}
