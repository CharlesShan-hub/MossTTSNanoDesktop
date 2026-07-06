import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../services/tts_service.dart';
import '../services/voice_manager.dart';
import '../services/audio_player_service.dart';
import 'theme_provider.dart';

class AppProviders {
  static List<SingleChildWidget> get providers {
    return [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => VoiceManager()),
      ChangeNotifierProvider(create: (_) => TtsService()),
      Provider(create: (_) => AudioPlayerService()),
    ];
  }
}
