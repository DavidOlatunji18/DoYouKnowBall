using System.Reflection;

namespace Dykb.Api.Services;

/// <summary>
/// Sign-up password rules, following NIST guidance: favour length and block guessable
/// passwords instead of forcing symbol/number mixes. Only applied when a password is
/// created, so existing passwords keep working. The mobile app applies the same rules
/// (lib/auth/password_rules.dart).
/// </summary>
public static class PasswordRules
{
    public const int MinLength = 8;
    public const int MaxLength = 100;

    private static readonly HashSet<string> Common = LoadCommonPasswords();

    /// <summary>Returns a message for the first broken rule, or null if the password is fine.</summary>
    public static string? Validate(string password, string username, string email)
    {
        if (password.Length < MinLength)
            return $"Use at least {MinLength} characters.";
        if (password.Length > MaxLength)
            return $"Use {MaxLength} characters or fewer.";

        var lower = password.ToLowerInvariant();
        if (lower.Distinct().Count() == 1)
            return "Don't repeat one character over and over.";
        if (IsSimpleRun(lower))
            return "Avoid simple runs like 12345678 or abcdefgh.";

        var emailName = email.Split('@')[0].ToLowerInvariant();
        if (ContainsPersonalInfo(lower, username.ToLowerInvariant()) || ContainsPersonalInfo(lower, emailName))
            return "Don't include your username or email in your password.";

        if (Common.Contains(lower))
            return "That password is too common. Try something harder to guess.";
        return null;
    }

    /// <summary>Every character is one step up (or down) from the previous one, e.g. "34567890" or "hgfedcba".</summary>
    private static bool IsSimpleRun(string s)
    {
        var step = s[1] - s[0];
        if (step is not (1 or -1)) return false;
        for (var i = 2; i < s.Length; i++)
        {
            if (s[i] - s[i - 1] != step) return false;
        }
        return true;
    }

    private static bool ContainsPersonalInfo(string password, string value) =>
        value.Length >= 3 && password.Contains(value);

    private static HashSet<string> LoadCommonPasswords()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Dykb.Api.Resources.common-passwords.txt")
            ?? throw new InvalidOperationException("common-passwords.txt is missing from the assembly.");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd()
            .Split('\n', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Where(line => !line.StartsWith('#'))
            .Select(line => line.ToLowerInvariant())
            .ToHashSet();
    }
}
