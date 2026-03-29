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
}

class MoonPhaseService {
  // Average lunar cycle length in days
  static const double _lunarCycle = 29.53058867;

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
    return days % _lunarCycle;
  }

  // Determine phase from age
  static MoonPhaseType _getPhaseFromAge(double age) {
    // Each phase is roughly 3.69 days
    const phaseLength = _lunarCycle / 8;

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
    final angle = (age / _lunarCycle) * 2 * math.pi;
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
        return 'Perfect for new beginnings and setting intentions';
      case MoonPhaseType.waxingCrescent:
        return 'Time to take action on your intentions';
      case MoonPhaseType.firstQuarter:
        return 'Face challenges and make decisions';
      case MoonPhaseType.waxingGibbous:
        return 'Refine and adjust your approach';
      case MoonPhaseType.fullMoon:
        return 'Peak energy for manifestation and release';
      case MoonPhaseType.waningGibbous:
        return 'Share wisdom and practice gratitude';
      case MoonPhaseType.lastQuarter:
        return 'Release what no longer serves you';
      case MoonPhaseType.waningCrescent:
        return 'Rest, reflect, and prepare for renewal';
    }
  }
}
