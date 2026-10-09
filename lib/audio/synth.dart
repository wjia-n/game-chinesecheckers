import 'dart:math';
import 'dart:typed_data';

/// Programmatic sound synthesis for the Imperial Porcelain sound set.
/// Everything is generated as 16-bit mono WAV bytes at 22050 Hz —
/// no external audio assets. Ceramic "toks", wooden knocks, pentatonic
/// chimes and a looping guzheng-tinged ambient bed.
class Synth {
  static const int rate = 22050;
  static final Random _r = Random(20261009);

  static Uint8List wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void str(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    var peak = 0.0;
    for (final s in samples) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    final gain = peak > 0 ? 0.85 / peak : 1.0;
    for (int i = 0; i < n; i++) {
      final v = (samples[i] * gain).clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static double _env(int i, int n, double decay) =>
      exp(-decay * i / n);

  /// Ceramic "tok": bright partials with fast decay + tiny strike transient.
  static List<double> tok(double baseFreq, double seconds) {
    final n = (rate * seconds).round();
    final out = List<double>.filled(n, 0.0);
    final partials = [1.0, 1.62, 2.51, 3.9];
    final amps = [1.0, 0.45, 0.28, 0.12];
    for (int i = 0; i < n; i++) {
      final t = i / rate;
      var s = 0.0;
      for (int p = 0; p < partials.length; p++) {
        s += amps[p] *
            sin(2 * pi * baseFreq * partials[p] * t) *
            _env(i, n, 5.0 + p * 3.0);
      }
      // Strike transient.
      if (i < rate * 0.004) {
        s += (_r.nextDouble() * 2 - 1) * 0.5 * (1 - i / (rate * 0.004));
      }
      out[i] = s * 0.5;
    }
    return out;
  }

  /// Dull wooden knock for invalid moves.
  static List<double> knock() {
    final n = (rate * 0.16).round();
    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final t = i / rate;
      var s = sin(2 * pi * 165 * t) * _env(i, n, 9.0) * 0.8 +
          sin(2 * pi * 98 * t) * _env(i, n, 7.0) * 0.6;
      if (i < rate * 0.008) {
        s += (_r.nextDouble() * 2 - 1) * 0.6 * (1 - i / (rate * 0.008));
      }
      out[i] = s * 0.6;
    }
    return out;
  }

  /// Soft wooden step thock.
  static List<double> thock() {
    final n = (rate * 0.11).round();
    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final t = i / rate;
      var s = sin(2 * pi * 310 * t) * _env(i, n, 8.0) * 0.7 +
          sin(2 * pi * 190 * t) * _env(i, n, 6.5) * 0.5;
      if (i < rate * 0.005) {
        s += (_r.nextDouble() * 2 - 1) * 0.35 * (1 - i / (rate * 0.005));
      }
      out[i] = s * 0.6;
    }
    return out;
  }

