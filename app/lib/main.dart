import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/prefs.dart';
import 'data/repository.dart';
import 'screens/shelf_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(TaintedViewApp(
    repo: BookRepository(),
    settings: ReaderSettings(prefs),
    progress: ProgressStore(prefs),
  ));
}

class TaintedViewApp extends StatelessWidget {
  const TaintedViewApp({
    super.key,
    required this.repo,
    required this.settings,
    required this.progress,
  });

  final BookRepository repo;
  final ReaderSettings settings;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7A5C3E);
    return AppScope(
      repo: repo,
      settings: settings,
      progress: progress,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: '不净观',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
          darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
          themeMode: switch (settings.theme) {
            ReaderTheme.system => ThemeMode.system,
            ReaderTheme.dark => ThemeMode.dark,
            _ => ThemeMode.light,
          },
          home: const ShelfScreen(),
        ),
      ),
    );
  }
}
