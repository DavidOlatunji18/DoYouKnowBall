using System.Text.RegularExpressions;

namespace Dykb.Api.Services;

/// <summary>
/// Instagram-style usernames: 3-30 characters of lowercase letters, numbers, periods and
/// underscores, with no period at the start or end and never two periods in a row.
/// The mobile app applies the same rules (lib/auth/username_rules.dart).
/// </summary>
public static partial class UsernameRules
{
    public const int MinLength = 3;
    public const int MaxLength = 30;

    [GeneratedRegex("^[a-z0-9._]+$")]
    private static partial Regex AllowedCharacters();

    /// <summary>Returns a message describing the first broken rule, or null if the username is valid.</summary>
    public static string? Validate(string username)
    {
        if (username.Length is < MinLength or > MaxLength)
            return $"Usernames must be {MinLength}-{MaxLength} characters.";
        if (!AllowedCharacters().IsMatch(username))
            return "Usernames can only use letters, numbers, periods and underscores.";
        if (username.StartsWith('.') || username.EndsWith('.'))
            return "Usernames can't start or end with a period.";
        if (username.Contains(".."))
            return "Usernames can't have two periods in a row.";
        return null;
    }
}
