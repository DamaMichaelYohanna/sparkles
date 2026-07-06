import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/dashboard_provider.dart';
import '../../core/models/dashboard_stats_model.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/mock_data.dart';
import 'widgets/kpi_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Overview'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: const Text('A', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Welcome back, Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Here is what is happening today.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                      maxY: 1500,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              const style = TextStyle(color: AppTheme.textSecondary, fontSize: 12);
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
                        horizontalInterval: 500,
                        getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.background, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: MockData.weeklyRevenue.asMap().entries.map((entry) {
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
