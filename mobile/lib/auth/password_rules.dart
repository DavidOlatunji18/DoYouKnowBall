/// Sign-up password rules, matching the API's PasswordRules (which has the final
/// say). Following NIST guidance, they favour length and block guessable passwords
/// rather than forcing symbol and number mixes. Login accepts any password.
abstract final class PasswordRules {
  static const minLength = 8;
  static const maxLength = 100;

  /// Returns a message for the first broken rule, or null if the password is fine.
  static String? validate(
    String password, {
    String username = '',
    String email = '',
  }) {
    if (password.length < minLength) {
      return 'Use at least $minLength characters.';
    }
    if (password.length > maxLength) {
      return 'Use $maxLength characters or fewer.';
    }

    final lower = password.toLowerCase();
    if (lower.split('').toSet().length == 1) {
      return "Don't repeat one character over and over.";
    }
    if (_isSimpleRun(lower)) {
      return 'Avoid simple runs like 12345678 or abcdefgh.';
    }

    final emailName = email.split('@').first.toLowerCase();
    if (_contains(lower, username.toLowerCase()) ||
        _contains(lower, emailName)) {
      return "Don't include your username or email in your password.";
    }

    if (common.contains(lower)) {
      return 'That password is too common. Try something harder to guess.';
    }
    return null;
  }

  /// Every character is one step up (or down) from the previous one.
  static bool _isSimpleRun(String s) {
    final step = s.codeUnitAt(1) - s.codeUnitAt(0);
    if (step != 1 && step != -1) return false;
    for (var i = 2; i < s.length; i++) {
      if (s.codeUnitAt(i) - s.codeUnitAt(i - 1) != step) return false;
    }
    return true;
  }

  static bool _contains(String password, String value) =>
      value.length >= 3 && password.contains(value);

  /// Same list as api/Dykb.Api/Resources/common-passwords.txt (a test checks they match).
  static const common = {
    'password',
    'password1',
    'password12',
    'password123',
    'password1234',
    'passw0rd',
    'p@ssword',
    'p@ssw0rd',
    '12345678',
    '123456789',
    '1234567890',
    '12345678910',
    '123123123',
    '11223344',
    '12341234',
    '12344321',
    '87654321',
    '00000000',
    '11111111',
    '88888888',
    '99999999',
    'qwertyui',
    'qwerty12',
    'qwerty123',
    'qwerty1234',
    'qwertyuiop',
    '1q2w3e4r',
    '1q2w3e4r5t',
    '1qaz2wsx',
    'zaq12wsx',
    'asdfghjk',
    'asdfghjkl',
    'zxcvbnm1',
    'abc12345',
    'abcd1234',
    'abcdefgh',
    'aa123456',
    'iloveyou',
    'iloveyou1',
    'iloveyou2',
    'letmein1',
    'welcome1',
    'welcome123',
    'sunshine',
    'sunshine1',
    'princess',
    'princess1',
    'football',
    'football1',
    'baseball',
    'baseball1',
    'basketball',
    'basketball1',
    'soccer123',
    'hockey123',
    'superman',
    'batman123',
    'starwars',
    'whatever',
    'trustno1',
    'michelle',
    'jennifer',
    'jordan23',
    'michael1',
    'charlie1',
    'computer',
    'internet',
    'master123',
    'dragon123',
    'monkey123',
    'shadow123',
    'liverpool',
    'chelsea1',
    'arsenal1',
    'manchester',
    'barcelona',
    'realmadrid',
    'lakers24',
    'cowboys1',
    'steelers',
    'yankees1',
    '1234qwer',
    'qwer1234',
    'q1w2e3r4',
    'q1w2e3r4t5',
    'changeme',
    'changeme1',
    'default1',
    'admin123',
    'administrator',
    'login123',
    'secret123',
    'test1234',
    'testing123',
    'guest123',
    'user1234',
  };
}
