class _CombFilter {
  final List<double> _buffer;
  int _index = 0;
  double _filterStore = 0.0;
  double feedback = 0.8;
  double damp = 0.2;

  _CombFilter(int size) : _buffer = List<double>.filled(size, 0.0);

  int get size => _buffer.length;

  void reset() {
    _buffer.fillRange(0, _buffer.length, 0.0);
    _index = 0;
    _filterStore = 0.0;
  }

  double process(double input) {
    final output = _buffer[_index];
    _filterStore = output * (1.0 - damp) + _filterStore * damp;
    _buffer[_index] = input + _filterStore * feedback;

    _index++;
    if (_index >= _buffer.length) _index = 0;
    return output;
  }
}

class _AllpassFilter {
  final List<double> _buffer;
  int _index = 0;
  double feedback = 0.5;

  _AllpassFilter(int size) : _buffer = List<double>.filled(size, 0.0);

  int get size => _buffer.length;

  void reset() {
    _buffer.fillRange(0, _buffer.length, 0.0);
    _index = 0;
  }

  double process(double input) {
    final bufOut = _buffer[_index];
    final output = -input + bufOut;
    _buffer[_index] = input + (bufOut * feedback);

    _index++;
    if (_index >= _buffer.length) _index = 0;
    return output;
  }
}

/// Algorithmic Schroeder / Freeverb reverberator with parallel comb filters and series allpass diffusers.
class SchroederReverb {
  double _roomSize;
  double _damp;
  double _wet;
  double _dry;

  late final List<_CombFilter> _combFilters;
  late final List<_AllpassFilter> _allpassFilters;

  SchroederReverb({
    double roomSize = 0.7,
    double damp = 0.25,
    double wet = 0.35,
    double dry = 1.0,
    double sampleRate = 44100.0,
  })  : _roomSize = roomSize,
        _damp = damp,
        _wet = wet,
        _dry = dry {
    final scale = sampleRate / 44100.0;

    // Classic Freeverb tuned delay lengths
    final combTunings = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
    _combFilters = combTunings.map((t) => _CombFilter((t * scale).round())).toList();

    final allpassTunings = [556, 441, 341, 225];
    _allpassFilters = allpassTunings.map((t) => _AllpassFilter((t * scale).round())).toList();

    _updateParameters();
  }

  double get roomSize => _roomSize;
  set roomSize(double value) {
    _roomSize = value.clamp(0.0, 0.98);
    _updateParameters();
  }

  double get damp => _damp;
  set damp(double value) {
    _damp = value.clamp(0.0, 1.0);
    _updateParameters();
  }

  double get wet => _wet;
  set wet(double value) => _wet = value.clamp(0.0, 1.0);

  double get dry => _dry;
  set dry(double value) => _dry = value.clamp(0.0, 1.0);

  void _updateParameters() {
    for (final comb in _combFilters) {
      comb.feedback = _roomSize;
      comb.damp = _damp;
    }
  }

  void reset() {
    for (final c in _combFilters) {
      c.reset();
    }
    for (final a in _allpassFilters) {
      a.reset();
    }
  }

  /// Processes a single audio sample and returns reverberated output.
  double process(double input) {
    double combSum = 0.0;
    for (int i = 0; i < _combFilters.length; i++) {
      combSum += _combFilters[i].process(input);
    }
    combSum *= 0.125; // Scale by 1 / 8 parallel filters

    double out = combSum;
    for (int i = 0; i < _allpassFilters.length; i++) {
      out = _allpassFilters[i].process(out);
    }

    return input * _dry + out * _wet;
  }

  /// Processes an audio buffer in-place.
  void processBuffer(List<double> buffer) {
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = process(buffer[i]);
    }
  }
}
