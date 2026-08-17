import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'walks/walk_home_screen.dart';
import 'walks/walk_recording_controller.dart';
import 'walks/walk_repository.dart';

class PathgrainApp extends StatelessWidget {
  const PathgrainApp({
    super.key,
    required this.controller,
    required this.repository,
  });

  final WalkRecordingController controller;
  final WalkRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF386A42)),
        useMaterial3: true,
      ),
      home: WalkHomeScreen(controller: controller, repository: repository),
    );
  }
}
