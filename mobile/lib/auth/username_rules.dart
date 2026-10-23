import 'package:flutter/services.dart';

/// Instagram-style usernames: 3-30 characters of lowercase letters, numbers,
/// periods and underscores, with no period at the start or end and never two
/// periods in a row. Mirrors the API's UsernameRules, which has the final say.
abstract final class UsernameRules {
  static const minLength = 3;
  static const maxLength = 30;

  static const hint = 'Letters, numbers, periods and underscores.';

  /// Returns a message for the first broken rule, or null if [username] is valid.
  static String? validate(String username) {
    if (username.length < minLength || username.length > maxLength) {
      return 'Usernames must be $minLength-$maxLength characters.';
    }
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(username)) {
      return 'Usernames can only use letters, numbers, periods and underscores.';
    }
    if (username.startsWith('.') || username.endsWith('.')) {
      return "Usernames can't start or end with a period.";
    }
    if (username.contains('..')) {
      return "Usernames can't have two periods in a row.";
    }
    return null;
  }

  /// Lowercases what the player types and drops characters a username can't
  /// contain (spaces, emoji, symbols), capped at [maxLength].
  static final inputFormatters = <TextInputFormatter>[
    _UsernameFormatter(),
    LengthLimitingTextInputFormatter(maxLength),
  ];
}

class _UsernameFormatter extends TextInputFormatter {
  static final _allowed = RegExp(r'[a-z0-9._]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allowed characters are all single ASCII code units, so anything else
    // (accents, emoji, surrogate halves) is simply dropped.
    final input = newValue.text;
    final cursor = newValue.selection.baseOffset < 0
        ? input.length
        : newValue.selection.baseOffset;
    final buffer = StringBuffer();
    var keptBeforeCursor = 0;

    for (var i = 0; i < input.length; i++) {
      final lower = input[i].toLowerCase();
      if (!_allowed.hasMatch(lower)) continue;
      buffer.write(lower);
      if (i < cursor) keptBeforeCursor++;
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: keptBeforeCursor),
    );
  }
}
