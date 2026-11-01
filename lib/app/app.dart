import 'package:flutter/material.dart';

import '../core/app_store.dart';
import '../core/app_theme.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/shell/app_shell.dart';

class CamsGoldApp extends StatefulWidget {
  const CamsGoldApp({super.key});

  @override
  State<CamsGoldApp> createState() => _CamsGoldAppState();
}

class _CamsGoldAppState extends State<CamsGoldApp> {
  final AppStore _store = AppStore();
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Comptoir d'Or",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _store.isSignedIn
          ? AppShell(store: _store, onSignOut: _signOut)
          : _showRegister
          ? RegisterScreen(
              onRegister: _signIn,
              onShowLogin: () => setState(() => _showRegister = false),
            )
          : LoginScreen(
              onLogin: _signIn,
              onShowRegister: () => setState(() => _showRegister = true),
            ),
    );
  }

  void _signIn(String name) {
    setState(() {
      _store.signIn(name);
      _showRegister = false;
    });
  }

  void _signOut() {
    setState(_store.signOut);
  }
}
