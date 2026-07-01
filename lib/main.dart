import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart'
    show BackupVault, FileVaultStore, createPlatformVaultFileApi;
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/calendar_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'services/face_service.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize storage
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  await storageService.initialize();

  // Initialize face recognition (model may not be present)
  await FaceService.instance.initialize();
  debugPrint('Face recognition available: ${FaceService.instance.isAvailable}');
  if (!FaceService.instance.isAvailable) {
    debugPrint('Face init error: ${FaceService.instance.initError}');
  }

  // Initialize notifications
  await NotificationService.instance.initialize();
  if (storageService.getReminderEnabled()) {
    await NotificationService.instance.scheduleDailyReminder(
      storageService.getReminderTime(),
    );
  }

  // Initialize visual style
  AppTheme.visualStyle = storageService.getVisualStyle();

  runApp(OneSecondApp(storageService: storageService));
}

class OneSecondApp extends StatefulWidget {
  final StorageService storageService;

  /// Builds the [BackupService] the post-first-frame freshness hook uses.
  /// Injectable so tests can point the vault at an in-memory store; the
  /// default builds the same metadata_vault the Backup & Restore screen
  /// drives (app-documents/metadata_vault on Android, OPFS on web).
  final BackupService Function()? backupServiceFactory;

  const OneSecondApp(
      {super.key, required this.storageService, this.backupServiceFactory});

  @override
  State<OneSecondApp> createState() => _OneSecondAppState();
}

class _OneSecondAppState extends State<OneSecondApp> {
  late int _themeMode;
  late Color _accentColor;
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.storageService.getThemeMode();
    _accentColor = Color(widget.storageService.getAccentColor());
    _showOnboarding = !widget.storageService.getOnboardingComplete();

    // BACKUP_RETENTION_SPEC trigger 3, post-first-frame: when the newest
    // metadata snapshot is >7 days old (or none exists), quietly vault a
    // fresh one. Best-effort by contract — maybeFreshnessSnapshot never
    // throws, so a missing vault dir or full disk can't reach the UI.
    // No nag, no badge — it just happens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = widget.backupServiceFactory?.call() ??
          BackupService(
            widget.storageService,
            vault: BackupVault(
              FileVaultStore(
                  createPlatformVaultFileApi(dirName: 'metadata_vault')),
              appId: 'punctum',
              extension: 'json',
            ),
          );
      unawaited(service.maybeFreshnessSnapshot());
    });
  }

  void updateTheme(int mode, Color accent) {
    setState(() {
      _themeMode = mode;
      _accentColor = accent;
    });
    widget.storageService.setThemeMode(mode);
    widget.storageService.setAccentColor(accent.toARGB32());
  }

  void _onVisualStyleChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _themeMode == 0
        ? Brightness.dark
        : _themeMode == 1
            ? Brightness.light
            : MediaQuery.platformBrightnessOf(context);

    return MaterialApp(
      title: 'Punctum Temporis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(brightness, _accentColor),
      builder: (context, child) {
        final inner = child ?? const SizedBox.shrink();
        if (MediaQuery.of(context).size.width <= 760) return inner;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(child: SizedBox(width: 760, child: inner)),
        );
      },
      home: _showOnboarding
          ? OnboardingScreen(
              storageService: widget.storageService,
              onComplete: () {
                setState(() => _showOnboarding = false);
              },
            )
          : CalendarScreen(
              storageService: widget.storageService,
              onThemeChanged: updateTheme,
              onVisualStyleChanged: _onVisualStyleChanged,
            ),
    );
  }
}
