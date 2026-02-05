
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'admin_screen.dart';

// 1. Auth Provider
class AuthProvider with ChangeNotifier {
  User? _user;
  User? get user => _user;

  AuthProvider() {
    // Listen to authentication state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      notifyListeners(); // Notify listeners (like GoRouter) of the change
    });
  }

  bool get isLoggedIn => _user != null;
}

// 2. GoRouter Configuration
class AppRouter {
  final AuthProvider authProvider;
  late final GoRouter router;

  AppRouter(this.authProvider) {
    router = GoRouter(
      refreshListenable: authProvider, // Re-evaluates the route when auth state changes
      initialLocation: '/admin', // Start at a protected route, redirect will handle it
      routes: [
        GoRoute(
          name: 'login',
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          name: 'admin',
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final bool isLoggedIn = authProvider.isLoggedIn;
        final bool isAtLoginPage = state.matchedLocation == '/login';

        // If the user is not logged in and not trying to go to login, redirect them.
        if (!isLoggedIn && !isAtLoginPage) {
          return '/login';
        }

        // If the user is logged in and trying to go to the login page, redirect to admin.
        if (isLoggedIn && isAtLoginPage) {
          return '/admin';
        }

        // No redirect needed.
        return null;
      },
    );
  }
}
