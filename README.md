# voxdsp

A lightweight, pure Dart digital signal processing (DSP), audio filtering, reverberation, spatial 3D audio, and mixer bus hierarchy engine.

## Features

- **2nd-Order IIR Biquad Filters**: Robert Bristow-Johnson Audio EQ Cookbook filters (`lowpass`, `highpass`, `bandpass`, `notch`, `peakingEq`) with resonance and cutoff tuning.
- **Algorithmic Schroeder Reverb**: Classic 8-comb filter + 4-allpass diffuser reverberation model with room size and damping controls.
- **Feedback Delay**: Delay line with feedback recirculation and wet/dry mix.
- **3D Spatial Audio**: Inverse, linear, and exponential distance attenuation models, equal-power stereo amplitude panning, and Doppler pitch shift calculation.
- **Audio Mixer Groups**: Hierarchical parent-child bus routing with decibel scaling, mute/solo flags, and effect chain insertion.
- **Pure Dart**: Zero platform dependencies (`dart:io` or `package:web`), designed for native desktop, WebGL, or headless engines.
