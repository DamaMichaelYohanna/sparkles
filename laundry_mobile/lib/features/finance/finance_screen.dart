import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import 'finance_report_generator.dart';
import 'providers/finance_provider.dart';

/// Reads subscription_tier from SharedPreferences (cached at login/profile fetch).
/// Falls back to checking the live userProfileProvider so it always has a value.
final _tierProvider = FutureProvider<String>((ref) async {
  // Try cached value first (instant, no network)
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString('subscription_tier');
  if (cached != null && cached.isNotEmpty) return cached.toLowerCase();

  // Fallback: read from live profile
  final profileAsync = ref.read(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (p) => (p['subscription_tier'] as String? ?? 'free').toLowerCase(),
    orElse: () => 'free',
  );
});

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({Key? key}) : super(key: key);

  // ── Tier gate helpers ───────────────────────────────────────────────────

  bool _canExport(String tier) =>
      tier == 'pro' || tier == 'premium';

  void _showUpgradeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.fileBarChart,
                color: AppTheme.primaryColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Financial Report Export',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Export a full branded PDF report with revenue breakdown, trends, and top customers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4A00E0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text('🔒 Pro & Premium Feature',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Upgrade your plan to unlock PDF exports, advanced analytics, and more.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Upgrade Plan',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerExport(
      BuildContext context, WidgetRef ref, FinanceStats stats) async {
    // Show a loading indicator in the snack bar while generating
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Generating report…'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );
    try {
      await FinanceReportGenerator.generateAndShare(stats, stats.officeName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(financeStatsProvider);
    // Read tier from cache (instant) — no loading flicker
    final tierAsync = ref.watch(_tierProvider);
    final tier = tierAsync.maybeWhen(
      data: (t) => t,
      orElse: () {
        // While loading, also try live profile as synchronous fallback
        final profileAsync = ref.watch(userProfileProvider);
        return profileAsync.maybeWhen(
          data: (p) => (p['subscription_tier'] as String? ?? 'free').toLowerCase(),
          orElse: () => 'free',
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Analysis'),
        actions: [
          // Always show the button once stats are loaded; lock badge gates non-Pro
          asyncStats.maybeWhen(
            data: (stats) => IconButton(
              tooltip: _canExport(tier)
                  ? 'Export PDF Report'
                  : 'Pro & Premium only',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(LucideIcons.download),
                  if (!_canExport(tier))
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock,
                            size: 9, color: Colors.white),
                      ),
                    ),
                ],
              ),
              onPressed: () => _canExport(tier)
                  ? _triggerExport(context, ref, stats)
                  : _showUpgradeSheet(context),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: asyncStats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error loading finance data: $error')),
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            await ref.refresh(financeStatsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderKpis(stats),
                const SizedBox(height: 24),
                _buildRevenueTrendsChart(stats),
                const SizedBox(height: 24),
                _buildRevenueByStatus(stats),
                const SizedBox(height: 24),
                _buildTopCustomers(stats),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderKpis(FinanceStats stats) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF4A00E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Revenue',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '₦${stats.totalRevenue.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Orders', stats.totalOrders.toString(), LucideIcons.shoppingBag),
                  _buildMiniStat('AOV', '₦${stats.averageOrderValue.toStringAsFixed(0)}', LucideIcons.trendingUp),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueTrendsChart(FinanceStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('7-Day Revenue Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(color: AppTheme.textSecondary, fontSize: 12);
                      final now = DateTime.now();
                      final date = now.subtract(Duration(days: 6 - value.toInt()));
                      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final text = days[date.weekday - 1];
                      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: style));
                    },
                    interval: 1,
                  ),
                ),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: stats.weeklyTrend.isEmpty ? 1000 : (stats.weeklyTrend.reduce((a, b) => a > b ? a : b) * 1.5).clamp(100, double.infinity),
              lineBarsData: [
                LineChartBarData(
                  spots: stats.weeklyTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                  isCurved: true,
                  color: AppTheme.primaryColor,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueByStatus(FinanceStats stats) {
    final completed = stats.revenueByStatus['Completed'] ?? 0.0;
    final pending = stats.revenueByStatus['Pending'] ?? 0.0;
    final overdue = stats.revenueByStatus['Overdue'] ?? 0.0;
    final total = completed + pending + overdue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Revenue by Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        color: AppTheme.primaryColor,
                        value: completed,
                        title: '',
                        radius: 20,
                      ),
                      PieChartSectionData(
                        color: Colors.orange,
                        value: pending,
                        title: '',
                        radius: 20,
                      ),
                      PieChartSectionData(
                        color: Colors.redAccent,
                        value: overdue,
                        title: '',
                        radius: 20,
                      ),
                      if (total == 0)
                         PieChartSectionData(
                          color: Colors.grey.shade200,
                          value: 1,
                          title: '',
                          radius: 20,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Completed', completed, AppTheme.primaryColor),
                    const SizedBox(height: 12),
                    _buildLegendItem('Pending', pending, Colors.orange),
                    const SizedBox(height: 12),
                    _buildLegendItem('Overdue', overdue, Colors.redAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
        Text(
          '₦${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTopCustomers(FinanceStats stats) {
    if (stats.topCustomers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.topCustomers.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final entry = stats.topCustomers.entries.elementAt(index);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    '#\${index + 1}',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                  '₦\${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
