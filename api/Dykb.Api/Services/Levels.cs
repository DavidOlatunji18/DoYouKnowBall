using Dykb.Api.Dtos;

namespace Dykb.Api.Services;

/// <summary>
/// XP and levels. A round earns 10 XP per correct answer, 20 for finishing and 30 more
/// for a perfect score. Level 2 takes 100 XP and each level after needs 25 more than the
/// one before. Every level falls in a rank, from Waterboy up to YKB ("You Know Ball").
/// </summary>
public static class Levels
{
    public const int XpPerCorrect = 10;
    public const int XpPerRound = 20;
    public const int PerfectBonus = 30;

    /// <summary>Ranks by the level they start at, lowest first.</summary>
    public static readonly (int FromLevel, string Name)[] Ranks =
    [
        (1, "Waterboy"),
        (5, "Benchwarmer"),
        (10, "Casual"),
        (20, "Real Fan"),
        (30, "Certified"),
        (50, "Unc"),
        (75, "GOAT"),
        (100, "YKB"),
    ];

    public static XpEarnedDto ForRound(int score, int total)
    {
        var perfect = total > 0 && score == total ? PerfectBonus : 0;
        var correct = score * XpPerCorrect;
        return new XpEarnedDto(correct, XpPerRound, perfect, correct + XpPerRound + perfect);
    }

    /// <summary>Total XP needed to reach <paramref name="level"/> (0 for level 1).</summary>
    public static int XpToReach(int level)
    {
        var steps = Math.Max(level - 1, 0);
        return 100 * steps + 25 * steps * (steps - 1) / 2;
    }

    public static int LevelFor(int xp)
    {
        var level = 1;
        while (XpToReach(level + 1) <= xp)
            level++;
        return level;
    }

    public static string RankFor(int level) => Ranks.Last(r => level >= r.FromLevel).Name;

    public static ProgressDto Progress(int xp)
    {
        var level = LevelFor(xp);
        var start = XpToReach(level);
        return new ProgressDto(xp, level, xp - start, XpToReach(level + 1) - start, RankFor(level));
    }
}
