import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/login_page.dart';
import '../pages/main_page.dart';
import '../providers/auth_provider.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return switch (authState) {
      AuthAuthenticated() => const MainPage(),
      AuthLoading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _ => const LoginPage(),
    };
  }
}
