import 'dart:math' as math;

enum DistanceModel { inverse, linear, exponential }

class DspVec3 {
  final double x;
  final double y;
  final double z;

  const DspVec3(this.x, this.y, this.z);

  static const DspVec3 zero = DspVec3(0.0, 0.0, 0.0);
  static const DspVec3 forward = DspVec3(0.0, 0.0, -1.0);
  static const DspVec3 right = DspVec3(1.0, 0.0, 0.0);
  static const DspVec3 up = DspVec3(0.0, 1.0, 0.0);

  DspVec3 operator +(DspVec3 other) => DspVec3(x + other.x, y + other.y, z + other.z);
  DspVec3 operator -(DspVec3 other) => DspVec3(x - other.x, y - other.y, z - other.z);
  DspVec3 operator -() => DspVec3(-x, -y, -z);
  DspVec3 operator *(double scalar) => DspVec3(x * scalar, y * scalar, z * scalar);
  DspVec3 operator /(double scalar) => DspVec3(x / scalar, y / scalar, z / scalar);

  double dot(DspVec3 other) => x * other.x + y * other.y + z * other.z;

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  DspVec3 get normalized {
    final len = length;
    if (len < 1e-12) return DspVec3.zero;
    return this / len;
  }
}

class SpatialAudioResult {
  final double volume;
  final double pan;
  final double leftGain;
  final double rightGain;
  final double dopplerFactor;

  const SpatialAudioResult({
    required this.volume,
    required this.pan,
    required this.leftGain,
    required this.rightGain,
    required this.dopplerFactor,
  });
}

/// 3D distance attenuation, equal-power stereophonic panning, and Doppler calculations.
class SpatialAudio3D {
  static const double speedOfSound = 343.3; // meters/sec in air at 20 C

  /// Computes spatial audio volume, stereo pan, and Doppler pitch factor.
  static SpatialAudioResult calculate({
    required DspVec3 sourcePosition,
    required DspVec3 listenerPosition,
    DspVec3 listenerForward = DspVec3.forward,
    DspVec3 listenerRight = DspVec3.right,
    DspVec3 sourceVelocity = DspVec3.zero,
    DspVec3 listenerVelocity = DspVec3.zero,
    DistanceModel distanceModel = DistanceModel.inverse,
    double minDistance = 1.0,
    double maxDistance = 50.0,
    double rolloffFactor = 1.0,
    double dopplerIntensity = 1.0,
  }) {
    final toSource = sourcePosition - listenerPosition;
    final distance = toSource.length;

    // 1. Distance Attenuation
    double volume = 1.0;
    final clampedDist = math.max(minDistance, distance);

    switch (distanceModel) {
      case DistanceModel.inverse:
        volume = minDistance / (minDistance + rolloffFactor * (clampedDist - minDistance));
        break;
      case DistanceModel.linear:
        volume = 1.0 - rolloffFactor * (clampedDist - minDistance) / (maxDistance - minDistance);
        break;
      case DistanceModel.exponential:
        volume = math.pow(clampedDist / minDistance, -rolloffFactor).toDouble();
        break;
    }

    if (distance > maxDistance && distanceModel == DistanceModel.linear) {
      volume = 0.0;
    }
    volume = volume.clamp(0.0, 1.0);

    // 2. Stereo Panning (equal-power law)
    double pan = 0.0;
    if (distance > 1e-6) {
      final toSourceDir = toSource.normalized;
      // Dot product with listener's right axis gives lateral displacement: -1 left, +1 right
      pan = listenerRight.normalized.dot(toSourceDir).clamp(-1.0, 1.0);
    }

    final panAngle = (pan + 1.0) * (math.pi * 0.25); // Range [0, pi/2]
    final leftGain = math.cos(panAngle);
    final rightGain = math.sin(panAngle);

    // 3. Doppler Pitch Calculation
    double doppler = 1.0;
    if (dopplerIntensity > 0.0 && distance > 1e-4) {
      final unitSourceToListener = (-toSource).normalized;
      final vs = sourceVelocity.dot(unitSourceToListener);
      final vl = listenerVelocity.dot(unitSourceToListener);

      final c = speedOfSound;
      final clampedVs = vs.clamp(-c * 0.95, c * 0.95);
      final clampedVl = vl.clamp(-c * 0.95, c * 0.95);

      final baseDoppler = (c - clampedVl) / (c - clampedVs);
      doppler = 1.0 + (baseDoppler - 1.0) * dopplerIntensity;
    }

    return SpatialAudioResult(
      volume: volume,
      pan: pan,
      leftGain: leftGain,
      rightGain: rightGain,
      dopplerFactor: doppler,
    );
  }
}
