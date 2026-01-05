import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:roomwise/app/run_roomwise_app.dart';
import 'package:roomwise/features/guest/onboarding/onboarding_prefs.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/guest_root_shell.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/onboarding_screen_1.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final envKey = await _loadStripeKey();
  final definedKey = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  final stripeKey = envKey?.isNotEmpty == true ? envKey! : definedKey;
  if (stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
    debugPrint(
      'Stripe key loaded from ${envKey?.isNotEmpty == true ? 'asset' : 'dart-define'}.',
    );
  } else {
    debugPrint('Missing STRIPE_PUBLISHABLE_KEY.');
  }

  await runRoomWiseApp(home: const _GuestAppBootstrapper());
}

Future<String?> _loadStripeKey() async {
  const candidates = ['.env', 'stripe.env'];
  for (final asset in candidates) {
    try {
      final content = await rootBundle.loadString(asset);
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final idx = trimmed.indexOf('=');
        if (idx <= 0) continue;
        final key = trimmed.substring(0, idx).trim();
        if (key != 'STRIPE_PUBLISHABLE_KEY') continue;
        var value = trimmed.substring(idx + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        return value;
      }
    } catch (e) {
      debugPrint('Failed to load $asset: $e');
    }
  }
  return null;
}

class _GuestAppBootstrapper extends StatefulWidget {
  const _GuestAppBootstrapper();

  @override
  State<_GuestAppBootstrapper> createState() => _GuestAppBootstrapperState();
}

class _GuestAppBootstrapperState extends State<_GuestAppBootstrapper> {
  bool _ready = false;
  bool _seenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final seen = await OnboardingPrefs.hasSeenOnboarding();
    if (!mounted) return;
    setState(() {
      _seenOnboarding = seen;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_seenOnboarding) {
      return const GuestRootShell();
    }
    return const OnboardingScreen1();
  }
}
