using System.Security.Claims;
using System.Text;
using Dykb.Api.Data;
using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Dykb.Api.Services;

public class AuthService(AppDbContext db, IPasswordHasher<User> hasher, IOptions<JwtOptions> jwtOptions)
{
    private readonly JwtOptions _jwt = jwtOptions.Value;

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request)
    {
        var email = NormalizeEmail(request.Email);
        var username = request.DisplayName.Trim().ToLowerInvariant();
        if (UsernameRules.Validate(username) is { } usernameProblem)
            throw ApiException.BadRequest(usernameProblem);
        if (PasswordRules.Validate(request.Password, username, email) is { } passwordProblem)
            throw ApiException.BadRequest(passwordProblem);

        if (await db.Users.AnyAsync(u => u.Email == email))
            throw ApiException.Conflict("An account with that email already exists.");
        if (await db.Users.AnyAsync(u => u.DisplayName == username))
            throw ApiException.Conflict("That username is taken.");

        var user = new User { Email = email, DisplayName = username, CreatedAt = DateTime.UtcNow };
        user.PasswordHash = hasher.HashPassword(user, request.Password);
        db.Users.Add(user);

        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // Lost a race with a concurrent registration for the same email or username.
            db.Entry(user).State = EntityState.Detached;
            if (await db.Users.AnyAsync(u => u.Email == email))
                throw ApiException.Conflict("An account with that email already exists.");
            if (await db.Users.AnyAsync(u => u.DisplayName == username))
                throw ApiException.Conflict("That username is taken.");
            throw;
        }

        return new AuthResponse(CreateToken(user), ToDto(user));
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        // One field takes either: anything with an @ in the middle is an email, otherwise
        // it's a username (a leading @, as in "@kobe24", is allowed and ignored).
        var login = request.EmailOrUsername.Trim().ToLowerInvariant();
        var user = login.IndexOf('@') > 0
            ? await db.Users.SingleOrDefaultAsync(u => u.Email == login)
            : await db.Users.SingleOrDefaultAsync(u => u.DisplayName == login.TrimStart('@'));

        var result = user is null
            ? PasswordVerificationResult.Failed
            : hasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);
        if (user is null || result == PasswordVerificationResult.Failed)
            throw ApiException.Unauthorized("Incorrect username, email or password.");

        if (result == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = hasher.HashPassword(user, request.Password);
            await db.SaveChangesAsync();
        }

        return new AuthResponse(CreateToken(user), ToDto(user));
    }

    /// <summary>The account behind a valid token. A deleted account counts as logged out.</summary>
    public async Task<UserDto> GetUserAsync(int userId)
    {
        var user = await db.Users.FindAsync(userId)
            ?? throw ApiException.Unauthorized("Please log in to continue.");
        return ToDto(user);
    }

    private string CreateToken(User user)
    {
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _jwt.Issuer,
            Audience = _jwt.Audience,
            Expires = DateTime.UtcNow.AddMinutes(_jwt.ExpiryMinutes),
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.Key)), SecurityAlgorithms.HmacSha256),
            Subject = new ClaimsIdentity(
            [
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Email, user.Email),
                new Claim(JwtRegisteredClaimNames.Name, user.DisplayName),
            ]),
        };
        return new JsonWebTokenHandler().CreateToken(descriptor);
    }

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    private static UserDto ToDto(User user) => new(user.Id, user.Email, user.DisplayName);
}
