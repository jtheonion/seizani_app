/// Zodiac utilities for converting a birth date to a western zodiac sign
/// and providing localized labels.
///
/// This module intentionally has no framework dependencies so it can be used
/// from domain/application layers and covered by unit tests easily.

/// Western zodiac signs.
enum WesternZodiacSign {
  aries, // おひつじ座
  taurus, // おうし座
  gemini, // ふたご座
  cancer, // かに座
  leo, // しし座
  virgo, // おとめ座
  libra, // てんびん座
  scorpio, // さそり座
  sagittarius, // いて座
  capricorn, // やぎ座
  aquarius, // みずがめ座
  pisces, // うお座
}

/// Returns the western zodiac sign for the given [date].
///
/// Date ranges are based on a commonly used standard:
/// - Aquarius:    Jan 20 – Feb 18
/// - Pisces:      Feb 19 – Mar 20
/// - Aries:       Mar 21 – Apr 19
/// - Taurus:      Apr 20 – May 20
/// - Gemini:      May 21 – Jun 21
/// - Cancer:      Jun 22 – Jul 22
/// - Leo:         Jul 23 – Aug 22
/// - Virgo:       Aug 23 – Sep 22
/// - Libra:       Sep 23 – Oct 23
/// - Scorpio:     Oct 24 – Nov 22
/// - Sagittarius: Nov 23 – Dec 21
/// - Capricorn:   Dec 22 – Jan 19 (wraps year-end)
WesternZodiacSign getWesternZodiacForDate(DateTime date) {
  final int month = date.month;
  final int day = date.day;

  // Capricorn: Dec 22 – Jan 19 (wrap-around)
  if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
    return WesternZodiacSign.capricorn;
  }

  if (_inRange(month, day, 1, 20, 2, 18)) return WesternZodiacSign.aquarius;
  if (_inRange(month, day, 2, 19, 3, 20)) return WesternZodiacSign.pisces;
  if (_inRange(month, day, 3, 21, 4, 19)) return WesternZodiacSign.aries;
  if (_inRange(month, day, 4, 20, 5, 20)) return WesternZodiacSign.taurus;
  if (_inRange(month, day, 5, 21, 6, 21)) return WesternZodiacSign.gemini;
  if (_inRange(month, day, 6, 22, 7, 22)) return WesternZodiacSign.cancer;
  if (_inRange(month, day, 7, 23, 8, 22)) return WesternZodiacSign.leo;
  if (_inRange(month, day, 8, 23, 9, 22)) return WesternZodiacSign.virgo;
  if (_inRange(month, day, 9, 23, 10, 23)) return WesternZodiacSign.libra;
  if (_inRange(month, day, 10, 24, 11, 22)) return WesternZodiacSign.scorpio;
  if (_inRange(month, day, 11, 23, 12, 21))
    return WesternZodiacSign.sagittarius;

  // Fallback (should never hit if ranges above cover the full year)
  return WesternZodiacSign.capricorn;
}

/// Inclusive date range checker for month/day ranges that do not wrap year-end.
bool _inRange(int m, int d, int startM, int startD, int endM, int endD) {
  if (m < startM || m > endM) return false;
  if (m == startM && d < startD) return false;
  if (m == endM && d > endD) return false;
  return true;
}

/// English label for the given zodiac [sign].
String westernZodiacEnglishLabel(WesternZodiacSign sign) {
  switch (sign) {
    case WesternZodiacSign.aries:
      return 'Aries';
    case WesternZodiacSign.taurus:
      return 'Taurus';
    case WesternZodiacSign.gemini:
      return 'Gemini';
    case WesternZodiacSign.cancer:
      return 'Cancer';
    case WesternZodiacSign.leo:
      return 'Leo';
    case WesternZodiacSign.virgo:
      return 'Virgo';
    case WesternZodiacSign.libra:
      return 'Libra';
    case WesternZodiacSign.scorpio:
      return 'Scorpio';
    case WesternZodiacSign.sagittarius:
      return 'Sagittarius';
    case WesternZodiacSign.capricorn:
      return 'Capricorn';
    case WesternZodiacSign.aquarius:
      return 'Aquarius';
    case WesternZodiacSign.pisces:
      return 'Pisces';
  }
}

/// Japanese label for the given zodiac [sign].
String westernZodiacJapaneseLabel(WesternZodiacSign sign) {
  switch (sign) {
    case WesternZodiacSign.aries:
      return 'おひつじ座';
    case WesternZodiacSign.taurus:
      return 'おうし座';
    case WesternZodiacSign.gemini:
      return 'ふたご座';
    case WesternZodiacSign.cancer:
      return 'かに座';
    case WesternZodiacSign.leo:
      return 'しし座';
    case WesternZodiacSign.virgo:
      return 'おとめ座';
    case WesternZodiacSign.libra:
      return 'てんびん座';
    case WesternZodiacSign.scorpio:
      return 'さそり座';
    case WesternZodiacSign.sagittarius:
      return 'いて座';
    case WesternZodiacSign.capricorn:
      return 'やぎ座';
    case WesternZodiacSign.aquarius:
      return 'みずがめ座';
    case WesternZodiacSign.pisces:
      return 'うお座';
  }
}
