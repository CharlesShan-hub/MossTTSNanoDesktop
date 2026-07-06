import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/voice.dart';
import '../../services/voice_manager.dart';
import '../../services/audio_player_service.dart';
import '../widgets/voice_card.dart';

class VoicesPage extends StatefulWidget {
  const VoicesPage({super.key});

  @override
  State<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends State<VoicesPage> {
  String _searchQuery = '';
  String? _filterLanguage;
  bool _showHidden = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final voiceManager = context.watch<VoiceManager>();
    final audioPlayer = context.read<AudioPlayerService>();

    List<Voice> displayVoices = _showHidden
        ? voiceManager.allVoices
        : voiceManager.voices;

    // 搜索和过滤
    if (_searchQuery.isNotEmpty) {
      displayVoices = displayVoices
          .where((v) =>
              v.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (v.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
          .toList();
    }

    if (_filterLanguage != null && _filterLanguage!.isNotEmpty) {
      displayVoices = displayVoices
          .where((v) => v.language == _filterLanguage)
          .toList();
    }

    final languages = voiceManager.allVoices
        .map((v) => v.language)
        .whereType<String>()
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voices'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'show_hidden',
                checked: _showHidden,
                child: const Text('Show Hidden Voices'),
              ),
            ],
            onSelected: (value) {
              if (value == 'show_hidden') {
                setState(() {
                  _showHidden = !_showHidden;
                });
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 搜索和过滤
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search voices...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (languages.isNotEmpty)
                    Row(
                      children: [
                        const Text('Filter:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _filterLanguage,
                            isDense: true,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Languages'),
                              ),
                              ...languages.map((lang) {
                                return DropdownMenuItem(
                                  value: lang,
                                  child: Text(lang),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filterLanguage = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // 列表
            Expanded(
              child: voiceManager.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayVoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.voice_chat_outlined,
                                size: 80,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                voiceManager.voices.isEmpty
                                    ? 'No voices yet'
                                    : 'No matching voices',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                voiceManager.voices.isEmpty
                                    ? 'Tap the + button to add a voice'
                                    : 'Try a different search term',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: displayVoices.length,
                          itemBuilder: (context, index) {
                            return VoiceCard(
                              voice: displayVoices[index],
                              onPlay: () => _playVoice(displayVoices[index], audioPlayer),
                              onEdit: () => _editVoice(displayVoices[index]),
                              onDelete: () => _deleteVoice(displayVoices[index]),
                              onToggleHidden: () => _toggleHidden(displayVoices[index]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _importVoice(voiceManager),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _importVoice(VoiceManager voiceManager) async {
    await voiceManager.importVoice();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice imported!')),
      );
    }
  }

  Future<void> _playVoice(Voice voice, AudioPlayerService audioPlayer) async {
    try {
      await audioPlayer.playPath(voice.audioPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play voice: $e')),
        );
      }
    }
  }

  Future<void> _editVoice(Voice voice) async {
    // TODO: 实现编辑功能
  }

  Future<void> _deleteVoice(Voice voice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voice?'),
        content: Text('Are you sure you want to delete "${voice.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final voiceManager = context.read<VoiceManager>();
      await voiceManager.deleteVoice(voice);
    }
  }

  Future<void> _toggleHidden(Voice voice) async {
    final voiceManager = context.read<VoiceManager>();
    await voiceManager.toggleVoiceHidden(voice);
  }
}
