import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'package:openhearth_design/openhearth_design.dart' show OhPage;

class OnboardingScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onComplete;

  /// Schedules the daily reminder when the person chooses it on the last
  /// page (a seam so tests stay off the platform plugin).
  final Future<void> Function(TimeOfDay time)? scheduleReminder;

  const OnboardingScreen({
    super.key,
    required this.storageService,
    required this.onComplete,
    this.scheduleReminder,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  /// The reminder is offered on the last page, never switched on for you.
  bool _remind = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    if (_remind) {
      await widget.storageService.setReminderEnabled(true);
      final time = widget.storageService.getReminderTime();
      await (widget.scheduleReminder ??
          NotificationService.instance.scheduleDailyReminder)(time);
    }
    await widget.storageService.setOnboardingComplete(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: OhPage(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _complete,
                  child: Text(
                    'SKIP',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: AppTheme.dimInk(theme),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  // The three facts that matter when something goes wrong
                  // lead (audit finding 8, ruled): where clips live, that
                  // nothing uploads, and that missing days is normal.
                  _OnboardingPage(
                    icon: Icons.phone_android,
                    title: 'ONE SECOND A DAY, ON THIS PHONE',
                    subtitle: 'Each day’s second is a file on this phone. '
                        'Nothing is uploaded, and there is no account. '
                        'Missing a day is normal: the calendar just leaves '
                        'it blank.',
                    accentColor: theme.colorScheme.primary,
                  ),
                  _OnboardingPage(
                    icon: Icons.calendar_today,
                    title: 'EVERY DAY COUNTS',
                    subtitle: 'Watch your calendar fill up day by day. '
                        'Build streaks, tag moments, and '
                        'never lose track of your memories.',
                    accentColor: theme.colorScheme.primary,
                  ),
                  _OnboardingPage(
                    icon: Icons.movie_creation,
                    title: 'YOUR YEAR IN MOTION',
                    subtitle: 'Compile your seconds into videos. '
                        'One month, one season, one whole year: '
                        'all your moments, seamlessly joined.',
                    accentColor: theme.colorScheme.primary,
                    footer: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _remind,
                      onChanged: (v) => setState(() => _remind = v),
                      title: Text(
                        'Remind me each day at 8:00 PM',
                        style: AppTheme.monoFont(
                            fontSize: 14, color: theme.colorScheme.onSurface),
                      ),
                      subtitle: Text(
                        'You can change the time or turn it off in Settings.',
                        textAlign: TextAlign.start,
                        style: AppTheme.monoFont(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.75)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final isActive = index == _currentPage;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  );
                }),
              ),
            ),

            // Action button
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _next,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      border: Border.all(
                          color: theme.colorScheme.primary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _currentPage == 2 ? 'GET STARTED' : 'NEXT',
                        style: AppTheme.monoFont(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget? footer;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Scrolls when the words outgrow the page (large text on a small
    // phone); centred when they fit.
    return Center(
     child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon area
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: accentColor, width: 3),
            ),
            child: Icon(
              icon,
              size: 56,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: AppTheme.pixelFont(
              fontSize: 16,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: AppTheme.monoFont(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            // A paragraph reads from a straight left edge; it wraps to the
            // width instead of at typed line breaks.
            textAlign: TextAlign.start,
          ),
          if (footer != null) ...[
            const SizedBox(height: 24),
            footer!,
          ],
        ],
      ),
     ),
    );
  }
}
