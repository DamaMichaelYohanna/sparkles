import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import 'providers/finance_provider.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsyncValue = ref.watch(financeStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final syncRepo = ref.read(syncRepositoryProvider);
          await syncRepo.getOrders();
          ref.invalidate(rawFinanceOrdersProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Metric Cards Grid
              statsAsyncValue.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Center(child: Text('Error loading stats: $error')),
                data: (stats) => Column(
                  children: [
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
                    const SizedBox(height: 24),
                    
                    // Weekly Sales Trend Chart Card
                    const Text(
                      'Weekly Revenue Trend',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: SizedBox(
                          height: 180,
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
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
}
