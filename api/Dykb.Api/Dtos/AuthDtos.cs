using System.ComponentModel.DataAnnotations;

namespace Dykb.Api.Dtos;

public record RegisterRequest(
    [Required, EmailAddress, MaxLength(256)] string Email,
    // Strength rules (length, common passwords, etc.) are checked in AuthService via PasswordRules.
    [Required(ErrorMessage = "Pick a password.")] string Password,
    // Instagram-style username rules are checked in AuthService so each one gets a clear message.
    [Required(ErrorMessage = "Pick a username.")] string DisplayName);

public record LoginRequest(
    [Required(ErrorMessage = "Enter your email or username.")] string EmailOrUsername,
    [Required(ErrorMessage = "Enter your password.")] string Password);

public record UserDto(int Id, string Email, string DisplayName);

public record AuthResponse(string Token, UserDto User);
