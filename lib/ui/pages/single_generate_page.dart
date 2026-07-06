import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/voice.dart';
import '../../models/generation_params.dart';
import '../../services/tts_service.dart';
import '../../services/voice_manager.dart';
import '../../services/audio_player_service.dart';
import '../widgets/parameter_slider.dart';

class SingleGeneratePage extends StatefulWidget {
  const SingleGeneratePage({super.key});

  @override
  State<SingleGeneratePage> createState() => _SingleGeneratePageState();
}

class _SingleGeneratePageState extends State<SingleGeneratePage> {
  final _textController = TextEditingController();
  bool _showAdvanced = false;
  Voice? _selectedVoice;
  GenerationParams _params = GenerationParams();
  Uint8List? _generatedAudio;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final voiceManager = context.watch<VoiceManager>();
    final ttsService = context.watch<TtsService>();
    final audioPlayer = context.read<AudioPlayerService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MOSS-TTS-Nano'),
        actions: [
          IconButton(
            icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
            onPressed: () {
              setState(() {
                _showAdvanced = !_showAdvanced;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 音色选择
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voice',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Voice>(
                        value: _selectedVoice,
                        isExpanded: true,
                        items: voiceManager.voices.map((voice) {
                          return DropdownMenuItem(
                            value: voice,
                            child: Text(voice.name),
                          );
                        }).toList(),
                        decoration: const InputDecoration(
                          hintText: 'Select a voice',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (voice) {
                          setState(() {
                            _selectedVoice = voice;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 文本输入
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Text',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_textController.text.length} chars',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _textController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: 'Enter text to synthesize...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 高级参数
              if (_showAdvanced) _buildAdvancedParams(),
              if (_showAdvanced) const SizedBox(height: 16),
              // 生成按钮
              FilledButton.icon(
                onPressed: _selectedVoice == null ||
                        _textController.text.trim().isEmpty ||
                        ttsService.state == TtsServiceState.loading ||
                        ttsService.state == TtsServiceState.generating
                    ? null
                    : () => _generateAudio(ttsService, audioPlayer),
                icon: ttsService.state == TtsServiceState.generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(ttsService.state == TtsServiceState.generating
                    ? 'Generating...'
                    : 'Generate'),
              ),
              const SizedBox(height: 16),
              // 音频播放器
              if (_generatedAudio != null || ttsService.generatedAudio != null)
                _buildAudioPlayer(audioPlayer),
              // 状态信息
              if (ttsService.state == TtsServiceState.generating)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: ttsService.progress,
                      ),
                      const SizedBox(height: 8),
                      Text('${(ttsService.progress * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                ),
              if (ttsService.errorMessage != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      ttsService.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedParams() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Parameters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ParameterSlider(
              label: 'Temperature',
              value: _params.audioTemperature,
              min: 0.1,
              max: 2.0,
              onChanged: (value) {
                setState(() {
                  _params = _params.copyWith(audioTemperature: value);
                });
              },
            ),
            const SizedBox(height: 12),
            ParameterSlider(
              label: 'Top-K',
              value: _params.audioTopK.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              isInt: true,
              onChanged: (value) {
                setState(() {
                  _params = _params.copyWith(audioTopK: value.toInt());
                });
              },
            ),
            const SizedBox(height: 12),
            ParameterSlider(
              label: 'Top-P',
              value: _params.audioTopP,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _params = _params.copyWith(audioTopP: value);
                });
              },
            ),
            const SizedBox(height: 12),
            ParameterSlider(
              label: 'Repetition Penalty',
              value: _params.audioRepetitionPenalty,
              min: 1.0,
              max: 2.0,
              onChanged: (value) {
                setState(() {
                  _params = _params.copyWith(audioRepetitionPenalty: value);
                });
              },
            ),
            const SizedBox(height: 12),
            ParameterSlider(
              label: 'Max Frames',
              value: _params.maxNewFrames.toDouble(),
              min: 50,
              max: 1000,
              divisions: 95,
              isInt: true,
              onChanged: (value) {
                setState(() {
                  _params = _params.copyWith(maxNewFrames: value.toInt());
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(AudioPlayerService audioPlayer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () async {
                    if (_isPlaying) {
                      await audioPlayer.pause();
                    } else {
                      final audio = _generatedAudio ?? ttsService.generatedAudio;
                      if (audio != null) {
                        await audioPlayer.playBytes(audio);
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StreamBuilder<Duration>(
                    stream: audioPlayer.onPositionChanged,
                    builder: (context, snapshot) {
                      return StreamBuilder<Duration?>(
                        stream: audioPlayer.onDurationChanged,
                        builder: (context, durationSnapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = durationSnapshot.data ?? Duration.zero;
                          return Column(
                            children: [
                              LinearProgressIndicator(
                                value: duration.inMilliseconds > 0
                                    ? position.inMilliseconds / duration.inMilliseconds
                                    : 0,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position)),
                                  Text(_formatDuration(duration)),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () => _saveAudio(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAudio(
    TtsService ttsService,
    AudioPlayerService audioPlayer,
  ) async {
    if (_selectedVoice == null) return;
    
    final audio = await ttsService.generate(
      voice: _selectedVoice!,
      text: _textController.text.trim(),
      params: _params,
    );
    
    if (audio != null && mounted) {
      setState(() {
        _generatedAudio = audio;
      });
    }
  }

  Future<void> _saveAudio() async {
    // TODO: 实现文件保存功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio saved!')),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
