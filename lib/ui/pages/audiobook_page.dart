import 'package:flutter/material.dart';

class AudiobookPage extends StatefulWidget {
  const AudiobookPage({super.key});

  @override
  State<AudiobookPage> createState() => _AudiobookPageState();
}

class _AudiobookPageState extends State<AudiobookPage> {
  List<Map<String, dynamic>> chapters = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audiobook'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _importChapters,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Import Chapters'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: chapters.isEmpty ? null : _generateAll,
                      icon: const Icon(Icons.mic),
                      label: const Text('Generate All'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: chapters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 80,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No chapters imported',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap "Import Chapters" to add text files',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          return _ChapterCard(
                            title: chapter['title'],
                            status: chapter['status'],
                            progress: chapter['progress'],
                            onTap: () => _playChapter(index),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importChapters() async {
    // TODO: 实现文件选择
    setState(() {
      chapters = [
        {
          'title': 'Chapter 1 - Introduction',
          'status': 'waiting',
          'progress': 0.0,
        },
        {
          'title': 'Chapter 2 - Getting Started',
          'status': 'waiting',
          'progress': 0.0,
        },
      ];
    });
  }

  Future<void> _generateAll() async {
    // TODO: 实现批量生成
  }

  void _playChapter(int index) {
    // TODO: 实现章节播放
  }
}

class _ChapterCard extends StatelessWidget {
  final String title;
  final String status;
  final double progress;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.title,
    required this.status,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _buildLeadingIcon(),
        title: Text(title),
        subtitle: status == 'generating'
            ? LinearProgressIndicator(value: progress)
            : null,
        trailing: status == 'completed'
            ? IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: onTap,
              )
            : null,
      ),
    );
  }

  Widget _buildLeadingIcon() {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'generating':
        return const CircularProgressIndicator();
      case 'error':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.circle_outlined);
    }
  }
}
