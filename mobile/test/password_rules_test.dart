import 'dart:io';

import 'package:dykb/auth/password_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rejected = {
    '1234567': 'at least 8 characters',
    '11111111': 'repeat one character',
    '12345678': 'simple runs',
    'hgfedcba': 'simple runs',
    'kobe24rules': 'username or email',
    'xxmambaxx99': 'username or email',
    'Password123': 'too common',
    'liverpool': 'too common',
  };
  rejected.forEach((password, reason) {
    test('rejects "$password"', () {
      expect(
        PasswordRules.validate(
          password,
          username: 'kobe24',
          email: 'mamba@example.com',
        ),
        contains(reason),
      );
    });
  });

  for (final ok in [
    '48201937',
    'hoops-and-dreams',
    'correct horse battery staple',
  ]) {
    test('accepts "$ok"', () {
      expect(
        PasswordRules.validate(
          ok,
          username: 'kobe24',
          email: 'mamba@example.com',
        ),
        isNull,
      );
    });
  }

  test('a short username is not treated as personal info', () {
    expect(PasswordRules.validate('xyabxy99', username: 'ab'), isNull);
  });

  test("the app's common-password list matches the API's", () {
    final apiList = File('../api/Dykb.Api/Resources/common-passwords.txt')
        .readAsLinesSync()
        .map((line) => line.trim().toLowerCase())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toSet();
    expect(PasswordRules.common, apiList);
  });
}
