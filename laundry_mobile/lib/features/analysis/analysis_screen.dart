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

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AnalysisFilterBottomSheet(),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year.toString().substring(2)}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsyncValue = ref.watch(analysisStatsProvider);
    final financeStatsAsync = ref.watch(financeStatsProvider);
    final filter = ref.watch(analysisFilterProvider);
    final filterNotifier = ref.read(analysisFilterProvider.notifier);
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

    final hasActiveFilters = filter.status != 'All' ||
        filter.paymentStatus != 'All' ||
        filter.dateRange != 'All Time';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Analysis'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(LucideIcons.slidersHorizontal, size: 20),
                if (hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterBottomSheet(context),
          ),
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
      body: Column(
        children: [
          // Active Filter Chips (Only shown if filters are active)
          if (hasActiveFilters)
            Container(
              height: 48,
              color: AppTheme.background.withOpacity(0.5),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.filter, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      if (filter.dateRange != 'All Time')
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InputChip(
                            label: Text(
                              filter.dateRange == 'Custom' && filter.customDateRange != null
                                  ? "${_formatDate(filter.customDateRange!.start)} - ${_formatDate(filter.customDateRange!.end)}"
                                  : filter.dateRange,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onDeleted: () => filterNotifier.setDateRange('All Time'),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: AppTheme.primaryColor,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      if (filter.status != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InputChip(
                            label: Text(
                              "Status: ${filter.status}",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onDeleted: () => filterNotifier.setStatus('All'),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: AppTheme.primaryColor,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      if (filter.paymentStatus != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InputChip(
                            label: Text(
                              "Payment: ${filter.paymentStatus}",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onDeleted: () => filterNotifier.setPaymentStatus('All'),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: AppTheme.primaryColor,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      TextButton(
                        onPressed: () => filterNotifier.reset(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                        child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (hasActiveFilters) const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
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
                      // 1. PERIOD FILTER BAR
                      _buildPeriodFilterChips(ref),
                      const SizedBox(height: 16),

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
    ),
  ],
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

  Widget _buildPeriodFilterChips(WidgetRef ref) {
    final filter = ref.watch(analysisFilterProvider);
    final filterNotifier = ref.read(analysisFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(ref, 'All Time', 'All Time', filter.dateRange, filterNotifier),
          const SizedBox(width: 8),
          _buildFilterChip(ref, 'Today', 'Today', filter.dateRange, filterNotifier),
          const SizedBox(width: 8),
          _buildFilterChip(ref, 'This Week', 'This Week', filter.dateRange, filterNotifier),
          const SizedBox(width: 8),
          _buildFilterChip(ref, 'This Month', 'This Month', filter.dateRange, filterNotifier),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String value, String currentRange, AnalysisFilterNotifier filterNotifier) {
    final isSelected = currentRange == value;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.grey.shade100,
      elevation: isSelected ? 2 : 0,
      onSelected: (selected) {
        if (selected) {
          filterNotifier.setDateRange(value);
        }
      },
    );
  }
}

class AnalysisFilterBottomSheet extends ConsumerWidget {
  const AnalysisFilterBottomSheet({Key? key}) : super(key: key);

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year.toString().substring(2)}";
  }

  Future<void> _pickCustomDateRange(BuildContext context, WidgetRef ref, DateTimeRange? currentRange) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: currentRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(analysisFilterProvider.notifier).setCustomDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(analysisFilterProvider);
    final filterNotifier = ref.read(analysisFilterProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Business Analytics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              TextButton(
                onPressed: () => filterNotifier.reset(),
                child: const Text('Reset All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),

          // 1. Date filters
          const Text('Date Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...['All Time', 'Today', 'This Week', 'This Month'].map((range) {
                final isSelected = filter.dateRange == range;
                return ChoiceChip(
                  label: Text(range, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (_) => filterNotifier.setDateRange(range),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickCustomDateRange(context, ref, filter.customDateRange),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: filter.dateRange == 'Custom' ? AppTheme.primaryColor.withOpacity(0.08) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: filter.dateRange == 'Custom' ? AppTheme.primaryColor : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: filter.dateRange == 'Custom' ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    filter.dateRange == 'Custom' && filter.customDateRange != null
                        ? "${_formatDate(filter.customDateRange!.start)} - ${_formatDate(filter.customDateRange!.end)}"
                        : 'Select Calendar Range',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: filter.dateRange == 'Custom' ? FontWeight.bold : FontWeight.normal,
                      color: filter.dateRange == 'Custom' ? AppTheme.primaryColor : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Order Progress
          const Text('Order Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...['All', 'Pending', 'Completed', 'Overdue'].map((status) {
                final isSelected = filter.status == status;
                return ChoiceChip(
                  label: Text(status, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (_) => filterNotifier.setStatus(status),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Payment Status
          const Text('Payment Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...['All', 'Fully Paid', 'Partially Paid', 'Unpaid'].map((payStatus) {
                final isSelected = filter.paymentStatus == payStatus;
                return ChoiceChip(
                  label: Text(payStatus, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (_) => filterNotifier.setPaymentStatus(payStatus),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Apply Analytics Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
