import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/locale/locale_controller.dart';
import 'package:roomwise/features/booking/sync/bookings_sync.dart';
import 'package:roomwise/features/onboarding/onboarding_prefs.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_root_shell.dart';
import 'package:roomwise/features/onboarding/presentation/screens/onboarding_screen_1.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_landing_screen.dart';
import 'package:roomwise/features/wishlist/wishlist_sync.dart';
import 'package:roomwise/features/notifications/domain/notification_controller.dart';
import 'package:roomwise/core/search/search_state.dart';
import 'package:roomwise/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Stripe.publishableKey =
      'pk_test_51SSHokLTIGnnOfLJWaCvyRUFWfKoggwc2MCZjKf2aHDjILirh3GFpCc3El41wB37kLvu3BFvwK0BcrDEUnTj4E60002kihvtQZ';

  final api = RoomWiseApiClient();
  final auth = AuthState(api);
  await auth.loadFromStorage();
  final localeController = LocaleController();
  await localeController.load();

  runApp(
    RoomWiseRoot(
      apiClient: api,
      authState: auth,
      localeController: localeController,
    ),
  );
}

class RoomWiseRoot extends StatelessWidget {
  final RoomWiseApiClient apiClient;
  final AuthState authState;
  final LocaleController localeController;

  const RoomWiseRoot({
    super.key,
    required this.apiClient,
    required this.authState,
    required this.localeController,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RoomWiseApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthState>.value(value: authState),
        ChangeNotifierProvider<WishlistSync>(create: (_) => WishlistSync()),
        ChangeNotifierProvider(create: (_) => BookingsSync()),
        ChangeNotifierProvider<SearchState>(create: (_) => SearchState()),
        ChangeNotifierProvider<LocaleController>.value(value: localeController),
        ChangeNotifierProxyProvider<AuthState, NotificationController>(
          create: (context) => NotificationController(
            api: Provider.of<RoomWiseApiClient>(context, listen: false),
          ),
          update: (context, auth, controller) {
            controller ??= NotificationController(
              api: Provider.of<RoomWiseApiClient>(context, listen: false),
            );
            controller.handleAuthChanged(auth);
            return controller;
          },
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
    final localeController = context.watch<LocaleController>();
    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Roomwise',
      debugShowCheckedModeBanner: false,
      locale: localeController.locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('bs')],
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
