import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';
import 'package:gate_closes/shared/widgets/emoji_reaction_picker.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/shared/widgets/waveform_player.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

/// Terminal Echo feed — ephemeral spatial posts anchored to the user's
/// current airport. Airport is resolved via `AirportController.
/// detectAirport()` (Phase 6); the feed itself via `TerminalEchoController.
/// loadFeed(iata)`.
///
/// Not yet built (tracked in `FEATURE_PARITY_ROADMAP.md`): browsing a
/// *different* airport's feed via search, and the reply-thread view — both
/// need work beyond this page.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    await ref.read(airportControllerProvider.notifier).detectAirport();
    final airport = ref.read(airportControllerProvider).airport;
    if (airport != null) {
      await ref
          .read(terminalEchoControllerProvider.notifier)
          .loadFeed(airport.iata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final airportState = ref.watch(airportControllerProvider);
    final echoState = ref.watch(terminalEchoControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          airportState.airport != null
              ? 'Terminal Echo — ${airportState.airport!.iata}'
              : 'Terminal Echo',
          style:
              TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: colors.textPrimary),
            onPressed: () => context.push(RouteNames.airportSearch),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.accent,
        foregroundColor: colors.accentOn,
        onPressed: () => context.push(RouteNames.createEcho),
        child: const Icon(Icons.mic_rounded),
      ),
      body: _buildBody(colors, airportState, echoState),
    );
  }

  Widget _buildBody(
    GateColors colors,
    AirportState airportState,
    TerminalEchoState echoState,
  ) {
    if (airportState.isDetecting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (airportState.airport == null) {
      return AppStateView(
        kind: AppStateKind.empty,
        title: 'No airport detected',
        message: airportState.error ??
            "We couldn't find an airport near you. Terminal Echo is scoped "
                'to a specific airport.',
        actionLabel: 'Retry',
        onAction: () => unawaited(_init()),
      );
    }

    if (echoState.isLoading && echoState.echoes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (echoState.error != null && echoState.echoes.isEmpty) {
      return AppStateView(
        kind: AppStateKind.error,
        title: 'Could not load the feed',
        message: echoState.error,
        actionLabel: 'Retry',
        onAction: () => unawaited(_init()),
      );
    }

    if (echoState.echoes.isEmpty) {
      return const AppStateView(
        kind: AppStateKind.empty,
        title: 'No echoes yet',
        message: 'Be the first to post here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(terminalEchoControllerProvider.notifier)
          .loadFeed(airportState.airport!.iata),
      child: ListView.separated(
        padding: AppSpacing.edgeInsetsMd,
        itemCount: echoState.echoes.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) =>
            _EchoTile(echo: echoState.echoes[index]),
      ),
    );
  }
}

class _EchoTile extends ConsumerWidget {
  const _EchoTile({required this.echo});

  final TerminalEchoEntity echo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final name = echo.senderUsername ?? 'Unknown traveler';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: () => context.push(RouteNames.echoThreadFor(echo.id), extra: echo),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.accent.withValues(alpha: 0.18),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _timeAgo(echo.createdAt),
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (echo.textMessage.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                echo.textMessage,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ],
            if (echo.isVoiceMemo) ...[
              const SizedBox(height: AppSpacing.sm),
              WaveformPlayer(
                audioUrl: echo.fileUrl!,
                waveformData: echo.waveformData,
                durationSeconds: echo.audioDuration,
                onListenThresholdReached: () => unawaited(
                  ref
                      .read(terminalEchoControllerProvider.notifier)
                      .incrementListen(echo.id),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                GestureDetector(
                  onTap: () => unawaited(_react(context, ref)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 14,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${echo.totalReactions}',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.hearing_rounded, size: 14, color: colors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${echo.countListens}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _react(BuildContext context, WidgetRef ref) async {
    final reaction = await EmojiReactionPicker.show(context);
    if (reaction == null) return;
    await ref.read(terminalEchoControllerProvider.notifier).react(
          echoId: echo.id,
          reaction: EchoReactionType.values.byName(reaction),
        );
  }

  String _timeAgo(DateTime date) {
    final mins = DateTime.now().difference(date).inMinutes;
    if (mins < 1) return 'now';
    if (mins < 60) return '${mins}m ago';
    final hrs = mins ~/ 60;
    if (hrs < 24) return '${hrs}h ago';
    return '${hrs ~/ 24}d ago';
  }
}
