import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/dashboard_provider.dart';
import '../../core/models/dashboard_stats_model.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../settings/profile_screen.dart';
import 'widgets/kpi_card.dart';
import '../../core/widgets/sync_badge.dart';
import '../../core/widgets/shimmer_box.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Overview'),
        actions: [
          const SyncBadge(),
          IconButton(
            icon: const Icon(LucideIcons.user),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        loading: () => const _DashboardSkeleton(),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (stats) => _DashboardContent(stats: stats),
      ),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              const ShimmerBox(width: 44, height: 44, borderRadius: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 180, height: 16),
                  SizedBox(height: 6),
                  ShimmerBox(width: 130, height: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI cards skeleton — 2×2 grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(4, (_) => const _KpiCardSkeleton()),
          ),
          const SizedBox(height: 24),

          // Chart title skeleton
          const ShimmerBox(width: 140, height: 18),
          const SizedBox(height: 16),

          // Chart card skeleton
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Fake bar chart bars
                  SizedBox(
                    height: 200,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [0.6, 0.9, 0.45, 0.75, 1.0, 0.55, 0.7]
                          .map((h) => ShimmerBox(
                                width: 32,
                                height: 200 * h,
                                borderRadius: 6,
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Day labels skeleton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      7,
                      (_) => const ShimmerBox(width: 24, height: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCardSkeleton extends StatelessWidget {
  const _KpiCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const ShimmerBox(width: 42, height: 42, borderRadius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  ShimmerBox(height: 20),
                  SizedBox(height: 6),
                  ShimmerBox(width: 70, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Real content (with fade-in) ─────────────────────────────────────────────

class _DashboardContent extends StatefulWidget {
  final DashboardStats stats;
  const _DashboardContent({required this.stats});

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: _DashboardBody(stats: widget.stats),
    );
  }
}

// ─── Body (extracted so it can be wrapped in FadeTransition) ─────────────────

class _DashboardBody extends ConsumerWidget {
  final DashboardStats stats;
  const _DashboardBody({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_sync_timestamp');
        final syncRepo = ref.read(syncRepositoryProvider);
        await syncRepo.getOrders();
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentOrdersProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Builder(
                  builder: (context) {
                    final logoBase64 = ref.watch(officeLogoProvider).asData?.value;
                    final hasLogo = logoBase64 != null && logoBase64.isNotEmpty;
                    return CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      backgroundImage: hasLogo ? MemoryImage(base64Decode(logoBase64!)) : null,
                      child: !hasLogo
                          ? Text(
                              ref.watch(officeNameProvider).maybeWhen(
                                data: (name) => name.isNotEmpty ? name[0].toUpperCase() : 'L',
                                orElse: () => 'L',
                              ),
                              style: const TextStyle(
                                  color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ref.watch(officeNameProvider).when(
                      data: (name) => Text('Welcome back, $name',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      loading: () => const Text('Welcome back...',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      error: (_, __) => const Text('Welcome back, Admin',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const Text('Here is what is happening today.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // KPI Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                KpiCard(
                  title: 'Total Revenue',
                  value: '₦${stats.totalRevenue}',
                  icon: LucideIcons.dollarSign,
                  color: Colors.green,
                ),
                KpiCard(
                  title: 'Pending',
                  value: '${stats.pendingOrders}',
                  icon: LucideIcons.clock,
                  color: Colors.orange,
                ),
                KpiCard(
                  title: 'Completed',
                  value: '${stats.completedOrders}',
                  icon: LucideIcons.checkCircle,
                  color: AppTheme.primaryColor,
                ),
                KpiCard(
                  title: 'Overdue',
                  value: '${stats.overdueOrders}',
                  icon: LucideIcons.alertCircle,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chart Section
            const Text(
              'Weekly Revenue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (stats.weeklyTrend
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2)
                          .clamp(1000, 10000000),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget:
                                (double value, TitleMeta meta) {
                              const style = TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12);
                              String text;
                              switch (value.toInt()) {
                                case 0:
                                  text = 'Mon';
                                  break;
                                case 1:
                                  text = 'Tue';
                                  break;
                                case 2:
                                  text = 'Wed';
                                  break;
                                case 3:
                                  text = 'Thu';
                                  break;
                                case 4:
                                  text = 'Fri';
                                  break;
                                case 5:
                                  text = 'Sat';
                                  break;
                                case 6:
                                  text = 'Sun';
                                  break;
                                default:
                                  text = '';
                                  break;
                              }
                              return Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8),
                                  child: Text(text, style: style));
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 500,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(
                                color: AppTheme.background,
                                strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups:
                          stats.weeklyTrend.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              color: AppTheme.primaryColor,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                            )
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
