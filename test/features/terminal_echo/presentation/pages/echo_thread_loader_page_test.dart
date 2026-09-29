import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/echo_thread_loader_page.dart';
import 'package:gate_closes/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockTerminalEchoRepository extends Mock
    implements TerminalEchoRepository {}

void main() {
  late MockTerminalEchoRepository repo;

  setUp(() => repo = MockTerminalEchoRepository());

  Widget buildSubject() => ProviderScope(
        overrides: [terminalEchoRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EchoThreadLoaderPage(echoId: 'e1'),
        ),
      );

  testWidgets('fetches the echo by id when none was passed in', (
    tester,
  ) async {
    when(() => repo.getEchoById('e1')).thenAnswer(
      (_) async => const Left(ServerFailure('Echo not found')),
    );

    await tester.pumpWidget(buildSubject());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    verify(() => repo.getEchoById('e1')).called(1);
    expect(find.text("Couldn't open this echo"), findsOneWidget);
    expect(find.text('Echo not found'), findsOneWidget);
  });
}
