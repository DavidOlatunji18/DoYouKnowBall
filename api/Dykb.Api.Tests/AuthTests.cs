using System.Net;
using System.Net.Http.Json;
using Dykb.Api.Dtos;

namespace Dykb.Api.Tests;

public class AuthTests : IDisposable
{
    private readonly ApiFactory _factory = new();
    private readonly HttpClient _client;

    public AuthTests() => _client = _factory.CreateClient();

    public void Dispose() => _factory.Dispose();

    [Fact]
    public async Task Register_ReturnsTokenAndUser()
    {
        var response = await _client.PostAsJsonAsync("/auth/register",
            new RegisterRequest("  Kobe@Example.com ", "mamba-mentality", "Kobe"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.False(string.IsNullOrWhiteSpace(auth!.Token));
        Assert.True(auth.User.Id > 0);
        Assert.Equal("kobe@example.com", auth.User.Email);
        Assert.Equal("Kobe", auth.User.DisplayName);
    }

    [Fact]
    public async Task Register_DoesNotStorePlaintextPassword()
    {
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("hash@example.com", "plaintext-pass", "Hash"));

        var hash = await _factory.WithDbAsync(db => Task.FromResult(db.Users.Single().PasswordHash));
        Assert.DoesNotContain("plaintext-pass", hash);
    }

    [Fact]
    public async Task Register_DuplicateEmail_Returns409()
    {
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("dup@example.com", "password123", "First"));

        var response = await _client.PostAsJsonAsync("/auth/register",
            new RegisterRequest("DUP@example.com", "password456", "Second"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        Assert.Contains("already exists", error!.Error);
    }

    [Theory]
    [InlineData("not-an-email", "password123", "Name")]
    [InlineData("short@example.com", "short", "Name")]
    [InlineData("name@example.com", "password123", " ")]
    public async Task Register_InvalidInput_Returns400WithErrorShape(string email, string password, string displayName)
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new RegisterRequest(email, password, displayName));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        Assert.False(string.IsNullOrWhiteSpace(error!.Error));
    }

    [Fact]
    public async Task Login_WithCorrectPassword_ReturnsToken()
    {
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("lebron@example.com", "kingjames23", "LeBron"));

        var response = await _client.PostAsJsonAsync("/auth/login", new LoginRequest("LeBron@example.com", "kingjames23"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.False(string.IsNullOrWhiteSpace(auth!.Token));
        Assert.Equal("LeBron", auth.User.DisplayName);
    }

    [Theory]
    [InlineData("lebron@example.com", "wrong-password")]
    [InlineData("nobody@example.com", "kingjames23")]
    public async Task Login_WithBadCredentials_Returns401(string email, string password)
    {
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("lebron@example.com", "kingjames23", "LeBron"));

        var response = await _client.PostAsJsonAsync("/auth/login", new LoginRequest(email, password));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        Assert.Equal("Incorrect email or password.", error!.Error);
    }

    [Theory]
    [InlineData("GET", "/sports")]
    [InlineData("GET", "/sports/1/categories")]
    [InlineData("GET", "/quiz?categoryId=1")]
    [InlineData("POST", "/games")]
    [InlineData("GET", "/games/history")]
    [InlineData("GET", "/leaderboard?sportId=1")]
    public async Task ProtectedEndpoints_WithoutToken_Return401(string method, string url)
    {
        var response = await _client.SendAsync(new HttpRequestMessage(new HttpMethod(method), url));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        Assert.False(string.IsNullOrWhiteSpace(error!.Error));
    }

    [Fact]
    public async Task ProtectedEndpoint_WithGarbageToken_Returns401()
    {
        _client.DefaultRequestHeaders.Authorization = new("Bearer", "not.a.real.token");

        var response = await _client.GetAsync("/sports");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Health_IsPublic()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
