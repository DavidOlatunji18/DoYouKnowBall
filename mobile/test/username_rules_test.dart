import 'package:dykb/auth/username_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String type(String text) {
  var value = TextEditingValue.empty;
  for (final formatter in UsernameRules.inputFormatters) {
    value = formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
    text = value.text;
  }
  return value.text;
}

void main() {
  group('validate', () {
    for (final ok in ['kobe.bryant_24', 'k_b', '__mamba__', '123', 'a' * 30]) {
      test('accepts "$ok"', () => expect(UsernameRules.validate(ok), isNull));
    }

    final rejected = {
      'ab': '3-30 characters',
      'a' * 31: '3-30 characters',
      'kobe bryant': 'letters, numbers, periods and underscores',
      'Kobe': 'letters, numbers, periods and underscores',
      '.kobe': 'start or end with a period',
      'kobe.': 'start or end with a period',
      'kobe..24': 'two periods in a row',
    };
    rejected.forEach((name, reason) {
      test(
        'rejects "$name"',
        () => expect(UsernameRules.validate(name), contains(reason)),
      );
    });
  });

  group('typing filter', () {
    test('lowercases letters', () => expect(type('KobeBryant'), 'kobebryant'));
    test(
      'drops spaces, symbols and emoji',
      () => expect(type('kobe bryant!🏀#24'), 'kobebryant24'),
    );
    test(
      'keeps periods and underscores',
      () => expect(type('kobe.b_24'), 'kobe.b_24'),
    );
    test('drops accented letters', () => expect(type('kôbe'), 'kbe'));
    test('stops at 30 characters', () => expect(type('a' * 40).length, 30));

    test('keeps the cursor next to the character just typed', () {
      final formatted = UsernameRules.inputFormatters.first.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'ko Be',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(formatted.text, 'kobe');
      expect(formatted.selection.baseOffset, 3);
    });
  });
}
