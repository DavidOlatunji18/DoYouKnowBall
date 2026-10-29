using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Dykb.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class GameXp : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "XpEarned",
                table: "GameSessions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Games played before XP existed get the XP they would have earned.
            migrationBuilder.Sql(
                "UPDATE GameSessions SET XpEarned = Score * 10 + 20 + CASE WHEN Score = Total AND Total > 0 THEN 30 ELSE 0 END;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "XpEarned",
                table: "GameSessions");
        }
    }
}
