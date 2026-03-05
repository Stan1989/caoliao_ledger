import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';

/// Data class holding the persisted default selections for the record form.
class RecordDefaultsData {
  const RecordDefaultsData({
    this.categoryId,
    this.categoryName,
    this.accountId,
    this.accountName,
    this.toAccountId,
    this.toAccountName,
    this.memberId,
    this.memberName,
    this.projectId,
    this.projectName,
  });

  final int? categoryId;
  final String? categoryName;
  final int? accountId;
  final String? accountName;
  final int? toAccountId;
  final String? toAccountName;
  final int? memberId;
  final String? memberName;
  final int? projectId;
  final String? projectName;

  /// Create from JSON map.
  factory RecordDefaultsData.fromJson(Map<String, dynamic> json) {
    return RecordDefaultsData(
      categoryId: json['categoryId'] as int?,
      categoryName: json['categoryName'] as String?,
      accountId: json['accountId'] as int?,
      accountName: json['accountName'] as String?,
      toAccountId: json['toAccountId'] as int?,
      toAccountName: json['toAccountName'] as String?,
      memberId: json['memberId'] as int?,
      memberName: json['memberName'] as String?,
      projectId: json['projectId'] as int?,
      projectName: json['projectName'] as String?,
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'accountId': accountId,
        'accountName': accountName,
        'toAccountId': toAccountId,
        'toAccountName': toAccountName,
        'memberId': memberId,
        'memberName': memberName,
        'projectId': projectId,
        'projectName': projectName,
      };

  /// Returns a copy with invalid fields (those that failed DB validation)
  /// set to null.
  RecordDefaultsData copyWithNulled({
    bool clearCategory = false,
    bool clearAccount = false,
    bool clearToAccount = false,
    bool clearMember = false,
    bool clearProject = false,
  }) {
    return RecordDefaultsData(
      categoryId: clearCategory ? null : categoryId,
      categoryName: clearCategory ? null : categoryName,
      accountId: clearAccount ? null : accountId,
      accountName: clearAccount ? null : accountName,
      toAccountId: clearToAccount ? null : toAccountId,
      toAccountName: clearToAccount ? null : toAccountName,
      memberId: clearMember ? null : memberId,
      memberName: clearMember ? null : memberName,
      projectId: clearProject ? null : projectId,
      projectName: clearProject ? null : projectName,
    );
  }
}

/// Service that persists and retrieves record form default selections
/// using SharedPreferences.
class RecordDefaultsService {
  RecordDefaultsService(this._prefs);

  final SharedPreferences _prefs;

  /// SharedPreferences key format: `record_defaults_{ledgerId}_{typeName}`
  static String _key(int ledgerId, TransactionType type) =>
      'record_defaults_${ledgerId}_${type.name}';

  /// Save the current form selections as defaults for the given ledger + type.
  Future<void> save(
    int ledgerId,
    TransactionType type,
    RecordDefaultsData data,
  ) async {
    final json = jsonEncode(data.toJson());
    await _prefs.setString(_key(ledgerId, type), json);
  }

  /// Load persisted defaults for the given ledger + type.
  /// Returns null if nothing has been saved yet.
  RecordDefaultsData? load(int ledgerId, TransactionType type) {
    final json = _prefs.getString(_key(ledgerId, type));
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return RecordDefaultsData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Load defaults and validate each ID against the database.
  /// Invalid IDs (deleted entities or wrong ledger) are set to null.
  Future<RecordDefaultsData?> loadAndValidate(
    int ledgerId,
    TransactionType type,
    AppDatabase db,
  ) async {
    final data = load(ledgerId, type);
    if (data == null) return null;

    bool clearCategory = false;
    bool clearAccount = false;
    bool clearToAccount = false;
    bool clearMember = false;
    bool clearProject = false;

    // Validate categoryId
    if (data.categoryId != null) {
      final cat = await db.categoryDao.getById(data.categoryId!);
      if (cat == null || cat.ledgerId != ledgerId) {
        clearCategory = true;
      }
    }

    // Validate accountId (must exist AND belong to this ledger)
    if (data.accountId != null) {
      final acc = await db.accountDao.getById(data.accountId!);
      if (acc == null || acc.ledgerId != ledgerId) {
        clearAccount = true;
      }
    }

    // Validate toAccountId
    if (data.toAccountId != null) {
      final acc = await db.accountDao.getById(data.toAccountId!);
      if (acc == null || acc.ledgerId != ledgerId) {
        clearToAccount = true;
      }
    }

    // Validate memberId
    if (data.memberId != null) {
      final member = await db.memberDao.getById(data.memberId!);
      if (member == null || member.ledgerId != ledgerId) {
        clearMember = true;
      }
    }

    // Validate projectId
    if (data.projectId != null) {
      final project = await db.projectDao.getById(data.projectId!);
      if (project == null || project.ledgerId != ledgerId) {
        clearProject = true;
      }
    }

    // If nothing needs clearing, return as-is
    if (!clearCategory &&
        !clearAccount &&
        !clearToAccount &&
        !clearMember &&
        !clearProject) {
      return data;
    }

    return data.copyWithNulled(
      clearCategory: clearCategory,
      clearAccount: clearAccount,
      clearToAccount: clearToAccount,
      clearMember: clearMember,
      clearProject: clearProject,
    );
  }
}

/// Provider for [RecordDefaultsService].
/// Uses [SharedPreferences.getInstance()] lazily.
final recordDefaultsServiceProvider = Provider<RecordDefaultsService>((ref) {
  // SharedPreferences.getInstance() returns a cached singleton after first call,
  // so this is effectively synchronous after app startup.
  throw UnimplementedError(
    'recordDefaultsServiceProvider must be overridden with a valid instance',
  );
});
