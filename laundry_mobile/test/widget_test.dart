// Smoke test — verifies the app compiles and renders without errors.
// We test AuthScreen directly to avoid the async session-check timers in
// SplashRouterScreen which are incompatible with the synchronous test pump.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_mobile/core/theme.dart';
import 'package:laundry_mobile/features/auth/auth_screen.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          title: 'Sparkles',
          theme: AppTheme.lightTheme,
          home: const AuthScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    // Verify login screen renders its key elements
    expect(find.text('Sparkles'), findsOneWidget);
    expect(find.text('Sign in to your office'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
