import 'dart:math';

class ECGSimulator {
  static const int sampleRate = 250;
  static const int durationSeconds = 10;
  static const int totalSamples = sampleRate * durationSeconds;

  static final _random = Random();

  static double _gaussian(double t, double center, double sigma, double amplitude) {
    final exponent = -pow((t - center), 2) / (2 * pow(sigma, 2));
    return amplitude * exp(exponent);
  }

  static List<double> _generatePQRST(double cycleLength, {bool afib = false, bool stElevation = false}) {
    final samples = (cycleLength * sampleRate).round();
    final data = List<double>.filled(samples, 0.0);

    for (int i = 0; i < samples; i++) {
      final t = i / sampleRate;
      double value = 0.0;

      // P wave (absent in AFib)
      if (!afib) {
        value += _gaussian(t, cycleLength * 0.12, 0.04, 0.15);
      } else {
        // fibrillatory baseline
        value += 0.05 * sin(2 * pi * (_random.nextDouble() * 8 + 4) * t);
        value += 0.03 * sin(2 * pi * (_random.nextDouble() * 12 + 6) * t);
      }

      // Q wave
      value += _gaussian(t, cycleLength * 0.22, 0.008, -0.10);

      // R wave
      value += _gaussian(t, cycleLength * 0.25, 0.012, 1.2);

      // S wave
      value += _gaussian(t, cycleLength * 0.28, 0.008, -0.20);

      // ST segment elevation
      if (stElevation) {
        value += _gaussian(t, cycleLength * 0.35, 0.06, 0.35);
      }

      // T wave
      value += _gaussian(t, cycleLength * 0.45, 0.06, 0.30);

      // noise
      value += (_random.nextDouble() - 0.5) * 0.03;

      data[i] = value;
    }

    return data;
  }

  /// Generates normal sinus rhythm ECG data
  static List<double> generateNormal({int heartRate = 72}) {
    final cycleLength = 60.0 / heartRate;
    final data = <double>[];
    while (data.length < totalSamples) {
      data.addAll(_generatePQRST(cycleLength));
    }
    return data.sublist(0, totalSamples);
  }

  /// Generates tachycardia ECG (fast rate)
  static List<double> generateTachycardia() {
    final heartRate = 110 + _random.nextInt(30); // 110-140 BPM
    return generateNormal(heartRate: heartRate);
  }

  /// Generates bradycardia ECG (slow rate)
  static List<double> generateBradycardia() {
    final heartRate = 40 + _random.nextInt(15); // 40-55 BPM
    return generateNormal(heartRate: heartRate);
  }

  /// Generates atrial fibrillation pattern
  static List<double> generateAFib() {
    final data = <double>[];
    while (data.length < totalSamples) {
      // Irregular R-R intervals
      final cycleLength = 0.5 + _random.nextDouble() * 0.6; // 0.5-1.1s
      data.addAll(_generatePQRST(cycleLength, afib: true));
    }
    return data.sublist(0, totalSamples);
  }

  /// Generates ST elevation pattern
  static List<double> generateSTElevation() {
    final cycleLength = 60.0 / 80;
    final data = <double>[];
    while (data.length < totalSamples) {
      data.addAll(_generatePQRST(cycleLength, stElevation: true));
    }
    return data.sublist(0, totalSamples);
  }

  /// Generates PVC pattern (occasional wide bizarre QRS)
  static List<double> generatePVC() {
    final baseCycleLength = 60.0 / 75;
    final data = <double>[];
    int beatCount = 0;
    while (data.length < totalSamples) {
      beatCount++;
      if (beatCount % 4 == 0) {
        // PVC beat: wider, inverted, taller
        final samples = (baseCycleLength * sampleRate).round();
        final pvcData = List<double>.filled(samples, 0.0);
        for (int i = 0; i < samples; i++) {
          final t = i / sampleRate;
          double value = 0.0;
          // No P wave, wide QRS
          value += _gaussian(t, baseCycleLength * 0.20, 0.025, -1.5);
          value += _gaussian(t, baseCycleLength * 0.28, 0.020, 0.8);
          value += _gaussian(t, baseCycleLength * 0.45, 0.06, -0.25);
          value += (_random.nextDouble() - 0.5) * 0.03;
          pvcData[i] = value;
        }
        data.addAll(pvcData);
      } else {
        data.addAll(_generatePQRST(baseCycleLength));
      }
    }
    return data.sublist(0, totalSamples);
  }

  /// Generate random ECG with weighted probability
  static ({List<double> data, String type}) generateRandom() {
    final roll = _random.nextDouble();
    if (roll < 0.50) {
      final hr = 60 + _random.nextInt(30);
      return (data: generateNormal(heartRate: hr), type: 'normal');
    } else if (roll < 0.65) {
      return (data: generateTachycardia(), type: 'tachycardia');
    } else if (roll < 0.78) {
      return (data: generateBradycardia(), type: 'bradycardia');
    } else if (roll < 0.88) {
      return (data: generateAFib(), type: 'afib');
    } else if (roll < 0.95) {
      return (data: generateSTElevation(), type: 'st_elevation');
    } else {
      return (data: generatePVC(), type: 'pvc');
    }
  }
}
