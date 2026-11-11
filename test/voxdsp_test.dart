import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:voxdsp/voxdsp.dart';

void main() {
  group('voxdsp - BiquadFilter', () {
    test('Lowpass filter attenuates high frequencies more than low frequencies', () {
      final filter = BiquadFilter.lowpass(cutoffFrequency: 500.0, sampleRate: 44100.0);

      // Low frequency (100 Hz) sine wave
      double lowEnergy = 0.0;
      for (int i = 0; i < 441; i++) {
        final sample = math.sin(2.0 * math.pi * 100.0 * i / 44100.0);
        final out = filter.process(sample);
        lowEnergy += out * out;
      }

      filter.reset();

      // High frequency (5000 Hz) sine wave
      double highEnergy = 0.0;
      for (int i = 0; i < 441; i++) {
        final sample = math.sin(2.0 * math.pi * 5000.0 * i / 44100.0);
        final out = filter.process(sample);
        highEnergy += out * out;
      }

      expect(lowEnergy, greaterThan(highEnergy * 5.0));
    });
  });

  group('voxdsp - FeedbackDelay', () {
    test('Delay buffers impulse and outputs delayed echo', () {
      final delay = FeedbackDelay(delayTimeSeconds: 0.01, feedback: 0.5, wet: 1.0, dry: 0.0, sampleRate: 1000.0);
      // 0.01s * 1000 Hz = 10 samples delay
      final out0 = delay.process(1.0);
      expect(out0, equals(0.0)); // Dry is 0, delay is empty

      // Advance 9 samples
      for (int i = 0; i < 9; i++) {
        expect(delay.process(0.0), equals(0.0));
      }

      // 10th sample should output delayed impulse
      final delayedOut = delay.process(0.0);
      expect(delayedOut, equals(1.0));
    });
  });

  group('voxdsp - SchroederReverb', () {
    test('Reverberator sustains decay tail after input impulse', () {
      final reverb = SchroederReverb(roomSize: 0.8, wet: 1.0, dry: 0.0, sampleRate: 44100.0);

      // Impulse
      reverb.process(1.0);

      // Subsequent output should have decaying energy
      double tailEnergy = 0.0;
      for (int i = 0; i < 2000; i++) {
        final out = reverb.process(0.0);
        tailEnergy += out * out;
      }

      expect(tailEnergy, greaterThan(0.01));
    });
  });

  group('voxdsp - SpatialAudio3D', () {
    test('Distance attenuation and stereo panning', () {
      // Listener at origin facing -Z with right along +X
      const listenerPos = DspVec3.zero;

      // Source placed 10m to the right (+X)
      const sourceRight = DspVec3(10.0, 0.0, 0.0);
      final resRight = SpatialAudio3D.calculate(
        sourcePosition: sourceRight,
        listenerPosition: listenerPos,
        minDistance: 1.0,
      );

      expect(resRight.volume, closeTo(0.1, 0.02)); // 1 / (1 + 9) = 0.1
      expect(resRight.pan, closeTo(1.0, 1e-4)); // Full right
      expect(resRight.rightGain, greaterThan(resRight.leftGain));

      // Source placed 10m to the left (-X)
      const sourceLeft = DspVec3(-10.0, 0.0, 0.0);
      final resLeft = SpatialAudio3D.calculate(
        sourcePosition: sourceLeft,
        listenerPosition: listenerPos,
        minDistance: 1.0,
      );

      expect(resLeft.pan, closeTo(-1.0, 1e-4)); // Full left
      expect(resLeft.leftGain, greaterThan(resLeft.rightGain));
    });

    test('Doppler pitch shift on moving source', () {
      const listenerPos = DspVec3.zero;
      const sourcePos = DspVec3(0.0, 0.0, 10.0); // Source in front

      // Source moving towards listener (-Z direction) at 34.33 m/s (~0.1 mach)
      const approachingVel = DspVec3(0.0, 0.0, -34.33);
      final resApproach = SpatialAudio3D.calculate(
        sourcePosition: sourcePos,
        listenerPosition: listenerPos,
        sourceVelocity: approachingVel,
      );

      expect(resApproach.dopplerFactor, greaterThan(1.05)); // Pitch shifted up
    });
  });

  group('voxdsp - AudioMixerGroup', () {
    test('Volume propagation, decibels, and muting', () {
      final master = AudioMixerGroup('Master', volume: 0.8);
      final sfx = AudioMixerGroup('SFX', volume: 0.5, parent: master);

      expect(sfx.effectiveVolume, closeTo(0.4, 1e-4));
      expect(master.volumeDb, closeTo(-1.938, 0.05));

      // Mute master mutes child
      master.muted = true;
      expect(sfx.effectiveVolume, equals(0.0));
    });
  });
}
