import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used in SharedPreferences to track privacy consent.
const String kPrivacyAcceptedKey = 'privacy_accepted';

/// A full-screen dialog that shows the privacy policy and requires user consent.
///
/// - The dialog cannot be dismissed by tapping outside or pressing back.
/// - The "同意" button is disabled until the user checks the checkbox.
/// - Pressing "不同意" exits the app via [SystemNavigator.pop].
class PrivacyConsentDialog extends StatefulWidget {
  const PrivacyConsentDialog({super.key, this.onResult});

  /// Called when the user agrees or disagrees.
  /// If null, the widget will try to pop a Navigator route instead.
  final ValueChanged<bool>? onResult;

  @override
  State<PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends State<PrivacyConsentDialog> {
  bool _agreed = false;
  String _markdown = '';

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    final content = await rootBundle.loadString('assets/privacy_policy.md');
    if (mounted) {
      setState(() => _markdown = content);
    }
  }

  Future<void> _onAgree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrivacyAcceptedKey, true);
    if (mounted) {
      widget.onResult?.call(true);
    }
  }

  Future<void> _onDisagree() async {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('隐私政策'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            children: [
              Expanded(
                child: _markdown.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : Markdown(
                        data: _markdown,
                        selectable: true,
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: const Text(
                        '我已阅读并同意以上隐私政策',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _onDisagree,
            child: const Text('不同意'),
          ),
          FilledButton(
            onPressed: _agreed ? _onAgree : null,
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }
}
