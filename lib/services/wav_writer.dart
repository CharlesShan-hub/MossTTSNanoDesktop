import 'dart:io';

/// 将 float64 音频采样写入 16-bit WAV 文件
void writeWav(String path, List<double> samples, int sampleRate) {
  final file = File(path);
  final buffer = <int>[];
  void w32(int v) {
    buffer.add(v & 0xFF);
    buffer.add((v >> 8) & 0xFF);
    buffer.add((v >> 16) & 0xFF);
    buffer.add((v >> 24) & 0xFF);
  }
  void w16(int v) {
    buffer.add(v & 0xFF);
    buffer.add((v >> 8) & 0xFF);
  }
  buffer.addAll('RIFF'.codeUnits);
  w32(36 + samples.length * 2);
  buffer.addAll('WAVE'.codeUnits);
  buffer.addAll('fmt '.codeUnits);
  w32(16);
  w16(1);      // PCM
  w16(1);      // mono
  w32(sampleRate);
  w32(sampleRate * 2); // byte rate
  w16(2);      // block align
  w16(16);     // bits per sample
  buffer.addAll('data'.codeUnits);
  w32(samples.length * 2);
  for (final s in samples) {
    final clamped = (s * 32767).clamp(-32768, 32767).toInt();
    w16(clamped & 0xFFFF);
  }
  file.writeAsBytesSync(buffer);
}
