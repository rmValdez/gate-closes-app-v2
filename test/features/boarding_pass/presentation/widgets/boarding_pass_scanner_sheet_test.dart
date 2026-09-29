import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/boarding_pass/presentation/widgets/boarding_pass_camera_view.dart';
import 'package:gate_closes/features/boarding_pass/presentation/widgets/boarding_pass_scanner_sheet.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/theme/app_theme.dart';

void main() {
  Widget buildSubject({FlightTicketEntity? initialTicket}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BoardingPassScannerSheet(initialTicket: initialTicket),
        ),
      ),
    );
  }

  testWidgets('starts in camera mode for a new boarding pass', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byType(BoardingPassCameraView), findsOneWidget);
    expect(find.text('Paste boarding pass text'), findsNothing);
  });

  testWidgets('switching to Manual closes the camera', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();

    expect(find.byType(BoardingPassCameraView), findsNothing);
    expect(find.text('Paste boarding pass text'), findsOneWidget);
  });

  testWidgets('editing an existing ticket starts in manual mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        initialTicket: FlightTicketEntity(
          id: 't1',
          userId: 'u1',
          flightNumber: 'PR1847',
          fromAirport: 'MNL',
          toAirport: 'CEB',
          departureDateTime: DateTime(2026, 10, 2, 6, 35),
        ),
      ),
    );

    expect(find.byType(BoardingPassCameraView), findsNothing);
    expect(find.text('PR1847'), findsOneWidget);
  });
}
