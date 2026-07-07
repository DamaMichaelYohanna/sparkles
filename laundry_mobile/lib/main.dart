import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/auth/auth_screen.dart';

void main() {
  runApp(const ProviderScope(child: LaundryApp()));
}

class LaundryApp extends StatelessWidget {
  const LaundryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sparkles',
      theme: AppTheme.lightTheme,
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
