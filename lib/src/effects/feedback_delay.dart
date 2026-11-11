import 'dart:math' as math;

/// Single-channel or stereo-capable feedback delay line effect.
class FeedbackDelay {
  double _delayTimeSeconds;
  double _feedback;
  double _wet;
  double _dry;
  final double sampleRate;

  late List<double> _buffer;
  int _bufferSize = 0;
  int _writeIndex = 0;

  FeedbackDelay({
    double delayTimeSeconds = 0.25,
    double feedback = 0.4,
    double wet = 0.5,
    double dry = 1.0,
    this.sampleRate = 44100.0,
  })  : _delayTimeSeconds = delayTimeSeconds,
        _feedback = feedback,
        _wet = wet,
        _dry = dry {
    _initBuffer();
  }

  double get delayTimeSeconds => _delayTimeSeconds;
  set delayTimeSeconds(double value) {
    if (_delayTimeSeconds != value) {
      _delayTimeSeconds = value;
      _initBuffer();
    }
  }

  double get feedback => _feedback;
  set feedback(double value) => _feedback = value.clamp(0.0, 0.98);

  double get wet => _wet;
  set wet(double value) => _wet = value.clamp(0.0, 1.0);

  double get dry => _dry;
  set dry(double value) => _dry = value.clamp(0.0, 1.0);

  void _initBuffer() {
    _bufferSize = math.max(1, (_delayTimeSeconds * sampleRate).round());
    _buffer = List<double>.filled(_bufferSize, 0.0);
    _writeIndex = 0;
  }

  void reset() {
    _buffer.fillRange(0, _buffer.length, 0.0);
    _writeIndex = 0;
  }

  double process(double input) {
    final delayed = _buffer[_writeIndex];
    final toWrite = input + delayed * _feedback;
    _buffer[_writeIndex] = toWrite;

    _writeIndex = (_writeIndex + 1) % _bufferSize;
    return input * _dry + delayed * _wet;
  }

  void processBuffer(List<double> buffer) {
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = process(buffer[i]);
    }
  }
}
