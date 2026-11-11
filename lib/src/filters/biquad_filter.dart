import 'dart:math' as math;

enum BiquadFilterType { lowpass, highpass, bandpass, notch, peakingEq }

/// 2nd-order IIR Biquad filter based on the Audio EQ Cookbook by Robert Bristow-Johnson.
class BiquadFilter {
  BiquadFilterType _type;
  double _cutoffFrequency;
  double _q;
  double _sampleRate;
  double _gainDb;

  double _b0 = 1.0;
  double _b1 = 0.0;
  double _b2 = 0.0;
  double _a1 = 0.0;
  double _a2 = 0.0;

  // Direct Form I state history
  double _x1 = 0.0;
  double _x2 = 0.0;
  double _y1 = 0.0;
  double _y2 = 0.0;

  BiquadFilter({
    BiquadFilterType type = BiquadFilterType.lowpass,
    double cutoffFrequency = 1000.0,
    double q = 0.70710678, // Butterworth Q = 1 / sqrt(2)
    double sampleRate = 44100.0,
    double gainDb = 0.0,
  })  : _type = type,
        _cutoffFrequency = cutoffFrequency,
        _q = q,
        _sampleRate = sampleRate,
        _gainDb = gainDb {
    _recomputeCoefficients();
  }

  factory BiquadFilter.lowpass({double cutoffFrequency = 1000.0, double q = 0.70710678, double sampleRate = 44100.0}) {
    return BiquadFilter(type: BiquadFilterType.lowpass, cutoffFrequency: cutoffFrequency, q: q, sampleRate: sampleRate);
  }

  factory BiquadFilter.highpass({double cutoffFrequency = 1000.0, double q = 0.70710678, double sampleRate = 44100.0}) {
    return BiquadFilter(type: BiquadFilterType.highpass, cutoffFrequency: cutoffFrequency, q: q, sampleRate: sampleRate);
  }

  factory BiquadFilter.bandpass({double cutoffFrequency = 1000.0, double q = 1.0, double sampleRate = 44100.0}) {
    return BiquadFilter(type: BiquadFilterType.bandpass, cutoffFrequency: cutoffFrequency, q: q, sampleRate: sampleRate);
  }

  factory BiquadFilter.notch({double cutoffFrequency = 1000.0, double q = 1.0, double sampleRate = 44100.0}) {
    return BiquadFilter(type: BiquadFilterType.notch, cutoffFrequency: cutoffFrequency, q: q, sampleRate: sampleRate);
  }

  BiquadFilterType get type => _type;
  set type(BiquadFilterType value) {
    if (_type != value) {
      _type = value;
      _recomputeCoefficients();
    }
  }

  double get cutoffFrequency => _cutoffFrequency;
  set cutoffFrequency(double value) {
    if (_cutoffFrequency != value) {
      _cutoffFrequency = value;
      _recomputeCoefficients();
    }
  }

  double get q => _q;
  set q(double value) {
    if (_q != value) {
      _q = value;
      _recomputeCoefficients();
    }
  }

  double get sampleRate => _sampleRate;
  set sampleRate(double value) {
    if (_sampleRate != value) {
      _sampleRate = value;
      _recomputeCoefficients();
    }
  }

  double get gainDb => _gainDb;
  set gainDb(double value) {
    if (_gainDb != value) {
      _gainDb = value;
      _recomputeCoefficients();
    }
  }

  void reset() {
    _x1 = 0.0;
    _x2 = 0.0;
    _y1 = 0.0;
    _y2 = 0.0;
  }

  void _recomputeCoefficients() {
    final nyquist = _sampleRate * 0.5;
    final clampedFreq = _cutoffFrequency.clamp(10.0, nyquist - 10.0);
    final omega = 2.0 * math.pi * (clampedFreq / _sampleRate);
    final cosW = math.cos(omega);
    final sinW = math.sin(omega);
    final alpha = sinW / (2.0 * math.max(_q, 1e-4));
    final a = math.pow(10.0, _gainDb / 40.0) as double;

    double b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0;

    switch (_type) {
      case BiquadFilterType.lowpass:
        b0 = (1.0 - cosW) * 0.5;
        b1 = 1.0 - cosW;
        b2 = (1.0 - cosW) * 0.5;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.highpass:
        b0 = (1.0 + cosW) * 0.5;
        b1 = -(1.0 + cosW);
        b2 = (1.0 + cosW) * 0.5;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.bandpass:
        b0 = alpha;
        b1 = 0.0;
        b2 = -alpha;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.notch:
        b0 = 1.0;
        b1 = -2.0 * cosW;
        b2 = 1.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW;
        a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.peakingEq:
        b0 = 1.0 + alpha * a;
        b1 = -2.0 * cosW;
        b2 = 1.0 - alpha * a;
        a0 = 1.0 + alpha / a;
        a1 = -2.0 * cosW;
        a2 = 1.0 - alpha / a;
        break;
    }

    final invA0 = 1.0 / a0;
    _b0 = b0 * invA0;
    _b1 = b1 * invA0;
    _b2 = b2 * invA0;
    _a1 = a1 * invA0;
    _a2 = a2 * invA0;
  }

  /// Processes a single audio sample through the biquad filter.
  double process(double input) {
    final output = _b0 * input + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = output;
    return output;
  }

  /// Processes an audio buffer in-place.
  void processBuffer(List<double> buffer) {
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = process(buffer[i]);
    }
  }
}
