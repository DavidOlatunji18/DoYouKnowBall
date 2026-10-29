using Dykb.Api.Dtos;
using Dykb.Api.Services;

namespace Dykb.Api.Tests;

public class LevelsTests
{
    [Theory]
    [InlineData(7, 10, 70, 0, 90)]
    [InlineData(10, 10, 100, 30, 150)]
    [InlineData(0, 10, 0, 0, 20)]
    [InlineData(3, 3, 30, 30, 80)]   // a short round can still be perfect
    public void ForRound_AddsCorrectAnswersRoundAndPerfectBonus(int score, int total, int correct, int perfect, int sum) =>
        Assert.Equal(new XpEarnedDto(correct, 20, perfect, sum), Levels.ForRound(score, total));

    [Theory]
    [InlineData(1, 0)]
    [InlineData(2, 300)]     // the first level-up takes 300
    [InlineData(3, 800)]     // the second another 500
    [InlineData(4, 1800)]    // then 1,000 each
    [InlineData(100, 97800)]
    public void XpToReach_StartsQuickThen1000PerLevel(int level, int xp) => Assert.Equal(xp, Levels.XpToReach(level));

    [Theory]
    [InlineData(0, 1)]
    [InlineData(299, 1)]
    [InlineData(300, 2)]
    [InlineData(799, 2)]
    [InlineData(800, 3)]
    [InlineData(1799, 3)]
    [InlineData(1800, 4)]
    [InlineData(97800, 100)]
    public void LevelFor_ChangesExactlyAtTheThreshold(int xp, int level) => Assert.Equal(level, Levels.LevelFor(xp));

    [Theory]
    [InlineData(1, "Waterboy")]
    [InlineData(4, "Waterboy")]
    [InlineData(5, "Benchwarmer")]
    [InlineData(10, "Casual")]
    [InlineData(20, "Real Fan")]
    [InlineData(30, "Certified")]
    [InlineData(50, "Unc")]
    [InlineData(75, "GOAT")]
    [InlineData(99, "GOAT")]
    [InlineData(100, "YKB")]
    [InlineData(250, "YKB")]
    public void RankFor_UsesTheRankLadder(int level, string rank) => Assert.Equal(rank, Levels.RankFor(level));

    [Fact]
    public void Progress_SplitsXpIntoTheCurrentLevel()
    {
        // 4,640 XP: level 6 starts at 3,800 and level 7 at 4,800.
        Assert.Equal(new ProgressDto(4640, 6, 840, 1000, "Benchwarmer"), Levels.Progress(4640));
        // Early levels report their own, smaller targets.
        Assert.Equal(new ProgressDto(450, 2, 150, 500, "Waterboy"), Levels.Progress(450));
    }
}
