
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up the router and auth provider
  final authProvider = AuthProvider();
  final appRouter = AppRouter(authProvider);

  runApp(MyApp(authProvider: authProvider, router: appRouter.router));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final GoRouter router;

  const MyApp({super.key, required this.authProvider, required this.router});

  @override
  Widget build(BuildContext context) {
    // The ChangeNotifierProvider provides the auth state to the rest of the app.
    return ChangeNotifierProvider.value(
      value: authProvider,
      child: MaterialApp.router(
        title: 'Admin Panel',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: router,
      ),
    );
  }
}
