import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/features/onboarding/onboarding_prefs.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_root_shell.dart';
import 'package:roomwise/features/onboarding/presentation/screens/onboarding_screen_1.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_landing_screen.dart';

void main() {
  runApp(const RoomWiseRoot());
}

class RoomWiseRoot extends StatelessWidget {
  const RoomWiseRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RoomWiseApiClient>(create: (_) => RoomWiseApiClient()),
        ChangeNotifierProvider<AuthState>(
          create: (context) =>
              AuthState(Provider.of<RoomWiseApiClient>(context, listen: false)),
        ),
      ],
      child: const RoomWiseApp(),
    );
  }
}

class RoomWiseApp extends StatelessWidget {
  const RoomWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF05A87A)),
      ),
      home: const _AppBootstrapper(),
    );
  }
}

class _AppBootstrapper extends StatefulWidget {
  const _AppBootstrapper({super.key});

  @override
  State<_AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<_AppBootstrapper> {
  bool _ready = false;
  bool _seenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthState>();
    await auth.loadFromStorage();

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
      // return const GuestLandingScreen();
      return const GuestRootShell();
    } else {
      return const OnboardingScreen1();
    }
  }
}
