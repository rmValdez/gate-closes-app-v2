import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';
import 'package:gate_closes/features/auth/data/repositories/auth_repository.dart';
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/auth/presentation/pages/onboarding_page.dart';
import 'package:gate_closes/features/boarding_pass/presentation/widgets/boarding_pass_scanner_sheet.dart';
import 'package:gate_closes/features/flight/domain/repositories/flight_repository.dart';
import 'package:gate_closes/features/flight/presentation/controllers/flight_controller.dart';
import 'package:gate_closes/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageService extends Mock implements StorageService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFlightRepository extends Mock implements FlightRepository {}

void main() {
  late MockStorageService mockStorage;
  late MockAuthRepository mockAuthRepository;
  late MockFlightRepository mockFlightRepository;

  setUp(() {
    mockStorage = MockStorageService();
    mockAuthRepository = MockAuthRepository();
    mockFlightRepository = MockFlightRepository();

    when(mockStorage.readUserModel).thenReturn(
      const UserModel(
        id: 'u1',
        email: 'test@example.com',
        name: 'Alex123.45',
        gender: 'Male',
        token: 'fake-token',
      ),
    );
    when(mockAuthRepository.refreshAuth).thenAnswer(
      (_) async => const Right(
        UserEntity(
          id: 'u1',
          email: 'test@example.com',
          name: 'Alex123.45',
          gender: 'Male',
        ),
      ),
    );
    when(() => mockStorage.setOnboardingSeen(any())).thenAnswer((_) async {});
    when(mockFlightRepository.getActiveFlightTicket).thenAnswer(
      (_) async => const Right(null),
    );
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        flightRepositoryProvider.overrideWithValue(mockFlightRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingPage(
          // Mirrors the router's injection in app_routes.dart.
          boardingPassStep: (onCompleted) => BoardingPassScannerSheet(
            completeButtonText: 'COMPLETE ONBOARDING',
            onCompleted: onCompleted,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'OnboardingPage renders welcome step with radar hero and enter button',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Welcome to'), findsOneWidget);
      expect(find.text('Enter GateCloses'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OnboardingPage advances to profile setup and boarding pass steps',
    (tester) async {
      when(
        () => mockAuthRepository.editProfile(
          username: any(named: 'username'),
          gender: any(named: 'gender'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          UserEntity(
            id: 'u1',
            email: 'test@example.com',
            name: 'Alex123.45',
            gender: 'Male',
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 100));

      // Advance from Welcome to Profile Setup
      await tester.tap(find.text('Enter GateCloses'));
      await tester.pumpAndSettle();

      expect(find.text('Complete Profile'), findsOneWidget);
      expect(find.text('USERNAME'), findsOneWidget);
      expect(find.text('SELECT GENDER IDENTITY'), findsOneWidget);

      // Advance to Boarding Pass Step
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('FLIGHT NUMBER'), findsOneWidget);
      expect(find.text('COMPLETE ONBOARDING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
