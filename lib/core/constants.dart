/// App-wide constants. Keep magic numbers here so rules, UI and tests agree.
class AppConstants {
  AppConstants._();

  static const String appName = 'Dairy Ledger';

  // Bill cycle (number of days covered by one bill, shown as a "week").
  static const int defaultBillCycleDays = 7;
  static const int minBillCycleDays = 1;
  static const int maxBillCycleDays = 31;

  // Rate chart seed: fat 3.0 .. 10.0 in 0.1 steps. Other fats are added manually.
  static const double fatMin = 3.0;
  static const double fatMax = 10.0;
  static const double fatStep = 0.1;

  /// Bills fetched per page ("Load older" fetches another page).
  static const int billPageSize = 5;

  /// Minimum gap between automatic delta syncs of the same collection.
  static const Duration syncThrottle = Duration(minutes: 1);

  static const String countryCode = '+91';
  static const int phoneLength = 10;
  static const int otpLength = 6;
}

/// Milking session. The value is the key stored in Firestore.
enum Session {
  morning('M', 'Morning'),
  evening('E', 'Evening');

  const Session(this.key, this.label);
  final String key;
  final String label;
}
