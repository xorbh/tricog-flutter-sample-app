import 'package:flutter/material.dart';
import '../models/ecg_record.dart';
import '../services/database_service.dart';
import '../widgets/ecg_record_card.dart';
import 'ecg_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onRecordDeleted;

  const HistoryScreen({super.key, this.onRecordDeleted});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<ECGRecord> _records = [];
  List<ECGRecord> _filtered = [];
  Severity? _filterSeverity;
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadRecords() async {
    final records = await DatabaseService.instance.getAllRecords();
    setState(() {
      _records = records;
      _applyFilter();
    });
  }

  void _applyFilter() {
    var list = _records;
    if (_filterSeverity != null) {
      list = list.where((r) => r.severity == _filterSeverity).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((r) => r.patientName.toLowerCase().contains(query)).toList();
    }
    _filtered = list;
  }

  Future<void> _deleteRecord(ECGRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Delete ECG for ${record.patientName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && record.id != null) {
      await DatabaseService.instance.deleteRecord(record.id!);
      widget.onRecordDeleted?.call();
      loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by patient name...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(_applyFilter),
              )
            : const Text('History'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _applyFilter();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildChip('All', null),
                const SizedBox(width: 8),
                _buildChip('Normal', Severity.normal),
                const SizedBox(width: 8),
                _buildChip('Warning', Severity.warning),
                const SizedBox(width: 8),
                _buildChip('Critical', Severity.critical),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No recordings found', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: loadRecords,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final record = _filtered[index];
                        return Dismissible(
                          key: ValueKey(record.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Colors.red.shade50,
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          confirmDismiss: (_) async {
                            await _deleteRecord(record);
                            return false; // we handle deletion ourselves
                          },
                          child: ECGRecordCard(
                            record: record,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ECGDetailScreen(record: record)),
                              );
                              loadRecords();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Severity? severity) {
    final selected = _filterSeverity == severity;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filterSeverity = severity;
          _applyFilter();
        });
      },
    );
  }
}
