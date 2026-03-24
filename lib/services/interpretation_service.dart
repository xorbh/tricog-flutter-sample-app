import '../models/ecg_record.dart';

class InterpretationResult {
  final String diagnosis;
  final Severity severity;
  final int heartRate;
  final String details;
  final List<String> findings;

  InterpretationResult({
    required this.diagnosis,
    required this.severity,
    required this.heartRate,
    required this.details,
    required this.findings,
  });
}

class InterpretationService {
  static Future<InterpretationResult> analyze(List<double> ecgData, String ecgType) async {
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 1500));

    switch (ecgType) {
      case 'normal':
        final hr = _estimateHeartRate(ecgData);
        return InterpretationResult(
          diagnosis: 'Normal Sinus Rhythm',
          severity: Severity.normal,
          heartRate: hr,
          details: 'The ECG shows a normal sinus rhythm with regular rate and rhythm.',
          findings: [
            'Regular R-R intervals',
            'Normal P wave morphology',
            'Normal PR interval (120-200ms)',
            'Narrow QRS complex (<120ms)',
            'Normal ST segment',
            'Normal T wave morphology',
          ],
        );

      case 'tachycardia':
        final hr = _estimateHeartRate(ecgData);
        return InterpretationResult(
          diagnosis: 'Sinus Tachycardia',
          severity: Severity.warning,
          heartRate: hr,
          details: 'Heart rate is elevated above 100 BPM. Sinus P waves present before each QRS.',
          findings: [
            'Elevated heart rate (>100 BPM)',
            'Regular R-R intervals',
            'Normal P wave before each QRS',
            'Narrow QRS complex',
            'Consider causes: fever, anxiety, dehydration, anemia',
          ],
        );

      case 'bradycardia':
        final hr = _estimateHeartRate(ecgData);
        return InterpretationResult(
          diagnosis: 'Sinus Bradycardia',
          severity: Severity.warning,
          heartRate: hr,
          details: 'Heart rate is below 60 BPM. Rhythm is regular with normal P waves.',
          findings: [
            'Low heart rate (<60 BPM)',
            'Regular R-R intervals',
            'Normal P wave morphology',
            'Normal PR interval',
            'May be normal in athletes or during sleep',
          ],
        );

      case 'afib':
        return InterpretationResult(
          diagnosis: 'Atrial Fibrillation',
          severity: Severity.critical,
          heartRate: _estimateHeartRate(ecgData),
          details: 'Irregularly irregular rhythm with absence of organized P waves. Fibrillatory baseline present.',
          findings: [
            'Irregularly irregular R-R intervals',
            'Absence of distinct P waves',
            'Fibrillatory baseline',
            'Variable ventricular rate',
            'URGENT: Assess stroke risk (CHA2DS2-VASc)',
            'Consider anticoagulation therapy',
          ],
        );

      case 'st_elevation':
        return InterpretationResult(
          diagnosis: 'ST Segment Elevation',
          severity: Severity.critical,
          heartRate: _estimateHeartRate(ecgData),
          details: 'Significant ST elevation detected. This may indicate acute myocardial infarction (STEMI).',
          findings: [
            'ST segment elevation >1mm',
            'Possible acute myocardial injury',
            'URGENT: Rule out STEMI',
            'Immediate cardiology consultation recommended',
            'Consider emergent catheterization',
          ],
        );

      case 'pvc':
        return InterpretationResult(
          diagnosis: 'Premature Ventricular Contractions',
          severity: Severity.warning,
          heartRate: _estimateHeartRate(ecgData),
          details: 'Premature wide QRS complexes observed without preceding P waves. Trigeminy pattern noted.',
          findings: [
            'Premature wide QRS complexes',
            'No preceding P wave for PVC beats',
            'Compensatory pause after PVCs',
            'Underlying rhythm appears sinus',
            'Monitor for frequency and symptoms',
          ],
        );

      default:
        return InterpretationResult(
          diagnosis: 'Unclassified',
          severity: Severity.warning,
          heartRate: 72,
          details: 'Unable to classify this ECG pattern.',
          findings: ['Further review recommended'],
        );
    }
  }

  static int _estimateHeartRate(List<double> ecgData) {
    // Find R peaks (highest points) and estimate rate
    const sampleRate = 250;
    final threshold = ecgData.reduce((a, b) => a > b ? a : b) * 0.6;
    final rPeaks = <int>[];
    for (int i = 1; i < ecgData.length - 1; i++) {
      if (ecgData[i] > threshold &&
          ecgData[i] > ecgData[i - 1] &&
          ecgData[i] > ecgData[i + 1]) {
        if (rPeaks.isEmpty || i - rPeaks.last > sampleRate * 0.3) {
          rPeaks.add(i);
        }
      }
    }
    if (rPeaks.length < 2) return 72;
    final avgInterval = (rPeaks.last - rPeaks.first) / (rPeaks.length - 1);
    return (60.0 * sampleRate / avgInterval).round();
  }
}
