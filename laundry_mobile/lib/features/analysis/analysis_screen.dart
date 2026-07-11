import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import 'providers/analysis_provider.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsyncValue = ref.watch(analysisStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Analysis'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final syncRepo = ref.read(syncRepositoryProvider);
          await syncRepo.getOrders();
          ref.invalidate(rawAnalysisOrdersProvider);
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
                // 1. SMART ACTIONABLE INSIGHTS SECTION (AI Sparks)
                _buildInsightsCard(stats.businessInsights),
                const SizedBox(height: 20),

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

  Widget _buildInsightsCard(List<String> insights) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15), width: 1.5),
      ),
      color: AppTheme.primaryColor.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(LucideIcons.sparkles, color: AppTheme.primaryColor, size: 18),
                SizedBox(width: 8),
                Text(
                  'Business Insights',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Icon(Icons.lens, size: 6, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
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
