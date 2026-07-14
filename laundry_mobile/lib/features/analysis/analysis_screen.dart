import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/widgets/sync_badge.dart';
import 'providers/analysis_provider.dart';
import '../finance/providers/finance_provider.dart';
import '../finance/finance_report_generator.dart';

/// Reads subscription_tier from SharedPreferences (cached at login/profile fetch).
final _tierProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString('subscription_tier');
  if (cached != null && cached.isNotEmpty) return cached.toLowerCase();

  final profileAsync = ref.read(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (p) => (p['subscription_tier'] as String? ?? 'free').toLowerCase(),
    orElse: () => 'free',
  );
});

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

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
              'Export a full branded PDF report with revenue\nbreakdown, trends, and top customers.',
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
                  Text('Upgrade your plan to unlock PDF exports,\nadvanced analytics, and more.',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsyncValue = ref.watch(analysisStatsProvider);
    final financeStatsAsync = ref.watch(financeStatsProvider);
    final tierAsync = ref.watch(_tierProvider);
    final tier = tierAsync.maybeWhen(
      data: (t) => t,
      orElse: () {
        final profileAsync = ref.watch(userProfileProvider);
        return profileAsync.maybeWhen(
          data: (p) => (p['subscription_tier'] as String? ?? 'free').toLowerCase(),
          orElse: () => 'free',
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Analysis'),
        actions: [
          const SyncBadge(),
          financeStatsAsync.maybeWhen(
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
      body: RefreshIndicator(
        onRefresh: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('last_sync_timestamp');
          final syncRepo = ref.read(syncRepositoryProvider);
          await syncRepo.getOrders();
          ref.invalidate(rawAnalysisOrdersProvider);
          ref.invalidate(analysisStatsProvider);
        },
        child: statsAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error loading analytics: $error')),
          data: (stats) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 2. FINANCIAL SUMMARY SECTION
                const Text(
                  'Financial Performance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.4,
                  children: [
                    _buildMetricCard(
                      title: 'Total Sales',
                      value: '₦${stats.totalSales.toStringAsFixed(2)}',
                      icon: LucideIcons.trendingUp,
                      color: AppTheme.primaryColor,
                      gradientColors: [AppTheme.primaryColor, AppTheme.primaryDark],
                    ),
                    _buildMetricCard(
                      title: 'Collected',
                      value: '₦${stats.totalCollected.toStringAsFixed(2)}',
                      icon: LucideIcons.checkCircle2,
                      color: Colors.green,
                      gradientColors: [Colors.green.shade600, Colors.green.shade800],
                    ),
                    _buildMetricCard(
                      title: 'Outstanding',
                      value: '₦${stats.outstanding.toStringAsFixed(2)}',
                      icon: LucideIcons.alertTriangle,
                      color: Colors.redAccent,
                      gradientColors: [Colors.redAccent.shade200, Colors.redAccent.shade700],
                    ),
                    _buildMetricCard(
                      title: 'Collection Rate',
                      value: '${stats.collectionRate.toStringAsFixed(1)}%',
                      icon: LucideIcons.percent,
                      color: Colors.orange,
                      gradientColors: [Colors.orange.shade500, Colors.orange.shade700],
                      subtitle: '${stats.totalOrdersCount} Total Orders',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekly Trend Bar Chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weekly Revenue Trend',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (stats.weeklyTrend.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000, 1000000),
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      const style = TextStyle(color: AppTheme.textSecondary, fontSize: 11);
                                      String text;
                                      switch (value.toInt()) {
                                        case 0: text = 'Mon'; break;
                                        case 1: text = 'Tue'; break;
                                        case 2: text = 'Wed'; break;
                                        case 3: text = 'Thu'; break;
                                        case 4: text = 'Fri'; break;
                                        case 5: text = 'Sat'; break;
                                        case 6: text = 'Sun'; break;
                                        default: text = ''; break;
                                      }
                                      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: style));
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.background, strokeWidth: 1),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: stats.weeklyTrend.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value,
                                      color: AppTheme.primaryColor,
                                      width: 14,
                                      borderRadius: BorderRadius.circular(4),
                                    )
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. OPERATIONAL SUMMARY SECTION (Segmented Progress Bar)
                const Text(
                  'Operations & Workflow',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                _buildOperationsCard(stats),
                const SizedBox(height: 24),

                // Periodic Order Summaries
                const Text(
                  'Order Volumes & Performance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                _buildPeriodicOrdersCard(stats),
                const SizedBox(height: 24),

                // 4. GROWTH & PROJECTIONS SECTION
                const Text(
                  'Growth & Projections',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                _buildGrowthProjectionsCard(stats),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildOperationsCard(AnalysisStats stats) {
    final total = stats.completedOrdersCount + stats.pendingOrdersCount + stats.overdueOrdersCount;
    final compPercent = total > 0 ? (stats.completedOrdersCount / total) * 100 : 0.0;
    final pendPercent = total > 0 ? (stats.pendingOrdersCount / total) * 100 : 0.0;
    final overPercent = total > 0 ? (stats.overdueOrdersCount / total) * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Order Distribution',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  '$total Active Orders',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Segmented Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: total == 0
                    ? Container(color: Colors.grey.shade200)
                    : Row(
                        children: [
                          if (stats.completedOrdersCount > 0)
                            Expanded(
                              flex: stats.completedOrdersCount,
                              child: Container(color: Colors.green),
                            ),
                          if (stats.pendingOrdersCount > 0)
                            Expanded(
                              flex: stats.pendingOrdersCount,
                              child: Container(color: Colors.orange),
                            ),
                          if (stats.overdueOrdersCount > 0)
                            Expanded(
                              flex: stats.overdueOrdersCount,
                              child: Container(color: Colors.red),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Legends row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegendItem('Completed', stats.completedOrdersCount, compPercent, Colors.green),
                _buildLegendItem('Pending', stats.pendingOrdersCount, pendPercent, Colors.orange),
                _buildLegendItem('Overdue', stats.overdueOrdersCount, overPercent, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, int count, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count (${percentage.toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildGrowthProjectionsCard(AnalysisStats stats) {
    final isPositive = stats.wowGrowth >= 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Week-over-Week Revenue',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isPositive ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                            color: isPositive ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${isPositive ? '+' : ''}${stats.wowGrowth.toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'vs. previous 7 days',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey.shade200),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Projected Monthly Sales',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "₦${stats.projectedMonthlyRevenue.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Estimated based on daily average',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white, size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodicOrdersCard(AnalysisStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(LucideIcons.calendarRange, color: AppTheme.primaryColor, size: 16),
                SizedBox(width: 8),
                Text(
                  'Volume Summaries',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPeriodicItem('This Week', stats.weeklyOrdersCount, stats.weeklyOrdersValue),
                _buildPeriodicItem('This Month', stats.monthlyOrdersCount, stats.monthlyOrdersValue),
                _buildPeriodicItem('This Year', stats.yearlyOrdersCount, stats.yearlyOrdersValue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodicItem(String label, int count, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            '$count ${count == 1 ? 'Order' : 'Orders'}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₦${value.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
