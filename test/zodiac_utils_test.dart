import 'package:flutter_test/flutter_test.dart';
import 'package:seizani_app/shared/utils/zodiac_utils.dart';

void main() {
  group('getWesternZodiacForDate', () {
    test('Aquarius Jan 20 – Feb 18', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 1, 20)),
        WesternZodiacSign.aquarius,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 2, 18)),
        WesternZodiacSign.aquarius,
      );
    });

    test('Pisces Feb 19 – Mar 20', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 2, 19)),
        WesternZodiacSign.pisces,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 3, 20)),
        WesternZodiacSign.pisces,
      );
    });

    test('Aries Mar 21 – Apr 19', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 3, 21)),
        WesternZodiacSign.aries,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 4, 19)),
        WesternZodiacSign.aries,
      );
    });

    test('Taurus Apr 20 – May 20', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 4, 20)),
        WesternZodiacSign.taurus,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 5, 20)),
        WesternZodiacSign.taurus,
      );
    });

    test('Gemini May 21 – Jun 21', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 5, 21)),
        WesternZodiacSign.gemini,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 6, 21)),
        WesternZodiacSign.gemini,
      );
    });

    test('Cancer Jun 22 – Jul 22', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 6, 22)),
        WesternZodiacSign.cancer,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 7, 22)),
        WesternZodiacSign.cancer,
      );
    });

    test('Leo Jul 23 – Aug 22', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 7, 23)),
        WesternZodiacSign.leo,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 8, 22)),
        WesternZodiacSign.leo,
      );
    });

    test('Virgo Aug 23 – Sep 22', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 8, 23)),
        WesternZodiacSign.virgo,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 9, 22)),
        WesternZodiacSign.virgo,
      );
    });

    test('Libra Sep 23 – Oct 23', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 9, 23)),
        WesternZodiacSign.libra,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 10, 23)),
        WesternZodiacSign.libra,
      );
    });

    test('Scorpio Oct 24 – Nov 22', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 10, 24)),
        WesternZodiacSign.scorpio,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 11, 22)),
        WesternZodiacSign.scorpio,
      );
    });

    test('Sagittarius Nov 23 – Dec 21', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 11, 23)),
        WesternZodiacSign.sagittarius,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 12, 21)),
        WesternZodiacSign.sagittarius,
      );
    });

    test('Capricorn Dec 22 – Jan 19 (wrap-around)', () {
      expect(
        getWesternZodiacForDate(DateTime(2025, 12, 22)),
        WesternZodiacSign.capricorn,
      );
      expect(
        getWesternZodiacForDate(DateTime(2025, 1, 19)),
        WesternZodiacSign.capricorn,
      );
    });
  });

  group('label helpers', () {
    test('English labels are non-empty', () {
      for (final sign in WesternZodiacSign.values) {
        expect(westernZodiacEnglishLabel(sign).isNotEmpty, true);
      }
    });

    test('Japanese labels are non-empty', () {
      for (final sign in WesternZodiacSign.values) {
        expect(westernZodiacJapaneseLabel(sign).isNotEmpty, true);
      }
    });
  });
}
