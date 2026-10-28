using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Dykb.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ShuffledOptions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "OptionOrders",
                table: "QuizAttempts",
                type: "nvarchar(60)",
                maxLength: 60,
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "OptionOrders",
                table: "QuizAttempts");
        }
    }
}
