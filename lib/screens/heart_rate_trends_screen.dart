import 'package:flutter/material.dart';
import '../models/ecg_record.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/heart_rate_chart_painter.dart';

enum TimeRange { week, month, quarter, all }

class HeartRateTrendsScreen extends StatefulWidget {
  const HeartRateTrendsScreen({super.key});

  @override
  State<HeartRateTrendsScreen> createState() => _HeartRateTrendsScreenState();
}

class _HeartRateTrendsScreenState extends State<HeartRateTrendsScreen> {
  TimeRange _range = TimeRange.month;
  List<ECGRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final start = switch (_range) {
      TimeRange.week => now.subtract(const Duration(days: 7)),
      TimeRange.month => now.subtract(const Duration(days: 30)),
      TimeRange.quarter => now.subtract(const Duration(days: 90)),
      TimeRange.all => DateTime(2000),
    };
    final records = await DatabaseService.instance.getRecordsInRange(start, now);
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataPoints = _records
        .map((r) => HRDataPoint(
              timestamp: r.timestamp,
              heartRate: r.heartRate,
              severity: r.severity,
            ))
        .toList();

    final avgHR = dataPoints.isEmpty
        ? 0
        : (dataPoints.map((d) => d.heartRate).reduce((a, b) => a + b) / dataPoints.length).round();
    final minHR = dataPoints.isEmpty ? 0 : dataPoints.map((d) => d.heartRate).reduce((a, b) => a < b ? a : b);
    final maxHR = dataPoints.isEmpty ? 0 : dataPoints.map((d) => d.heartRate).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Heart Rate Trends')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Time range selector
                  Row(
                    children: [
                      _buildRangeChip('7 Days', TimeRange.week),
                      const SizedBox(width: 8),
                      _buildRangeChip('30 Days', TimeRange.month),
                      const SizedBox(width: 8),
                      _buildRangeChip('90 Days', TimeRange.quarter),
                      const SizedBox(width: 8),
                      _buildRangeChip('All', TimeRange.all),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      _buildStatCard('Average', '$avgHR', 'BPM', AppColors.primary),
                      const SizedBox(width: 10),
                      _buildStatCard('Lowest', '$minHR', 'BPM', AppColors.normalGreen),
                      const SizedBox(width: 10),
                      _buildStatCard('Highest', '$maxHR', 'BPM', AppColors.criticalRed),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: dataPoints.isEmpty
                          ? SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'No recordings in this period',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 250,
                              child: CustomPaint(
                                size: Size(MediaQuery.of(context).size.width - 56, 250),
                                painter: HeartRateChartPainter(
                                  data: dataPoints,
                                  rangeStart: dataPoints.first.timestamp,
                                  rangeEnd: dataPoints.last.timestamp,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegend(AppColors.normalGreen, 'Normal'),
                      const SizedBox(width: 16),
                      _buildLegend(AppColors.warningAmber, 'Warning'),
                      const SizedBox(width: 16),
                      _buildLegend(AppColors.criticalRed, 'Critical'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Green band = normal range (60-100 BPM)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    '${dataPoints.length} recording${dataPoints.length == 1 ? '' : 's'} in this period',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRangeChip(String label, TimeRange range) {
    final selected = _range == range;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() => _range = range);
          _loadData();
        },
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            Text(unit, style: TextStyle(fontSize: 11, color: color.withAlpha(150))),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(180))),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
