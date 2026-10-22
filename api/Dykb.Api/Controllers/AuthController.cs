using Dykb.Api.Dtos;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Dykb.Api.Controllers;

[ApiController]
[Route("auth")]
[AllowAnonymous]
public class AuthController(AuthService auth) : ControllerBase
{
    [HttpPost("register")]
    public Task<AuthResponse> Register(RegisterRequest request) => auth.RegisterAsync(request);

    [HttpPost("login")]
    public Task<AuthResponse> Login(LoginRequest request) => auth.LoginAsync(request);
}
