import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/register_page.dart';
import '../../features/home/home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final loggedIn = user != null;
      final location = state.uri.toString();

      if (!loggedIn && location != '/login') return '/login';
      if (loggedIn && location == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const AuthGate(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (_, __) => const HomeShell(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Error: ${state.error}')),
    ),
  );
});
