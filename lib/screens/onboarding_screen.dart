import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.storageService,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

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
    await widget.storageService.setOnboardingComplete(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
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
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                  _OnboardingPage(
                    icon: Icons.hourglass_bottom,
                    title: 'FREEZE ONE SECOND',
                    subtitle: 'Capture just one second of video every day.\n'
                        'A tiny habit that builds into something\n'
                        'extraordinary over time.',
                    accentColor: theme.colorScheme.primary,
                  ),
                  _OnboardingPage(
                    icon: Icons.calendar_today,
                    title: 'EVERY DAY COUNTS',
                    subtitle: 'Watch your calendar fill up day by day.\n'
                        'Build streaks, tag moments, and\n'
                        'never lose track of your memories.',
                    accentColor: theme.colorScheme.primary,
                  ),
                  _OnboardingPage(
                    icon: Icons.movie_creation,
                    title: 'YOUR YEAR IN MOTION',
                    subtitle: 'Compile your seconds into videos.\n'
                        'One month, one season, one whole year —\n'
                        'all your moments, seamlessly joined.',
                    accentColor: theme.colorScheme.primary,
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
                          : theme.colorScheme.primary.withOpacity(0.3),
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

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
