class LevelCalculator {
  // Level thresholds (exponential growth)
  static const Map<int, int> _levelThresholds = {
    1: 0,
    2: 100, // Spend 100 coins
    3: 300, // Spend 300 total
    4: 600,
    5: 1000,
    6: 1500,
    7: 2100,
    8: 2800,
    9: 3600,
    10: 4500,
    11: 5500,
    12: 6600,
    13: 7800,
    14: 9100,
    15: 10500,
    20: 20000,
    30: 50000,
    40: 100000,
    50: 200000,
  };

  /// Calculate level based on lifetime coins spent
  static int calculateLevel(int lifetimeCoinsSpent) {
    int level = 1;

    // Check defined thresholds
    for (var entry in _levelThresholds.entries) {
      if (lifetimeCoinsSpent >= entry.value) {
        level = entry.key;
      } else {
        break;
      }
    }

    // For levels beyond defined map, use formula:
    // Level = 50 + (coins - 200000) / 10000
    if (lifetimeCoinsSpent > 200000) {
      level = 50 + ((lifetimeCoinsSpent - 200000) / 10000).floor();
    }

    return level;
  }

  /// Get coins required to reach the next level
  static int getCoinsForNextLevel(int currentLevel) {
    if (currentLevel >= 50) {
      // Formula for high levels
      return 200000 + ((currentLevel - 50 + 1) * 10000);
    }

    // Find next threshold
    for (var entry in _levelThresholds.entries) {
      if (entry.key > currentLevel) {
        return entry.value;
      }
    }

    return 0; // Max level?
  }

  /// Get progress percentage to next level (0.0 to 1.0)
  static double getProgressToNextLevel(int lifetimeSpent, int currentLevel) {
    int currentThreshold = _getThresholdForLevel(currentLevel);
    int nextThreshold = getCoinsForNextLevel(currentLevel);

    if (nextThreshold <= currentThreshold) return 1.0;

    return (lifetimeSpent - currentThreshold) /
        (nextThreshold - currentThreshold);
  }

  static int _getThresholdForLevel(int level) {
    if (level >= 50) {
      return 200000 + ((level - 50) * 10000);
    }

    int threshold = 0;
    for (var entry in _levelThresholds.entries) {
      if (entry.key <= level) {
        threshold = entry.value;
      } else {
        break;
      }
    }
    return threshold;
  }
}
