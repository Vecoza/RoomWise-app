import 'package:flutter/material.dart';
import 'package:roomwise/app/roomwise_app.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/locale/locale_controller.dart';

Future<void> runRoomWiseApp({required Widget home}) async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: home,
    ),
  );
}

