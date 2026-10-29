using Dykb.Api.Dtos;

namespace Dykb.Api.Services;

/// <summary>
/// XP and levels. A round earns 10 XP per correct answer, 20 for finishing and 30 more
/// for a perfect score. The first levels come quickly: level 2 takes 300 XP and level 3 another
/// 500; every level after that takes 1,000. Every level falls in a rank, from Waterboy up to
/// YKB ("You Know Ball").
/// </summary>
public static class Levels
{
    public const int XpPerCorrect = 10;
    public const int XpPerRound = 20;
    public const int PerfectBonus = 30;
    public const int XpPerLevel = 1000;

    /// <summary>XP for the first level-ups (level 1 to 2, then 2 to 3), before every level takes <see cref="XpPerLevel"/>.</summary>
    private static readonly int[] EarlyLevels = [300, 500];

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
        var early = EarlyLevels.Take(steps).Sum();
        return early + XpPerLevel * Math.Max(steps - EarlyLevels.Length, 0);
    }

    public static int LevelFor(int xp)
    {
        var level = 1;
        foreach (var cost in EarlyLevels)
        {
            if (xp < cost)
                return level;
            xp -= cost;
            level++;
        }
        return level + xp / XpPerLevel;
    }

    public static string RankFor(int level) => Ranks.Last(r => level >= r.FromLevel).Name;

    public static ProgressDto Progress(int xp)
    {
        var level = LevelFor(xp);
        var start = XpToReach(level);
        return new ProgressDto(xp, level, xp - start, XpToReach(level + 1) - start, RankFor(level));
    }
}
