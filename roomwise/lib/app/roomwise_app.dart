import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/locale/locale_controller.dart';
import 'package:roomwise/core/search/search_state.dart';
import 'package:roomwise/features/guest/booking/sync/bookings_sync.dart';
import 'package:roomwise/features/guest/notifications/domain/notification_controller.dart';
import 'package:roomwise/features/guest/wishlist/wishlist_sync.dart';
import 'package:roomwise/l10n/app_localizations.dart';

final RouteObserver<ModalRoute<void>> roomWiseRouteObserver =
    RouteObserver<ModalRoute<void>>();

class RoomWiseRoot extends StatelessWidget {
  final RoomWiseApiClient apiClient;
  final AuthState authState;
  final LocaleController localeController;
  final Widget home;

  const RoomWiseRoot({
    super.key,
    required this.apiClient,
    required this.authState,
    required this.localeController,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RoomWiseApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthState>.value(value: authState),
        ChangeNotifierProvider<WishlistSync>(create: (_) => WishlistSync()),
        ChangeNotifierProvider<BookingsSync>(create: (_) => BookingsSync()),
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
      child: RoomWiseApp(home: home),
    );
  }
}

class RoomWiseApp extends StatelessWidget {
  final Widget home;

  const RoomWiseApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Roomwise',
      debugShowCheckedModeBanner: false,
      locale: localeController.locale,
      localizationsDelegates: const [
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
      navigatorObservers: [roomWiseRouteObserver],
      home: home,
    );
  }
}
