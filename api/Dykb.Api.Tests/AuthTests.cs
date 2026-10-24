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
        Assert.Equal("kobe", auth.User.DisplayName); // usernames are stored lowercase
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
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("dup@example.com", "hoops-and-dreams", "First"));

        var response = await _client.PostAsJsonAsync("/auth/register",
            new RegisterRequest("DUP@example.com", "password456", "Second"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        Assert.Contains("already exists", error!.Error);
    }

    [Theory]
    [InlineData("not-an-email", "hoops-and-dreams", "Name")]
    [InlineData("short@example.com", "short", "Name")]
    [InlineData("name@example.com", "hoops-and-dreams", " ")]
    public async Task Register_InvalidInput_Returns400WithErrorShape(string email, string password, string displayName)
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new RegisterRequest(email, password, displayName));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponse>();
        Assert.False(string.IsNullOrWhiteSpace(error!.Error));
    }

    [Theory]
    [InlineData("ab", "3-30 characters")]
    [InlineData("this_username_is_way_too_long_1", "3-30 characters")]
    [InlineData("kobe bryant", "letters, numbers, periods and underscores")]
    [InlineData("kobe!", "letters, numbers, periods and underscores")]
    [InlineData("kôbe", "letters, numbers, periods and underscores")]
    [InlineData(".kobe", "start or end with a period")]
    [InlineData("kobe.", "start or end with a period")]
    [InlineData("kobe..24", "two periods in a row")]
    public async Task Register_InvalidUsername_Returns400WithReason(string username, string reason)
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("user@example.com", "hoops-and-dreams", username));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains(reason, (await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Theory]
    [InlineData("kobe.bryant_24")]
    [InlineData("k_b")]
    [InlineData("__mamba__")]
    [InlineData("123")]
    public async Task Register_ValidUsername_IsAccepted(string username)
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("user@example.com", "hoops-and-dreams", username));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Register_TakenUsername_Returns409IgnoringCase()
    {
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("first@example.com", "hoops-and-dreams", "kobe"));

        var response = await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("second@example.com", "hoops-and-dreams", "  KOBE "));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("That username is taken.", (await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Theory]
    [InlineData("1234567", "at least 8 characters")]
    [InlineData("11111111", "repeat one character")]
    [InlineData("12345678", "simple runs")]
    [InlineData("hgfedcba", "simple runs")]
    [InlineData("kobe24rules", "username or email")]       // contains the username
    [InlineData("xxmambaxx99", "username or email")]       // contains the email name
    [InlineData("Password123", "too common")]
    [InlineData("liverpool", "too common")]
    public async Task Register_WeakPassword_Returns400WithReason(string password, string reason)
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("mamba@example.com", password, "kobe24"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains(reason, (await response.Content.ReadFromJsonAsync<ErrorResponse>())!.Error);
    }

    [Theory]
    [InlineData("48201937")]          // all numbers is fine if it isn't guessable
    [InlineData("hoops-and-dreams")]
    [InlineData("correct horse battery staple")]
    public async Task Register_StrongPassword_IsAccepted(string password)
    {
        var response = await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("mamba@example.com", password, "kobe24"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("lebron23")]
    [InlineData("@LeBron23")]
    [InlineData("  LEBRON23 ")]
    [InlineData("lebron@example.com")]
    public async Task Login_WithUsernameOrEmail_ReturnsToken(string login)
    {
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("lebron@example.com", "kingjames23", "lebron23"));

        var response = await _client.PostAsJsonAsync("/auth/login", new LoginRequest(login, "kingjames23"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("lebron23", (await response.Content.ReadFromJsonAsync<AuthResponse>())!.User.DisplayName);
    }

    [Fact]
    public async Task Login_WithCorrectPassword_ReturnsToken()
    {
        await _client.PostAsJsonAsync("/auth/register", new RegisterRequest("lebron@example.com", "kingjames23", "LeBron"));

        var response = await _client.PostAsJsonAsync("/auth/login", new LoginRequest("LeBron@example.com", "kingjames23"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.False(string.IsNullOrWhiteSpace(auth!.Token));
        Assert.Equal("lebron", auth.User.DisplayName);
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
        Assert.Equal("Incorrect username, email or password.", error!.Error);
    }

    [Theory]
    [InlineData("GET", "/sports")]
    [InlineData("GET", "/sports/1/categories")]
    [InlineData("GET", "/quiz?categoryId=1")]
    [InlineData("POST", "/games")]
    [InlineData("POST", "/quiz/answer")]
    [InlineData("GET", "/games/history")]
    [InlineData("GET", "/leaderboard?sportId=1")]
    [InlineData("GET", "/me")]
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
    public async Task Me_WithToken_ReturnsTheAccount()
    {
        var client = await _factory.CreateAuthenticatedClientAsync("mamba24");

        var me = await client.GetFromJsonAsync<UserDto>("/me");

        Assert.Equal("mamba24", me!.DisplayName);
        Assert.EndsWith("@example.com", me.Email);
    }

    [Fact]
    public async Task Me_ForDeletedAccount_Returns401()
    {
        var client = await _factory.CreateAuthenticatedClientAsync("gone_player");
        await _factory.WithDbAsync(async db =>
        {
            db.Users.RemoveRange(db.Users);
            return await db.SaveChangesAsync();
        });

        var response = await client.GetAsync("/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Health_IsPublic()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
