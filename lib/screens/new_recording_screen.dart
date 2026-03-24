import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ecg_record.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/ecg_simulator.dart';
import '../services/interpretation_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ecg_waveform_painter.dart';
import '../widgets/severity_badge.dart';
import '../widgets/symptom_chips.dart';
import 'ecg_detail_screen.dart';

class NewRecordingScreen extends StatefulWidget {
  const NewRecordingScreen({super.key});

  @override
  State<NewRecordingScreen> createState() => _NewRecordingScreenState();
}

class _NewRecordingScreenState extends State<NewRecordingScreen>
    with TickerProviderStateMixin {
  // Steps: 0=symptoms, 1=capture, 2=interpreting, 3=result
  int _step = 0;

  // Symptom state
  final Set<String> _selectedSymptoms = {};
  final _symptomNoteController = TextEditingController();
  static const List<String> _symptomOptions = [
    'Chest Pain',
    'Palpitations',
    'Dizziness',
    'Shortness of Breath',
    'Fatigue',
    'Routine Check',
  ];

  // Capture state
  List<double> _ecgData = [];
  String _ecgType = '';
  InterpretationResult? _interpretation;
  late AnimationController _captureAnimController;
  Timer? _captureTimer;
  int _captureSeconds = 10;

  // Profile
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _captureAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _profile = await DatabaseService.instance.getProfile();
  }

  @override
  void dispose() {
    _symptomNoteController.dispose();
    _captureAnimController.dispose();
    _captureTimer?.cancel();
    super.dispose();
  }

  void _startCapture() {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select how you are feeling')),
      );
      return;
    }

    final result = ECGSimulator.generateRandom();
    _ecgData = result.data;
    _ecgType = result.type;

    setState(() => _step = 1);
    _captureSeconds = 10;

    _captureAnimController.forward();
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _captureSeconds--);
      if (_captureSeconds <= 0) {
        timer.cancel();
        _onCaptureComplete();
      }
    });
  }

  Future<void> _onCaptureComplete() async {
    setState(() => _step = 2);
    final result = await InterpretationService.analyze(_ecgData, _ecgType);
    setState(() {
      _interpretation = result;
      _step = 3;
    });
  }

  Future<void> _saveRecord() async {
    final profile = _profile;
    final record = ECGRecord(
      patientName: profile?.name ?? 'Unknown',
      patientAge: profile?.age ?? 0,
      patientGender: profile?.gender ?? 'Unknown',
      timestamp: DateTime.now(),
      ecgData: _ecgData,
      interpretation: _interpretation!.diagnosis,
      severity: _interpretation!.severity,
      heartRate: _interpretation!.heartRate,
      findings: _interpretation!.findings,
      symptoms: _selectedSymptoms.toList(),
      symptomNote: _symptomNoteController.text.trim().isEmpty
          ? null
          : _symptomNoteController.text.trim(),
    );

    final id = await DatabaseService.instance.insertRecord(record);
    final saved = record.copyWith(id: id);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ECGDetailScreen(record: saved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_step) {
          0 => 'How Are You Feeling?',
          1 => 'Capturing ECG...',
          2 => 'Analyzing...',
          _ => 'Results',
        }),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_step) {
          0 => _buildSymptoms(),
          1 => _buildCapture(),
          2 => _buildAnalyzing(),
          _ => _buildResults(),
        },
      ),
    );
  }

  Widget _buildSymptoms() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.self_improvement, size: 56, color: AppColors.primary.withAlpha(120)),
          const SizedBox(height: 16),
          const Text(
            'Before we start, how are you feeling right now?',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _symptomOptions.map((symptom) {
              final selected = _selectedSymptoms.contains(symptom);
              final isRoutine = symptom == 'Routine Check';
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SymptomChips.symptomIcons[symptom] ?? Icons.circle,
                      size: 16,
                      color: selected
                          ? Colors.white
                          : isRoutine
                              ? AppColors.normalGreen
                              : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(symptom),
                  ],
                ),
                selected: selected,
                selectedColor: isRoutine ? AppColors.normalGreen : AppColors.warningAmber,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                ),
                onSelected: (v) {
                  setState(() {
                    if (isRoutine) {
                      _selectedSymptoms.clear();
                      if (v) _selectedSymptoms.add(symptom);
                    } else {
                      _selectedSymptoms.remove('Routine Check');
                      if (v) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _symptomNoteController,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              hintText: 'e.g., "Just finished exercising"',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startCapture,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start ECG Capture'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapture() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          '$_captureSeconds',
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const Text('seconds remaining', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: LinearProgressIndicator(
            value: (10 - _captureSeconds) / 10,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedBuilder(
                animation: _captureAnimController,
                builder: (context, _) {
                  final visible = (_captureAnimController.value * _ecgData.length).round();
                  return CustomPaint(
                    size: Size(MediaQuery.of(context).size.width - 32, 200),
                    painter: ECGWaveformPainter(
                      data: _ecgData,
                      pixelsPerSample: (MediaQuery.of(context).size.width - 32) / _ecgData.length,
                      visibleSamples: visible,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sensors, color: AppColors.criticalRed.withAlpha(180)),
              const SizedBox(width: 8),
              Text(
                'Recording in progress...',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing ECG...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'AI algorithm is processing the recording',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final interp = _interpretation!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Diagnosis card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                SeverityBadge(severity: interp.severity, large: true),
                const SizedBox(height: 12),
                Text(
                  interp.diagnosis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, color: AppColors.criticalRed, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${interp.heartRate} BPM',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ECG preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width - 64, 150),
                  painter: ECGWaveformPainter(
                    data: _ecgData,
                    pixelsPerSample: (MediaQuery.of(context).size.width - 64) / _ecgData.length,
                    verticalScale: 60,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // What this means
          _buildGuidanceCard(interp.severity),
          const SizedBox(height: 16),

          Text(interp.details, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 16),

          const Text('Findings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ...interp.findings.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('\u2022 ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              )),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _saveRecord,
            icon: const Icon(Icons.save),
            label: const Text('Save Recording'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(Severity severity) {
    final (color, icon, title, message) = switch (severity) {
      Severity.normal => (
          AppColors.normalGreen,
          Icons.check_circle,
          'All looks good',
          'Your heart rhythm appears normal. Keep up the good work with regular monitoring.',
        ),
      Severity.warning => (
          AppColors.warningAmber,
          Icons.warning_amber_rounded,
          'Worth monitoring',
          'Some findings may need attention. Consider sharing this report with your doctor at your next visit.',
        ),
      Severity.critical => (
          AppColors.criticalRed,
          Icons.emergency,
          'Contact your doctor',
          'This result may require prompt medical attention. Please share this report with your doctor or seek medical care.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(fontSize: 13, color: color.withAlpha(200))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
