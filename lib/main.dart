import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/calendar_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'services/face_service.dart';
import 'services/notification_service.dart';

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

  const OneSecondApp({super.key, required this.storageService});

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
  }

  void updateTheme(int mode, Color accent) {
    setState(() {
      _themeMode = mode;
      _accentColor = accent;
    });
    widget.storageService.setThemeMode(mode);
    widget.storageService.setAccentColor(accent.value);
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
      title: 'One Second A Day',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(brightness, _accentColor),
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
