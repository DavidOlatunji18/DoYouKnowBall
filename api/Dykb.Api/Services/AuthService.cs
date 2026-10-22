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
        var displayName = request.DisplayName.Trim();
        if (displayName.Length < 2)
            throw ApiException.BadRequest("Display name must be at least 2 characters.");

        if (await db.Users.AnyAsync(u => u.Email == email))
            throw ApiException.Conflict("An account with that email already exists.");

        var user = new User { Email = email, DisplayName = displayName, CreatedAt = DateTime.UtcNow };
        user.PasswordHash = hasher.HashPassword(user, request.Password);
        db.Users.Add(user);

        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // Lost a race with a concurrent registration for the same email.
            if (await db.Users.AnyAsync(u => u.Email == email))
                throw ApiException.Conflict("An account with that email already exists.");
            throw;
        }

        return new AuthResponse(CreateToken(user), ToDto(user));
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        var email = NormalizeEmail(request.Email);
        var user = await db.Users.SingleOrDefaultAsync(u => u.Email == email);

        var result = user is null
            ? PasswordVerificationResult.Failed
            : hasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);
        if (user is null || result == PasswordVerificationResult.Failed)
            throw ApiException.Unauthorized("Incorrect email or password.");

        if (result == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = hasher.HashPassword(user, request.Password);
            await db.SaveChangesAsync();
        }

        return new AuthResponse(CreateToken(user), ToDto(user));
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
