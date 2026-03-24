import 'package:flutter/material.dart';
import '../models/ecg_record.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ecg_record_card.dart';
import 'ecg_detail_screen.dart';
import 'history_screen.dart';
import 'new_recording_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ECGRecord> _recentRecords = [];
  Map<String, int> _stats = {'total': 0, 'normal': 0, 'warning': 0, 'critical': 0};
  int _currentIndex = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await DatabaseService.instance.getAllRecords();
    final stats = await DatabaseService.instance.getStats();
    setState(() {
      _recentRecords = records.take(5).toList();
      _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          HistoryScreen(key: _historyKey, onRecordDeleted: _loadData),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          if (i == 1) _historyKey.currentState?.loadRecords();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewRecordingScreen()),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('New ECG'),
      ),
    );
  }

  Widget _buildDashboard() {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('CardioScan'),
          floating: true,
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Recordings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    if (_recentRecords.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _currentIndex = 1),
                        child: const Text('View All'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_recentRecords.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_heart_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No recordings yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Tap "New ECG" to capture your first recording', style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final record = _recentRecords[index];
                return ECGRecordCard(
                  record: record,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ECGDetailScreen(record: record)),
                    );
                    _loadData();
                  },
                );
              },
              childCount: _recentRecords.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Total', _stats['total']!, AppColors.primary),
        const SizedBox(width: 10),
        _buildStatCard('Normal', _stats['normal']!, AppColors.normalGreen),
        const SizedBox(width: 10),
        _buildStatCard('Abnormal', (_stats['warning']! + _stats['critical']!), AppColors.criticalRed),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color.withAlpha(180))),
          ],
        ),
      ),
    );
  }
}
