import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/guest_login_screen.dart';

class AdminRootShell extends StatelessWidget {
  const AdminRootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (!auth.isLoggedIn) {
      return const _AdminLoginGate();
    }

    if (!auth.isAdmin || auth.isGuest) {
      return const _AdminNotAuthorized();
    }

    return const _AdminHome();
  }
}

class _AdminLoginGate extends StatefulWidget {
  const _AdminLoginGate();

  @override
  State<_AdminLoginGate> createState() => _AdminLoginGateState();
}

class _AdminLoginGateState extends State<_AdminLoginGate> {
  bool _opening = false;

  Future<void> _openLogin() async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const GuestLoginScreen(audience: LoginAudience.admin),
        ),
      );

      if (!mounted) return;
      if (loggedIn != true) return;
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Admin panel'),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign in required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Log in with an administrator account to access the admin panel.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _opening ? null : _openLogin,
                      child: Text(_opening ? 'Opening…' : 'Log in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNotAuthorized extends StatelessWidget {
  const _AdminNotAuthorized();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Admin panel'),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Not authorized',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your account does not have the Administrator role.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () async {
                        await context.read<AuthState>().logout();
                      },
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Admin panel'),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                auth.email ?? '',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AuthState>().logout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Admin UI goes here (dashboard, hotels, reservations, users…).',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
