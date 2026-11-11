import 'dart:math' as math;

/// Audio mixer bus / group representing a routing node in the audio mixer hierarchy.
class AudioMixerGroup {
  final String name;
  AudioMixerGroup? parent;
  final List<AudioMixerGroup> children = [];

  double _volume = 1.0;
  bool muted = false;
  bool solo = false;

  /// DSP effects inserted on this group channel (BiquadFilter, SchroederReverb, FeedbackDelay).
  final List<dynamic> effects = [];

  AudioMixerGroup(this.name, {double volume = 1.0, this.parent}) {
    this.volume = volume;
    parent?._addChild(this);
  }

  void _addChild(AudioMixerGroup child) {
    if (!children.contains(child)) {
      children.add(child);
      child.parent = this;
    }
  }

  double get volume => _volume;
  set volume(double val) => _volume = val.clamp(0.0, 2.0);

  /// Volume in decibels (0 dB = 1.0, -6 dB = 0.5, -20 dB = 0.1).
  double get volumeDb {
    if (_volume <= 1e-4) return -80.0;
    return 20.0 * (math.log(_volume) / math.ln10);
  }

  set volumeDb(double db) {
    if (db <= -80.0) {
      _volume = 0.0;
    } else {
      _volume = math.pow(10.0, db / 20.0).toDouble();
    }
  }

  /// Calculates the effective volume considering parent groups and mute states.
  double get effectiveVolume {
    if (muted) return 0.0;
    final parentVol = parent?.effectiveVolume ?? 1.0;
    return _volume * parentVol;
  }

  /// Runs [buffer] through this group's DSP effect chain and applies [effectiveVolume].
  void processBuffer(List<double> buffer) {
    final vol = effectiveVolume;
    if (vol <= 1e-5) {
      buffer.fillRange(0, buffer.length, 0.0);
      return;
    }

    // Process through attached DSP effects
    for (final effect in effects) {
      if (effect is dynamic && effect.processBuffer != null) {
        effect.processBuffer(buffer);
      }
    }

    if ((vol - 1.0).abs() > 1e-4) {
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] *= vol;
      }
    }
  }
}
