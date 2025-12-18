import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:roomwise/app/run_roomwise_app.dart';
import 'package:roomwise/features/guest/onboarding/onboarding_prefs.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/guest_root_shell.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/onboarding_screen_1.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Stripe.publishableKey =
      'pk_test_51SSHokLTIGnnOfLJWaCvyRUFWfKoggwc2MCZjKf2aHDjILirh3GFpCc3El41wB37kLvu3BFvwK0BcrDEUnTj4E60002kihvtQZ';

  await runRoomWiseApp(home: const _GuestAppBootstrapper());
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
