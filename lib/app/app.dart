import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/settings/presentation/privacy_consent_dialog.dart';
import 'routes.dart';
import 'theme.dart';

/// Root application widget.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '草料记账',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      builder: (context, child) => _PrivacyGate(child: child!),
    );
  }
}

/// Gate widget that shows the privacy consent dialog on first launch.
class _PrivacyGate extends StatefulWidget {
  const _PrivacyGate({required this.child});
  final Widget child;

  @override
  State<_PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<_PrivacyGate> {
  bool _checked = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _checkPrivacy();
  }

  Future<void> _checkPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(kPrivacyAcceptedKey) ?? false;
    if (mounted) {
      setState(() {
        _checked = true;
        _accepted = accepted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Always mount the child so the Navigator/Router stays in the tree.
        widget.child,
        if (!_checked)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (_checked && !_accepted)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: PrivacyConsentDialog(
                  onResult: (agreed) {
                    if (mounted) setState(() => _accepted = agreed);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
