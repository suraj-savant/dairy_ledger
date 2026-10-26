import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_paths.dart';
import '../../../core/firestore/firestore_reads.dart';
import '../../../core/firestore/write_tracker.dart';
import '../models/rate_chart.dart';

/// Rate charts live in `users/{uid}/rates/{CATEGORY}`: one document per
/// category, so loading the whole chart is a single (cached) read.
class RateRepository {
  RateRepository(this._paths);
  final FsPaths _paths;

  /// Category name -> document ID: trimmed, upper case, no slashes.
  static String categoryId(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll('/', '-').toUpperCase();

  /// All charts of the admin. Served from the cache; the server is only asked
  /// when the cache is empty (new device / first run).
  Future<Map<String, RateChart>> loadAll(String uid) async {
    final col = _paths.rates(uid);
    QuerySnapshot<Json>? snap;
    try {
      snap = await getQueryFromCache(col, label: col.path);
    } on FirebaseException {
      snap = null; // cache unavailable: fall back to the server below
    }
    if (snap == null || snap.docs.isEmpty) {
      snap = await getQueryFromServer(col, label: col.path);
    }
    return {
      for (final d in snap.docs) d.id: RateChart.fromMap(d.id, d.data()),
    };
  }

  /// Creates a category seeded with fat 3.0 .. 10.0 at rate 0.
  RateChart createCategory(String uid, String name) {
    final id = categoryId(name);
    final chart = RateChart.seeded(id);
    final ref = _paths.rates(uid).doc(id);
    trackWrite(
      'create ${ref.path} (${chart.fats.length} fats)',
      ref.set({
        'fats': chart.fats,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return chart;
  }

  /// Sets (adds or edits) one fat's rate. `FieldPath` is required because
  /// fat keys contain a dot ("3.5").
  void setFat(String uid, String category, String fatKey, double rate) {
    final ref = _paths.rates(uid).doc(category);
    trackWrite(
      'update ${ref.path} fats[$fatKey]=$rate',
      ref.update({
        FieldPath(['fats', fatKey]): rate,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  void removeFat(String uid, String category, String fatKey) {
    final ref = _paths.rates(uid).doc(category);
    trackWrite(
      'update ${ref.path} remove fats[$fatKey]',
      ref.update({
        FieldPath(['fats', fatKey]): FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  void deleteCategory(String uid, String category) {
    final ref = _paths.rates(uid).doc(category);
    trackWrite('delete ${ref.path}', ref.delete());
  }
}
