using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Dykb.Api.Controllers;

/// <summary>Lets the app check on launch that a saved login is still valid.</summary>
[ApiController]
[Route("me")]
public class MeController(AuthService auth) : ControllerBase
{
    [HttpGet]
    public Task<UserDto> Get() => auth.GetUserAsync(User.GetUserId());
}
