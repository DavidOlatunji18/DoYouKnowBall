using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;

namespace Dykb.Api.Services;

public record QuizSession(int UserId, int CategoryId, List<int> QuestionIds);

/// <summary>
/// Issues and reads the quiz <c>sessionToken</c>: an encrypted, expiring record of which
/// questions were served to which user, so a submitted game can only answer those questions.
/// </summary>
public class QuizSessionTokens(IDataProtectionProvider provider)
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromHours(1);

    private readonly ITimeLimitedDataProtector _protector =
        provider.CreateProtector("Dykb.QuizSession.v1").ToTimeLimitedDataProtector();

    public string Create(QuizSession session) =>
        _protector.Protect(JsonSerializer.Serialize(session), Lifetime);

    /// <summary>Returns null if the token is invalid, tampered with, or expired.</summary>
    public QuizSession? Read(string token)
    {
        try
        {
            return JsonSerializer.Deserialize<QuizSession>(_protector.Unprotect(token));
        }
        catch (Exception ex) when (ex is CryptographicException or FormatException or JsonException)
        {
            return null;
        }
    }
}
