import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/core/utils/validators.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/ambient_background.dart';
import 'package:gate_closes/shared/widgets/buttons.dart';
import 'package:gate_closes/shared/widgets/modern_text_field.dart';
import 'package:gate_closes/shared/widgets/top_toast.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

/// Full onboarding flow matching React Native Expo:
/// Step 0: Welcome Screen (Animated radar pulse hero, logo, "Enter GateCloses")
/// Step 1: Profile Setup (Username + Gender selector)
/// Step 2: Boarding Pass Capture — supplied by [boardingPassStep].
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({required this.boardingPassStep, super.key});

  /// Builds the boarding-pass step; call `onCompleted` when the user is done.
  /// Injected by the router (the composition root) so `auth` doesn't import
  /// the `boarding_pass` feature.
  final Widget Function(VoidCallback onCompleted) boardingPassStep;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _currentStep = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      unawaited(_completeOnboarding());
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      unawaited(
        _pageController.previousPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId != null) {
      await ref.read(storageServiceProvider).setOnboardingSeen(userId);
    }
    if (mounted) {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: colors.textPrimary,
                          size: 20,
                        ),
                        onPressed: _previousStep,
                      )
                    else
                      const SizedBox(width: 48, height: 48),
                    // Progress dots indicator
                    Row(
                      children: List.generate(3, (index) {
                        final isActive = index == _currentStep;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? colors.accent
                                : colors.border.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    // Skip button on steps 1 and 2
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48, height: 48),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (step) => setState(() => _currentStep = step),
                  children: [
                    _WelcomeStep(onEnter: _nextStep),
                    _ProfileSetupStep(onCompleted: _nextStep),
                    widget.boardingPassStep(_completeOnboarding),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 0: Welcome Step with Animated Radar Pulse
// ---------------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const Spacer(),
          // Radar Pulse Hero Animation
          const _RadarPulseHero(size: 260),
          const SizedBox(height: AppSpacing.xl),
          // Title & Subtitle
          Text(
            'Welcome to\nGateCloses',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              height: 1.15,
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your journey into shared solitude begins here.\n'
            "Let's establish your traveler identity.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const Spacer(),
          // Primary CTA
          PrimaryButton(
            label: 'Enter GateCloses',
            onPressed: onEnter,
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _RadarPulseHero extends StatefulWidget {
  const _RadarPulseHero({required this.size});

  final double size;

  @override
  State<_RadarPulseHero> createState() => _RadarPulseHeroState();
}

class _RadarPulseHeroState extends State<_RadarPulseHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RadarPulsePainter(
              progress: _controller.value,
              accentColor: colors.accent,
            ),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.45),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  color: colors.accentOn,
                  size: 34,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  _RadarPulsePainter({required this.progress, required this.accentColor});

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Static boundary ring
    final staticPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxRadius * 0.85, staticPaint);

    // 3 expanding staggered pulses
    for (var i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.333)) % 1.0;
      final radius = 36 + (maxRadius - 36) * ringProgress;
      final opacity = math.sin(ringProgress * math.pi) * 0.4;

      final ringPaint = Paint()
        ..color = accentColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor;
  }
}

// ---------------------------------------------------------------------------
// Step 1: Profile Setup Step (Username + Gender)
// ---------------------------------------------------------------------------

class _ProfileSetupStep extends ConsumerStatefulWidget {
  const _ProfileSetupStep({required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  ConsumerState<_ProfileSetupStep> createState() => _ProfileSetupStepState();
}

class _ProfileSetupStepState extends ConsumerState<_ProfileSetupStep> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  String? _gender = 'Male';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      if (user.name.isNotEmpty) {
        _usernameController.text = user.name;
      }
      if (user.gender != null && user.gender!.isNotEmpty) {
        _gender = user.gender;
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _gender!.isEmpty) {
      showTopToast(context, 'Please select your gender identity');
      return;
    }

    setState(() => _isSaving = true);

    final ok = await ref.read(authControllerProvider.notifier).editProfile(
          username: _usernameController.text.trim(),
          gender: _gender,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      widget.onCompleted();
    } else {
      final err = ref.read(authControllerProvider).error;
      showTopToast(context, err ?? 'Failed to update profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Complete Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick a unique handle and gender identity to '
              'establish your presence.',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ModernTextField(
              label: 'USERNAME',
              hint: 'traveler_jane',
              controller: _usernameController,
              prefixIcon: Icons.badge_outlined,
              validator: Validators.username,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'SELECT GENDER IDENTITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final option in const ['Male', 'Female', 'Other']) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _gender == option
                              ? colors.accent.withValues(alpha: 0.16)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _gender == option
                                ? colors.accent
                                : colors.border,
                            width: _gender == option ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            color: _gender == option
                                ? colors.accent
                                : colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (option != 'Other') const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'Continue',
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
