import 'dart:math' as math;

enum MoonPhaseType {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

class MoonPhaseInfo {
  final MoonPhaseType phase;
  final String name;
  final double illumination; // 0.0 to 1.0
  final double age; // Days into lunar cycle (0-29.53)

  MoonPhaseInfo({
    required this.phase,
    required this.name,
    required this.illumination,
    required this.age,
  });

  String get illuminationPercent => '${(illumination * 100).round()}%';

  /// Position in the lunar cycle, 0 = new, 0.5 = full, approaching 1 = new.
  double get cycleFraction => age / MoonPhaseService.lunarCycle;
}

class MoonPhaseService {
  // Average lunar cycle length in days
  static const double lunarCycle = 29.53058867;

  // Reference new moon date (Jan 6, 2000 at 18:14 UTC)
  static final DateTime _referenceNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

  // Get current moon phase info
  static MoonPhaseInfo getCurrentMoonPhase() {
    return getMoonPhaseForDate(DateTime.now());
  }

  // Get moon phase for a specific date
  static MoonPhaseInfo getMoonPhaseForDate(DateTime date) {
    final age = _getMoonAge(date);
    final phase = _getPhaseFromAge(age);
    final illumination = _getIllumination(age);
    final name = _getPhaseName(phase);

    return MoonPhaseInfo(
      phase: phase,
      name: name,
      illumination: illumination,
      age: age,
    );
  }

  // Calculate days since reference new moon
  static double _getMoonAge(DateTime date) {
    final diff = date.toUtc().difference(_referenceNewMoon);
    final days = diff.inSeconds / 86400.0;
    return days % lunarCycle;
  }

  // Determine phase from age
  static MoonPhaseType _getPhaseFromAge(double age) {
    // Each phase is roughly 3.69 days
    const phaseLength = lunarCycle / 8;

    if (age < phaseLength * 0.5) {
      return MoonPhaseType.newMoon;
    } else if (age < phaseLength * 1.5) {
      return MoonPhaseType.waxingCrescent;
    } else if (age < phaseLength * 2.5) {
      return MoonPhaseType.firstQuarter;
    } else if (age < phaseLength * 3.5) {
      return MoonPhaseType.waxingGibbous;
    } else if (age < phaseLength * 4.5) {
      return MoonPhaseType.fullMoon;
    } else if (age < phaseLength * 5.5) {
      return MoonPhaseType.waningGibbous;
    } else if (age < phaseLength * 6.5) {
      return MoonPhaseType.lastQuarter;
    } else if (age < phaseLength * 7.5) {
      return MoonPhaseType.waningCrescent;
    } else {
      return MoonPhaseType.newMoon;
    }
  }

  // Calculate illumination percentage
  static double _getIllumination(double age) {
    // Use cosine to calculate illumination
    // 0 at new moon, 1 at full moon
    final angle = (age / lunarCycle) * 2 * math.pi;
    return (1 - math.cos(angle)) / 2;
  }

  // Get display name for phase
  static String _getPhaseName(MoonPhaseType phase) {
    switch (phase) {
      case MoonPhaseType.newMoon:
        return 'New Moon';
      case MoonPhaseType.waxingCrescent:
        return 'Waxing Crescent';
      case MoonPhaseType.firstQuarter:
        return 'First Quarter';
      case MoonPhaseType.waxingGibbous:
        return 'Waxing Gibbous';
      case MoonPhaseType.fullMoon:
        return 'Full Moon';
      case MoonPhaseType.waningGibbous:
        return 'Waning Gibbous';
      case MoonPhaseType.lastQuarter:
        return 'Last Quarter';
      case MoonPhaseType.waningCrescent:
        return 'Waning Crescent';
    }
  }

  // Get ritual meaning for the current phase
  static String getRitualMeaning(MoonPhaseType phase) {
    switch (phase) {
      case MoonPhaseType.newMoon:
        return 'A dark sky for new beginnings. Set one clear intention.';
      case MoonPhaseType.waxingCrescent:
        return 'The light is growing. Take a small step toward what you want.';
      case MoonPhaseType.firstQuarter:
        return 'Half lit, half waiting. A good night to make a decision.';
      case MoonPhaseType.waxingGibbous:
        return 'Almost full. Refine what you asked for.';
      case MoonPhaseType.fullMoon:
        return 'The brightest night of the cycle. Ask boldly, then let go.';
      case MoonPhaseType.waningGibbous:
        return 'The light is easing off. Name three things you are grateful for.';
      case MoonPhaseType.lastQuarter:
        return 'Release one thing that no longer fits.';
      case MoonPhaseType.waningCrescent:
        return 'A thin moon. Rest and let the cycle close.';
    }
  }
}
