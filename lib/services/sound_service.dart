import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// ── Web Audio API bindings ───────────────────────────────────────────────────

@JS('AudioContext')
extension type _AudioCtx._(JSObject _) implements JSObject {
  external factory _AudioCtx();
  external double get currentTime;
  external _AudioDest get destination;
  external _Osc createOscillator();
  external _Gain createGain();
}

extension type _AudioDest._(JSObject _) implements JSObject {}

extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double value, double startTime);
  external void linearRampToValueAtTime(double value, double endTime);
}

extension type _Osc._(JSObject _) implements JSObject {
  external set type(String t);
  external _AudioParam get frequency;
  external void connect(JSObject destination);
  external void start([double when]);
  external void stop([double when]);
}

extension type _Gain._(JSObject _) implements JSObject {
  external _AudioParam get gain;
  external void connect(JSObject destination);
}

// ── SoundService ─────────────────────────────────────────────────────────────

class SoundService {
  SoundService._();

  static bool enabled = true;
  static _AudioCtx? _ctx;

  static _AudioCtx? get _audio {
    if (!kIsWeb) return null;
    try {
      return _ctx ??= _AudioCtx();
    } catch (_) {
      return null;
    }
  }

  static void _beep(
    double hz,
    double secs, {
    String wave = 'sine',
    double vol = 0.22,
    double after = 0.0,
  }) {
    if (!enabled) return;
    final ctx = _audio;
    if (ctx == null) return;
    try {
      final t0 = ctx.currentTime + after;
      final t1 = t0 + secs;

      final osc = ctx.createOscillator();
      final amp = ctx.createGain();

      osc.type = wave;
      osc.frequency.value = hz;

      amp.gain.value = 0.0;
      amp.gain.setValueAtTime(vol, t0);
      amp.gain.linearRampToValueAtTime(0.0, t1);

      osc.connect(amp as JSObject);
      amp.connect(ctx.destination as JSObject);

      osc.start(t0);
      osc.stop(t1 + 0.01);
    } catch (_) {}
  }

  // ── Public sounds ───────────────────────────────────────────────────────

  static void roll() {
    for (int i = 0; i < 4; i++) {
      _beep(120 + i * 65.0, 0.07, wave: 'sawtooth', vol: 0.12, after: i * 0.055);
    }
  }

  static void handWin() {
    const notes = [523.25, 659.25, 783.99]; // C5 E5 G5
    for (int i = 0; i < notes.length; i++) {
      _beep(notes[i], 0.22, after: i * 0.09);
    }
  }

  static void handLose() {
    _beep(330.0, 0.14);
    _beep(261.63, 0.35, wave: 'triangle', vol: 0.18, after: 0.15);
  }

  static void betWon() {
    const notes = [523.25, 659.25, 783.99, 1046.5]; // C5 E5 G5 C6
    for (int i = 0; i < notes.length; i++) {
      _beep(notes[i], 0.18, after: i * 0.07);
    }
  }

  static void betLost() {
    _beep(220.0, 0.45, wave: 'triangle', vol: 0.15);
  }

  static void tick() {
    _beep(880.0, 0.05, vol: 0.08);
  }

  static void gameEnd() {
    const notes = [523.25, 659.25, 783.99, 659.25, 1046.5];
    const delays = [0.0, 0.10, 0.20, 0.35, 0.45];
    for (int i = 0; i < notes.length; i++) {
      _beep(notes[i], 0.28, after: delays[i]);
    }
  }
}
