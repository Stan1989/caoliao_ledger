import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/features/settings/presentation/privacy_consent_dialog.dart';

class _TestAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'assets/privacy_policy.md') {
      return '# Privacy\n\nTest policy content';
    }
    throw FlutterError('Unexpected asset request: $key');
  }

  @override
  Future<ByteData> load(String key) {
    throw FlutterError('Unexpected binary asset request: $key');
  }
}

void main() {
  testWidgets('privacy consent markdown is not selectable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _TestAssetBundle(),
        child: const MaterialApp(
          home: Scaffold(
            body: PrivacyConsentDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.selectable, isFalse);
  });
}