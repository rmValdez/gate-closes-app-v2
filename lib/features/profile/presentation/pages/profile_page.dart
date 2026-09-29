import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/theme_controller.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/features/flight/presentation/controllers/flight_controller.dart';
import 'package:gate_closes/features/profile/presentation/controllers/profile_controller.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/top_toast.dart';
import 'package:gate_closes/theme/tokens/radius.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Full Settings / Profile screen matching the React Native Expo app
/// structure:
/// - Profile Hero (Avatar, Username status, Gender traveler type)
/// - Flight Data section (Active flight card with edit/delete actions,
///   or Add Boarding Pass button)
/// - Account section (Edit Profile, Change Password)
/// - General section (Dark Mode, Notifications, Privacy & Anonymity,
///   Help & Support)
/// - Disconnect / Logout confirmation modal
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        unawaited(ref.read(profileControllerProvider.notifier).fetchProfile());
        unawaited(
          ref.read(flightControllerProvider.notifier).fetchActiveFlight(),
        );
      }),
    );
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(profileControllerProvider.notifier).fetchProfile(),
      ref.read(flightControllerProvider.notifier).fetchActiveFlight(),
    ]);
  }

  void _confirmDeleteFlightTicket() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: context.colors.surface,
            title: const Text('Delete Boarding Pass'),
            content: const Text(
              'This removes your flight details. You will need to add a new '
              'boarding pass to broadcast or match with other travelers.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Keep It',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final ok = await ref
                      .read(flightControllerProvider.notifier)
                      .deleteFlightTicket();
                  if (mounted) {
                    if (ok) {
                      showTopToast(context, 'Boarding pass removed');
                    } else {
                      final err = ref.read(flightControllerProvider).error;
                      showTopToast(context, err ?? 'Failed to delete ticket');
                    }
                  }
                },
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFlightCardMenu(FlightTicketEntity ticket) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bottomSheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit Boarding Pass'),
                    onTap: () {
                      Navigator.of(bottomSheetContext).pop();
                      unawaited(
                        context.push(RouteNames.addBoardingPass, extra: ticket),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Boarding Pass',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.of(bottomSheetContext).pop();
                      _confirmDeleteFlightTicket();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: context.colors.surface,
            title: const Text('Log Out'),
            content: const Text(
              'Are you sure you want to disconnect from the terminal? '
              'You will need to re-authenticate to enter.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Stay Connected',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await ref.read(authControllerProvider.notifier).logout();
                },
                child:
                    const Text('Log Out', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final authUser = ref.watch(authControllerProvider).user;
    final profileState = ref.watch(profileControllerProvider);
    final flightState = ref.watch(flightControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    final username =
        profileState.profile?.name ?? authUser?.name ?? 'Identity Pending';
    final gender = authUser?.gender;
    final travelerType = (gender != null && gender.isNotEmpty)
        ? '$gender Traveler'
        : 'Unestablished Traveler';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: colors.background,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              // Profile Hero
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: colors.accent,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colors.accentOn,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      travelerType,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Section: Flight Data
              _SectionHeader(title: 'Flight Data', color: colors.textMuted),
              const SizedBox(height: AppSpacing.xs),
              if (flightState.isLoading && flightState.activeFlight == null)
                Container(
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadius.brCard,
                  ),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else if (flightState.activeFlight != null)
                _FlightTicketCard(
                  ticket: flightState.activeFlight!,
                  onMenuPressed: () =>
                      _showFlightCardMenu(flightState.activeFlight!),
                )
              else
                _AddBoardingPassButton(
                  onTap: () => context.push(RouteNames.addBoardingPass),
                ),

              const SizedBox(height: AppSpacing.lg),

              // Section: Account
              _SectionHeader(title: 'Account', color: colors.textMuted),
              const SizedBox(height: AppSpacing.xs),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onTap: () => context.push(RouteNames.editProfile),
                  ),
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change Password',
                    onTap: () => context.push(RouteNames.changePassword),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Section: General
              _SectionHeader(title: 'General', color: colors.textMuted),
              const SizedBox(height: AppSpacing.xs),
              _SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.border.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            themeMode == ThemeMode.dark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Dark mode',
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: themeMode == ThemeMode.dark,
                          activeTrackColor: colors.accent,
                          onChanged: (isDark) =>
                              ref.read(themeModeProvider.notifier).setThemeMode(
                                    isDark ? ThemeMode.dark : ThemeMode.light,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    onTap: () => showTopToast(
                      context,
                      'Notification preferences coming soon.',
                    ),
                  ),
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.shield_outlined,
                    label: 'Privacy & Anonymity',
                    onTap: () => showTopToast(
                      context,
                      'Privacy & Anonymity settings coming soon.',
                    ),
                  ),
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () => showTopToast(
                      context,
                      'GateCloses support: help@gatecloses.internal',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sign out action
              _SettingsGroup(
                children: [
                  InkWell(
                    onTap: _showLogoutDialog,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  'GateCloses v0.1.0',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: colors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      color: colors.border.withValues(alpha: 0.3),
    );
  }
}

class _AddBoardingPassButton extends StatelessWidget {
  const _AddBoardingPassButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_rounded, color: colors.accentOn),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'ADD BOARDING PASS',
              style: TextStyle(
                color: colors.accentOn,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlightTicketCard extends StatelessWidget {
  const _FlightTicketCard({required this.ticket, required this.onMenuPressed});

  final FlightTicketEntity ticket;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final formatter = DateFormat('MMM d, yyyy · h:mm a');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLIGHT NUMBER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.flightNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onMenuPressed,
                icon: const Icon(Icons.more_vert_rounded),
                color: colors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FROM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.fromAirportName ?? ticket.fromAirport,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ticket.fromAirport,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  Icons.airplanemode_active_rounded,
                  color: colors.accent,
                  size: 22,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.toAirportName ?? ticket.toAirport,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ticket.toAirport,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: colors.border.withValues(alpha: 0.4), height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Departure',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              Text(
                formatter.format(ticket.departureDateTime),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (ticket.returnDateTime != null) ...[
                Text(
                  'Return',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                Text(
                  formatter.format(ticket.returnDateTime!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ] else ...[
                Text(
                  'One-way',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
