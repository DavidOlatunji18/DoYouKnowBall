using System.Security.Claims;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Dykb.Api.Infrastructure;

public static class ClaimsPrincipalExtensions
{
    public static int GetUserId(this ClaimsPrincipal principal) =>
        int.TryParse(principal.FindFirstValue(JwtRegisteredClaimNames.Sub), out var id)
            ? id
            : throw ApiException.Unauthorized("Please log in to continue.");
}
