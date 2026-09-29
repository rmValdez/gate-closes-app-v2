import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/echo_thread_page.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';

/// Entry point for `/feed/thread/:echoId`.
///
/// In-app navigation passes the already-loaded echo ([initialEcho]) and the
/// thread opens instantly. Anything that only knows the id — a map pin, a
/// deep link, a restored navigation stack — gets it fetched here first.
class EchoThreadLoaderPage extends ConsumerStatefulWidget {
  const EchoThreadLoaderPage({
    required this.echoId,
    this.initialEcho,
    super.key,
  });

  final String echoId;
  final TerminalEchoEntity? initialEcho;

  @override
  ConsumerState<EchoThreadLoaderPage> createState() =>
      _EchoThreadLoaderPageState();
}

class _EchoThreadLoaderPageState extends ConsumerState<EchoThreadLoaderPage> {
  TerminalEchoEntity? _echo;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEcho;
    if (initial != null && initial.id == widget.echoId) {
      _echo = initial;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final result = await ref
        .read(terminalEchoRepositoryProvider)
        .getEchoById(widget.echoId);
    if (!mounted) return;
    setState(() {
      result.fold(
        (failure) => _error = failure.message,
        (echo) => _echo = echo,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final echo = _echo;
    if (echo != null) return EchoThreadPage(echo: echo);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(backgroundColor: context.colors.background),
      body: _error == null
          ? const Center(child: CircularProgressIndicator())
          : AppStateView(
              kind: AppStateKind.error,
              title: "Couldn't open this echo",
              message: _error,
              actionLabel: 'Retry',
              onAction: () => unawaited(_load()),
            ),
    );
  }
}
