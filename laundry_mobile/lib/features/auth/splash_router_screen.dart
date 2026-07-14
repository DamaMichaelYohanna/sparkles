import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../auth/auth_screen.dart';
import '../shell/shell_screen.dart';

/// Displayed on cold start. Checks the stored session and routes accordingly:
/// - Has a valid access token  → ShellScreen (no login needed)
/// - Has a refresh token only  → silently refresh → ShellScreen
/// - No tokens / refresh failed → AuthScreen (must log in)
class SplashRouterScreen extends ConsumerStatefulWidget {
  const SplashRouterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashRouterScreen> createState() =>
      _SplashRouterScreenState();
}

class _SplashRouterScreenState extends ConsumerState<SplashRouterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _checkSession();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    // Small delay to show the splash branding nicely
    await Future.delayed(const Duration(milliseconds: 900));

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');

    bool authenticated = false;

    if (accessToken != null && accessToken.isNotEmpty) {
      // We have an access token — assume it's valid (or the 401 interceptor
      // will silently refresh it on the first real API call).
      authenticated = true;
    } else if (refreshToken != null && refreshToken.isNotEmpty) {
      // No access token but we have a refresh token — try to renew silently.
      final api = ref.read(apiServiceProvider);
      authenticated = await api.silentRefresh();
    }

    if (!mounted) return;

    if (authenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 110,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                'Sparkles',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Laundry Management',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 56),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
