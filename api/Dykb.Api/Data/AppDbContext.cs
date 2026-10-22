using Microsoft.EntityFrameworkCore;

namespace Dykb.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
}
