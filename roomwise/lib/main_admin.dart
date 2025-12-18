import 'package:flutter/material.dart';
import 'package:roomwise/app/run_roomwise_app.dart';
import 'package:roomwise/features/admin/presentation/screens/admin_root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runRoomWiseApp(home: const AdminRootShell());
}

