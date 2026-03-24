import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ecg_record.dart';
import '../services/database_service.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ecg_waveform_painter.dart';
import '../widgets/severity_badge.dart';
import '../widgets/symptom_chips.dart';

class ECGDetailScreen extends StatefulWidget {
  final ECGRecord record;

  const ECGDetailScreen({super.key, required this.record});

  @override
  State<ECGDetailScreen> createState() => _ECGDetailScreenState();
}

class _ECGDetailScreenState extends State<ECGDetailScreen> {
  late ECGRecord _record;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _notesController.text = _record.doctorNotes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _deleteRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('This will permanently delete this ECG recording. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.criticalRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && _record.id != null) {
      await DatabaseService.instance.deleteRecord(_record.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _shareReport() async {
    final profile = await DatabaseService.instance.getProfile();
    final report = ReportService.generateTextReport(_record, profile);
    await ReportService.shareReport(report);
  }

  void _editNotes() {
    _notesController.text = _record.doctorNotes ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Doctor's Notes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Add clinical notes...'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final notes = _notesController.text.trim();
                if (_record.id != null) {
                  await DatabaseService.instance.updateDoctorNotes(_record.id!, notes);
                  setState(() => _record = _record.copyWith(doctorNotes: notes));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Notes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy \u2013 h:mm a').format(_record.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareReport,
            tooltip: 'Share with Doctor',
          ),
          if (_record.id != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteRecord,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_record.patientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(
                            '${_record.patientAge} yrs \u00b7 ${_record.patientGender}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(dateStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Symptoms
            if (_record.symptoms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Symptoms Reported', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 10),
                      SymptomChips(symptoms: _record.symptoms),
                      if (_record.symptomNote != null && _record.symptomNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '"${_record.symptomNote}"',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // ECG Waveform
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ECG Waveform', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 8),
                    ECGWaveformWidget(data: _record.ecgData, height: 200),
                    const SizedBox(height: 4),
                    Text(
                      '10s \u00b7 250 Hz \u00b7 25mm/s',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Interpretation
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Interpretation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const Spacer(),
                        SeverityBadge(severity: _record.severity, large: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _record.interpretation,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: AppColors.criticalRed, size: 18),
                        const SizedBox(width: 4),
                        Text('${_record.heartRate} BPM', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Findings', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._record.findings.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('\u2022 ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(f)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // Doctor's Notes
            const SizedBox(height: 8),
            Card(
              child: InkWell(
                onTap: _editNotes,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Doctor's Notes", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              _record.doctorNotes?.isNotEmpty == true
                                  ? _record.doctorNotes!
                                  : 'Tap to add notes...',
                              style: TextStyle(
                                color: _record.doctorNotes?.isNotEmpty == true
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),

            // Share button
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _shareReport,
              icon: const Icon(Icons.share),
              label: const Text('Share with Doctor'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
