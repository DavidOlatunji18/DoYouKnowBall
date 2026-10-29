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
    [InlineData(2, 100)]
    [InlineData(3, 225)]   // each level needs 25 more than the last: 100, then 125
    [InlineData(4, 375)]
    [InlineData(5, 550)]
    public void XpToReach_GrowsBy25EachLevel(int level, int xp) => Assert.Equal(xp, Levels.XpToReach(level));

    [Theory]
    [InlineData(0, 1)]
    [InlineData(99, 1)]
    [InlineData(100, 2)]
    [InlineData(224, 2)]
    [InlineData(225, 3)]
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
        // 640 XP: level 5 starts at 550 and level 6 at 750.
        Assert.Equal(new ProgressDto(640, 5, 90, 200, "Benchwarmer"), Levels.Progress(640));
    }
}