  /// Pentatonic pluck used for chimes and the music bed.
  static List<double> pluck(double freq, double seconds,
      {double brightness = 0.5}) {
    final n = (rate * seconds).round();
    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final t = i / rate;
      final e = _env(i, n, 3.2);
      out[i] = (sin(2 * pi * freq * t) * 0.7 +
              sin(2 * pi * freq * 2.01 * t) * 0.3 * brightness +
              sin(2 * pi * freq * 3.02 * t) * 0.12 * brightness) *
          e *
          0.55;
    }
    return out;
  }

  static List<double> _mix(List<List<double>> parts) {
    var n = 0;
    for (final p in parts) {
      if (p.length > n) n = p.length;
    }
    final out = List<double>.filled(n, 0.0);
    for (final p in parts) {
      for (int i = 0; i < p.length; i++) {
        out[i] += p[i];
      }
    }
    return out;
  }

  static List<double> _at(List<double> s, double seconds) {
    final pad = List<double>.filled((rate * seconds).round(), 0.0);
    return [...pad, ...s];
  }

  // C major pentatonic across two octaves.
  static const _penta = [
    261.63, 293.66, 329.63, 392.00, 440.00, // C4 D4 E4 G4 A4
    523.25, 587.33, 659.25, 783.99, 880.00, // C5 D5 E5 G5 A5
    1046.50, 1174.66, 1318.51, 1567.98, 1760.00, // C6...
  ];

  /// Ascending hop: two ceramic toks rising in pitch.
  static List<double> hop() =>
      _mix([tok(620, 0.09), _at(tok(880, 0.11), 0.07)]);

  static List<double> start() => _mix([
        _at(pluck(_penta[5], 0.5), 0.0),
        _at(pluck(_penta[7], 0.5), 0.14),
        _at(pluck(_penta[9], 0.7), 0.28),
      ]);

  static List<double> win() => _mix([
        for (int i = 0; i < 7; i++)
          _at(pluck(_penta[5 + i], 0.6, brightness: 0.7), i * 0.13),
        _at(pluck(_penta[12], 1.0, brightness: 0.8), 0.91),
      ]);

  static List<double> lose() => _mix([
        _at(pluck(_penta[4], 0.6, brightness: 0.3), 0.0),
        _at(pluck(_penta[2], 0.6, brightness: 0.3), 0.22),
        _at(pluck(_penta[0], 0.9, brightness: 0.3), 0.44),
      ]);

  static List<double> click() => tok(1500, 0.05);

  static List<double> turnTick() {
    final n = (rate * 0.05).round();
    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final t = i / rate;
      out[i] = sin(2 * pi * 1180 * t) * _env(i, n, 10.0) * 0.25;
    }
    return out;
  }

  static List<double> hint() => pluck(990, 0.35, brightness: 0.4);

  /// 16-second looping ambient bed: slow pad chords (Am–F–C–G voicings in
  /// pentatonic-friendly tones) with sparse plucked melody. Deterministic.
  static List<double> musicBed({required bool calm}) {
    const seconds = 16.0;
    final n = (rate * seconds).round();
    final out = List<double>.filled(n, 0.0);
    // Pad chords: root+fifth+octave swells, 4s each.
    const chords = [
      [220.00, 329.63, 440.00], // Am-ish
      [174.61, 261.63, 349.23], // F-ish
      [130.81, 196.00, 261.63], // C-ish
      [196.00, 293.66, 392.00], // G-ish
    ];
    for (int c = 0; c < 4; c++) {
      final start = (c * 4 * rate).round();
      final len = (4 * rate).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / rate;
        final swell = sin(pi * i / len); // slow attack/release
        var s = 0.0;
        for (final f in chords[c]) {
          s += sin(2 * pi * f * t) * 0.33;
          s += sin(2 * pi * f * 2.0 * t) * 0.08;
        }
        out[start + i] += s * swell * 0.16;
      }
    }
    // Sparse pentatonic melody, deterministic pattern.
    final melody = calm
        ? [7, -1, 9, -1, 8, -1, 7, -1, 5, -1, 7, -1, 4, -1, 5, -1]
        : [9, 7, 9, 11, 9, 7, 5, 7, 9, -1, 11, 9, 7, 5, 4, 5];
    for (int k = 0; k < melody.length; k++) {
      final idx = melody[k];
      if (idx < 0) continue;
      final start = (k * rate).round();
      final note = pluck(_penta[idx.clamp(0, _penta.length - 1)], 1.6,
          brightness: 0.55);
      for (int i = 0; i < note.length && start + i < n; i++) {
        out[start + i] += note[i] * 0.5;
      }
    }
    // Seamless loop: crossfade the last 0.5s with the first 0.5s.
    final fade = (rate * 0.5).round();
    for (int i = 0; i < fade; i++) {
      final a = i / fade;
      out[i] = out[i] * a + out[n - fade + i] * (1 - a);
    }
    return out.sublist(0, n - fade);
  }
}
