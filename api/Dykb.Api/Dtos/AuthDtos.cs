using System.ComponentModel.DataAnnotations;

namespace Dykb.Api.Dtos;

public record RegisterRequest(
    [Required, EmailAddress, MaxLength(256)] string Email,
    [Required, MinLength(8, ErrorMessage = "Password must be at least 8 characters."), MaxLength(100)] string Password,
    [Required, MinLength(2, ErrorMessage = "Display name must be at least 2 characters."), MaxLength(30)] string DisplayName);

public record LoginRequest(
    [Required, EmailAddress] string Email,
    [Required] string Password);

public record UserDto(int Id, string Email, string DisplayName);

public record AuthResponse(string Token, UserDto User);
