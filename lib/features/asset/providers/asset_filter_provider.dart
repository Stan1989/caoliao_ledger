import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dimension for asset page filtering.
enum AssetFilterMode { all, month, year }

/// State for asset page period filter.
class AssetFilterState {
  final AssetFilterMode mode;
  final DateTime selectedDate; // year+month used for month mode, year for year mode

  const AssetFilterState({
    this.mode = AssetFilterMode.all,
    required this.selectedDate,
  });

  AssetFilterState copyWith({AssetFilterMode? mode, DateTime? selectedDate}) {
    return AssetFilterState(
      mode: mode ?? this.mode,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class AssetFilterNotifier extends Notifier<AssetFilterState> {
  @override
  AssetFilterState build() {
    final now = DateTime.now();
    return AssetFilterState(selectedDate: DateTime(now.year, now.month));
  }

  void setMode(AssetFilterMode mode) {
    state = state.copyWith(mode: mode);
  }

  void previousPeriod() {
    final d = state.selectedDate;
    switch (state.mode) {
      case AssetFilterMode.month:
        state = state.copyWith(selectedDate: DateTime(d.year, d.month - 1));
      case AssetFilterMode.year:
        state = state.copyWith(selectedDate: DateTime(d.year - 1, d.month));
      case AssetFilterMode.all:
        break;
    }
  }

  void nextPeriod() {
    final d = state.selectedDate;
    switch (state.mode) {
      case AssetFilterMode.month:
        state = state.copyWith(selectedDate: DateTime(d.year, d.month + 1));
      case AssetFilterMode.year:
        state = state.copyWith(selectedDate: DateTime(d.year + 1, d.month));
      case AssetFilterMode.all:
        break;
    }
  }
}

final assetFilterProvider =
    NotifierProvider<AssetFilterNotifier, AssetFilterState>(
  AssetFilterNotifier.new,
);
