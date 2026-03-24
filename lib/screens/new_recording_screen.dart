import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ecg_record.dart';
import '../services/database_service.dart';
import '../services/ecg_simulator.dart';
import '../services/interpretation_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ecg_waveform_painter.dart';
import '../widgets/severity_badge.dart';
import 'ecg_detail_screen.dart';

class NewRecordingScreen extends StatefulWidget {
  const NewRecordingScreen({super.key});

  @override
  State<NewRecordingScreen> createState() => _NewRecordingScreenState();
}

class _NewRecordingScreenState extends State<NewRecordingScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Male';

  int _step = 0; // 0=form, 1=capture, 2=interpreting, 3=result
  List<double> _ecgData = [];
  String _ecgType = '';
  InterpretationResult? _interpretation;
  late AnimationController _captureAnimController;
  Timer? _captureTimer;
  int _captureSeconds = 10;

  @override
  void initState() {
    super.initState();
    _captureAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _captureAnimController.dispose();
    _captureTimer?.cancel();
    super.dispose();
  }

  void _startCapture() {
    if (!_formKey.currentState!.validate()) return;

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
    final record = ECGRecord(
      patientName: _nameController.text.trim(),
      patientAge: int.parse(_ageController.text.trim()),
      patientGender: _gender,
      timestamp: DateTime.now(),
      ecgData: _ecgData,
      interpretation: _interpretation!.diagnosis,
      severity: _interpretation!.severity,
      heartRate: _interpretation!.heartRate,
      findings: _interpretation!.findings,
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
        title: Text(_step == 0
            ? 'Patient Information'
            : _step == 1
                ? 'Capturing ECG...'
                : _step == 2
                    ? 'Analyzing...'
                    : 'Results'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_step) {
          0 => _buildForm(),
          1 => _buildCapture(),
          2 => _buildAnalyzing(),
          _ => _buildResults(),
        },
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.person_outline, size: 64, color: AppColors.primary.withAlpha(100)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                prefixIcon: Icon(Icons.cake),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final age = int.tryParse(v.trim());
                if (age == null || age < 1 || age > 150) return 'Enter valid age';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Male', label: Text('Male'), icon: Icon(Icons.male)),
                ButtonSegment(value: 'Female', label: Text('Female'), icon: Icon(Icons.female)),
                ButtonSegment(value: 'Other', label: Text('Other')),
              ],
              selected: {_gender},
              onSelectionChanged: (v) => setState(() => _gender = v.first),
            ),
            const SizedBox(height: 40),
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

          // Details
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
}
