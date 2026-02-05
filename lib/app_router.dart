
import 'dart:async'; // Import async library for StreamSubscription
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'admin_screen.dart';
import 'public_games_screen.dart'; // Import the new public screen

class AppRouter {
  final GoRouter router;

  AppRouter() : router = _createRouter();

  static GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/', // Start at the public page
      routes: [
        // Public route that everyone can see
        GoRoute(
          path: '/',
          builder: (context, state) => const PublicGamesScreen(),
        ),
        // Private route for the admin panel
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
        // Private route for the login page
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final bool loggedIn = FirebaseAuth.instance.currentUser != null;
        final String location = state.uri.toString();

        // --- Security Logic ---

        // If the user is NOT logged in and tries to access the admin page,
        // redirect them to the public home page.
        if (!loggedIn && location == '/admin') {
          return '/'; // Redirect to public page, not login page
        }

        // If the user IS logged in and tries to access the login page,
        // redirect them to the admin panel.
        if (loggedIn && location == '/login') {
          return '/admin';
        }

        // No redirect needed
        return null;
      },
      // This listener will automatically refresh the router when the auth state changes
      refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    );
  }
}

// This class is used to listen to Firebase auth changes and rebuild the router
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;

  GoRouterRefreshStream(Stream<User?> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
