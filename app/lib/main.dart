import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/media.dart';
import 'data/prefs.dart';
import 'data/repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final support = await getApplicationSupportDirectory();
  runApp(TaintedViewApp(
    repo: BookRepository(),
    settings: ReaderSettings(prefs),
    progress: ProgressStore(prefs),
    media: MediaStore(prefs, root: Directory('${support.path}/media')),
  ));
}

class TaintedViewApp extends StatelessWidget {
  const TaintedViewApp({
    super.key,
    required this.repo,
    required this.settings,
    required this.progress,
    required this.media,
  });

  final BookRepository repo;
  final ReaderSettings settings;
  final ProgressStore progress;
  final MediaStore media;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7A5C3E);
    return AppScope(
      repo: repo,
      settings: settings,
      progress: progress,
      media: media,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'TaintedView',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
          darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
          themeMode: switch (settings.theme) {
            ReaderTheme.system => ThemeMode.system,
            ReaderTheme.dark => ThemeMode.dark,
            _ => ThemeMode.light,
          },
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
