import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'amount_visible';

/// Notifier that manages global amount visibility state.
///
/// When `true` amounts are shown normally; when `false` they are
/// replaced with `****` across Dashboard, Asset, Report and Flow pages.
class AmountVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true; // default: visible
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// Global provider for amount visibility.
final amountVisibilityProvider =
    NotifierProvider<AmountVisibilityNotifier, bool>(
  AmountVisibilityNotifier.new,
);
