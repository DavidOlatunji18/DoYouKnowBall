using Dykb.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace Dykb.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Sport> Sports => Set<Sport>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Question> Questions => Set<Question>();
    public DbSet<GameSession> GameSessions => Set<GameSession>();
    public DbSet<QuizAttempt> QuizAttempts => Set<QuizAttempt>();
    public DbSet<QuizAnswer> QuizAnswers => Set<QuizAnswer>();

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        // All timestamps are stored as UTC; mark them as such on read so JSON includes the "Z".
        configurationBuilder.Properties<DateTime>().HaveConversion<UtcDateTimeConverter>();
    }

    private class UtcDateTimeConverter() : ValueConverter<DateTime, DateTime>(
        v => v.ToUniversalTime(),
        v => DateTime.SpecifyKind(v, DateTimeKind.Utc));

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(e =>
        {
            e.Property(u => u.Email).HasMaxLength(256);
            e.Property(u => u.DisplayName).HasMaxLength(30);
            e.HasIndex(u => u.Email).IsUnique();
            e.HasIndex(u => u.DisplayName).IsUnique();
        });

        modelBuilder.Entity<Sport>(e =>
        {
            e.Property(s => s.Name).HasMaxLength(50);
            e.HasIndex(s => s.Name).IsUnique();
        });

        modelBuilder.Entity<Category>(e =>
        {
            e.Property(c => c.Name).HasMaxLength(100);
            e.HasIndex(c => new { c.SportId, c.Name }).IsUnique();
        });

        modelBuilder.Entity<Question>(e =>
        {
            e.Property(q => q.Text).HasMaxLength(500);
            e.Property(q => q.Option1).HasMaxLength(200);
            e.Property(q => q.Option2).HasMaxLength(200);
            e.Property(q => q.Option3).HasMaxLength(200);
            e.Property(q => q.Option4).HasMaxLength(200);
            e.HasIndex(q => q.CategoryId);
            e.ToTable(t =>
            {
                t.HasCheckConstraint("CK_Questions_CorrectIndex", "[CorrectIndex] BETWEEN 0 AND 3");
                t.HasCheckConstraint("CK_Questions_Difficulty", "[Difficulty] BETWEEN 1 AND 3");
            });
        });

        modelBuilder.Entity<GameSession>(e =>
        {
            e.HasIndex(g => new { g.UserId, g.CategoryId });
            // Deleting a category must not silently wipe players' history.
            e.HasOne(g => g.Category).WithMany().OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<QuizAttempt>(e =>
        {
            e.Property(a => a.QuestionIds).HasMaxLength(200);
            // Two submits racing each other: only the first one's update matches.
            e.Property(a => a.SubmittedAt).IsConcurrencyToken();
            e.HasIndex(a => a.UserId);
            e.HasOne(a => a.Category).WithMany().OnDelete(DeleteBehavior.Restrict);
            // The user cascade already reaches game sessions, so this link can't cascade too.
            e.HasOne(a => a.GameSession).WithMany().OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<QuizAnswer>(e =>
        {
            // One answer per question per round, enforced by the database too.
            e.HasIndex(a => new { a.QuizAttemptId, a.QuestionId }).IsUnique();
        });
    }
}
