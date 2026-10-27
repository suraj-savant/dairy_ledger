import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/fat.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/rate_repository.dart';
import '../models/rate_chart.dart';

final rateRepositoryProvider = Provider<RateRepository>(
  (ref) => RateRepository(ref.watch(fsPathsProvider)),
  name: 'rateRepositoryProvider',
);

/// All rate charts of the admin, keyed by category.
class RatesNotifier extends AsyncNotifier<Map<String, RateChart>> {
  @override
  Future<Map<String, RateChart>> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return {};
    return ref.watch(rateRepositoryProvider).loadAll(user.uid);
  }

  String get _uid => ref.read(authRepositoryProvider).currentUser!.uid;
  Map<String, RateChart> get _charts => state.value ?? {};
  RateRepository get _repo => ref.read(rateRepositoryProvider);

  /// Adds a category seeded with fat 3.0 .. 10.0. Returns false when the name
  /// is empty or already exists.
  bool createCategory(String name) {
    final id = RateRepository.categoryId(name);
    if (id.isEmpty || _charts.containsKey(id)) return false;
    final chart = _repo.createCategory(_uid, name);
    state = AsyncData({..._charts, id: chart});
    ref.read(selectedCategoryProvider.notifier).select(id);
    return true;
  }

  /// Adds or edits one fat. Any fat is allowed (also outside 3.0 .. 10.0).
  void setFat(String category, double fat, double rate) {
    final chart = _charts[category];
    if (chart == null) return;
    final key = Fat.key(fat);
    _repo.setFat(_uid, category, key, rate);
    state = AsyncData({..._charts, category: chart.withFat(key, rate)});
  }

  /// Saves the whole edited chart (fat key -> rate) with a single write.
  void saveChart(String category, Map<String, double> edited) {
    final chart = _charts[category];
    if (chart == null) return;
    _repo.saveChart(_uid, category, chart.fats, edited);
    state = AsyncData({
      ..._charts,
      category: RateChart(category: category, fats: edited),
    });
  }

  void deleteCategory(String category) {
    _repo.deleteCategory(_uid, category);
    state = AsyncData({..._charts}..remove(category));
    ref.read(selectedCategoryProvider.notifier).select(null);
  }
}

final ratesProvider =
    AsyncNotifierProvider<RatesNotifier, Map<String, RateChart>>(
      RatesNotifier.new,
      name: 'ratesProvider',
    );

/// Category chosen in the Rates dropdown (null = first one).
class SelectedCategory extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authStateProvider); // a different user starts with no selection
    return null;
  }

  void select(String? category) => state = category;
}

final selectedCategoryProvider = NotifierProvider<SelectedCategory, String?>(
  SelectedCategory.new,
  name: 'selectedCategoryProvider',
);

/// True while the Rates tab is in edit mode. The home shell watches it to hide
/// the bottom navigation, so the tabs cannot be switched with unsaved edits.
class RatesEditing extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authStateProvider); // never carry edit mode over to another user
    return false;
  }

  void set(bool editing) => state = editing;
}

final ratesEditingProvider = NotifierProvider<RatesEditing, bool>(
  RatesEditing.new,
  name: 'ratesEditingProvider',
);
