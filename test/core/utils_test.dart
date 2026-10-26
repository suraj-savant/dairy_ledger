import 'package:dairy_ledger/core/utils/fat.dart';
import 'package:dairy_ledger/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fat', () {
    test('key normalizes to at least one and at most two decimals', () {
      expect(Fat.key(4), '4.0');
      expect(Fat.key(4.1), '4.1');
      expect(Fat.key(4.10), '4.1');
      expect(Fat.key(4.25), '4.25');
      expect(Fat.key(3.0999999), '3.1');
    });

    test('seed chart runs from 3.0 to 10.0 in 0.1 steps (71 values)', () {
      final keys = Fat.seedKeys();
      expect(keys.length, 71);
      expect(keys.first, '3.0');
      expect(keys[1], '3.1');
      expect(keys.last, '10.0');
    });

    test('isCustom is true only outside the seed chart', () {
      expect(Fat.isCustom('4.5'), isFalse);
      expect(Fat.isCustom('10.5'), isTrue);
      expect(Fat.isCustom('4.25'), isTrue);
      expect(Fat.isCustom('2.8'), isTrue);
    });
  });

  group('Fmt', () {
    test('num drops trailing zeros', () {
      expect(Fmt.num(5), '5');
      expect(Fmt.num(5.5), '5.5');
      expect(Fmt.num(5.25), '5.25');
      expect(Fmt.num(0), '0');
    });

    test('money always has two decimals', () {
      expect(Fmt.money(286), '286.00');
      expect(Fmt.money(12.345), '12.35');
    });

    test('dateKey round-trips and sorts as text', () {
      final d = DateTime(2026, 10, 5);
      expect(Fmt.dateKey(d), '2026-10-05');
      expect(Fmt.parseKey('2026-10-05'), d);
      expect(Fmt.dateKey(DateTime(2026, 9, 30)).compareTo(Fmt.dateKey(d)) < 0, isTrue);
    });

    test('parseNum gives null for empty or invalid text', () {
      expect(Fmt.parseNum(''), isNull);
      expect(Fmt.parseNum('abc'), isNull);
      expect(Fmt.parseNum(' 4.2 '), 4.2);
    });
  });
}
