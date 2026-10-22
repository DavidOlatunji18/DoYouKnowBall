using System.Text;
using Dykb.Api.Data;
using Dykb.Api.Dtos;
using Dykb.Api.Infrastructure;
using Dykb.Api.Models;
using Dykb.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;

// `dotnet Dykb.Api.dll --seed` applies migrations, syncs seed questions, and exits (used for prod).
var seedAndExit = args.Contains("--seed");
var builder = WebApplication.CreateBuilder(args.Where(a => a != "--seed").ToArray());

var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured.");
var jwt = builder.Configuration.GetSection(JwtOptions.Section).Get<JwtOptions>() ?? new JwtOptions();
if (Encoding.UTF8.GetByteCount(jwt.Key) < 32)
    throw new InvalidOperationException("Jwt:Key must be configured and at least 32 bytes long.");

builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlServer(connectionString));
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.Section));
builder.Services.AddDataProtection();

builder.Services.AddScoped<IPasswordHasher<User>, PasswordHasher<User>>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<QuizService>();
builder.Services.AddScoped<GameService>();
builder.Services.AddSingleton<QuizSessionTokens>();
builder.Services.AddScoped<SeedLoader>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        // Keep claim names as issued ("sub", "email", "name") instead of mapping to long URIs.
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
        options.Events = new JwtBearerEvents
        {
            OnChallenge = context =>
            {
                context.HandleResponse();
                return ExceptionHandlingMiddleware.WriteErrorAsync(
                    context.HttpContext, StatusCodes.Status401Unauthorized, "Please log in to continue.");
            },
        };
    });

// Every endpoint requires a valid JWT unless it opts out with [AllowAnonymous].
builder.Services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

var corsOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy.WithOrigins(corsOrigins).AllowAnyHeader().AllowAnyMethod()));

builder.Services.AddControllers().ConfigureApiBehaviorOptions(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var invalid = context.ModelState.Where(e => e.Value?.Errors.Count > 0).ToList();
        var message = invalid.Any(e => e.Key.StartsWith('$'))
            ? "The request body is not valid JSON."
            : invalid.Select(e => e.Value!.Errors[0].ErrorMessage).FirstOrDefault() ?? "Invalid request.";
        return new BadRequestObjectResult(new ErrorResponse(message));
    };
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Do You Know Ball? API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Paste the token from /auth/login.",
    });
    c.AddSecurityRequirement(doc => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", doc)] = [],
    });
});

var app = builder.Build();

if (seedAndExit || app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync();
    await scope.ServiceProvider.GetRequiredService<SeedLoader>()
        .LoadAsync(Path.Combine(AppContext.BaseDirectory, "seed"));
    if (seedAndExit)
        return;
}

app.UseMiddleware<ExceptionHandlingMiddleware>();

// Swagger is served before auth so the docs page itself doesn't need a token.
app.UseSwagger();
app.UseSwaggerUI();

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" })).AllowAnonymous();
app.MapControllers();

app.Run();

public partial class Program;
