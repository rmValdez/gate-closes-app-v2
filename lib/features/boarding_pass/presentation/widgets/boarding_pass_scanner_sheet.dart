import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parse_confidence.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/enums/boarding_pass_source.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/boarding_pass_coordinator.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/flight_normalizer.dart';
import 'package:gate_closes/features/boarding_pass/presentation/debug/ticket_fixture_capture.dart';
import 'package:gate_closes/features/boarding_pass/presentation/providers/ticket_extraction_providers.dart';
import 'package:gate_closes/features/boarding_pass/presentation/widgets/boarding_pass_camera_view.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/features/flight/presentation/controllers/flight_controller.dart';
import 'package:gate_closes/shared/widgets/airport_picker_sheet.dart';
import 'package:gate_closes/shared/widgets/app_button.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/shared/widgets/modern_text_field.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// How the user is supplying flight details.
enum BoardingPassEntryMode { camera, manual }

/// Boarding pass entry sheet with two input modes: live camera barcode scan
/// and manual entry (typed fields, or pasted boarding-pass text). Both feed
/// the same confirmation form.
/// Matches `BoardingPassForm.tsx` from the Expo React Native app.
class BoardingPassScannerSheet extends ConsumerStatefulWidget {
  const BoardingPassScannerSheet({
    this.initialTicket,
    this.onCompleted,
    this.completeButtonText = 'PROCEED TO TERMINAL ECHO',
    super.key,
  });

  final FlightTicketEntity? initialTicket;
  final VoidCallback? onCompleted;
  final String completeButtonText;

  @override
  ConsumerState<BoardingPassScannerSheet> createState() =>
      _BoardingPassScannerSheetState();
}

class _BoardingPassScannerSheetState
    extends ConsumerState<BoardingPassScannerSheet> {
  final _flightNumberController = TextEditingController();
  final _manualOcrController = TextEditingController();
  final _seatController = TextEditingController();
  final _gateController = TextEditingController();

  late final BoardingPassCoordinator _coordinator;
  ParsedFlight? _parsedCandidate;

  // Generated once per sheet instance (not per submit attempt), so retrying
  // a failed submission reuses the same key — the server's idempotency check
  // (POST /flight-ticket) relies on the key staying stable across retries of
  // the *same* attempt. Reopening the sheet for a new attempt yields a new
  // State instance and therefore a new key. Only consumed on the create path
  // (FlightController.saveFlightTicket ignores it when editing).
  final String _idempotencyKey = const Uuid().v4();

  AirportEntity? _fromAirport;
  AirportEntity? _toAirport;
  DateTime? _departureDateTime;

  /// Date read from a boarding pass that carried no departure time (BCBP
  /// never does). It only pre-fills the picker: submitting a parsed midnight
  /// as the departure would skew every dwell-window calculation.
  DateTime? _parsedDepartureDate;
  DateTime? _returnDateTime;

  late BoardingPassEntryMode _mode;

  /// A camera scan was parsed; the preview is closed until "Scan again".
  bool _scanAccepted = false;

  /// Shown under the preview when a scanned code doesn't parse — the general
  /// error line sits by the submit button, off-screen while scanning.
  String? _scanMessage;

  /// A ticket photo is being picked/read. The live preview is unmounted
  /// meanwhile so the system camera can take over.
  bool _readingPhoto = false;

  /// Debug builds only: raw input of the last extraction, for the
  /// "Copy test fixture" tool (STEP 21). Always null in release.
  TicketCapture? _debugCapture;

  void _recordCapture(
    TicketCaptureSource source,
    String raw,
    ParsedFlight? parsed,
  ) {
    if (kDebugMode) _debugCapture = TicketCapture(source, raw, parsed);
  }

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showOcrInput = false;

  @override
  void initState() {
    super.initState();
    // Editing an existing ticket starts on the form, not the camera.
    _mode = widget.initialTicket != null
        ? BoardingPassEntryMode.manual
        : BoardingPassEntryMode.camera;
    _coordinator =
        BoardingPassCoordinator(validator: LocalAirportRegistry.instance);

    if (widget.initialTicket != null) {
      final t = widget.initialTicket!;
      _flightNumberController.text = t.flightNumber;
      _fromAirport = AirportEntity(
        id: '',
        iata: t.fromAirport,
        name: t.fromAirportName ?? t.fromAirport,
      );
      _toAirport = AirportEntity(
        id: '',
        iata: t.toAirport,
        name: t.toAirportName ?? t.toAirport,
      );
      _departureDateTime = t.departureDateTime;
      _returnDateTime = t.returnDateTime;
      if (t.seat != null) _seatController.text = t.seat!;
      if (t.gate != null) _gateController.text = t.gate!;
    }
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _manualOcrController.dispose();
    _seatController.dispose();
    _gateController.dispose();
    super.dispose();
  }

  void _applyParsedFlight(ParsedFlight flight) {
    _parsedCandidate = flight;
    if (flight.flightNumber.isNotEmpty) {
      _flightNumberController.text = flight.flightNumber;
    }
    if (flight.originIata.isNotEmpty) {
      final ref =
          LocalAirportRegistry.instance.resolveAirport(flight.originIata);
      _fromAirport = AirportEntity(
        id: '',
        iata: flight.originIata,
        name: ref?.name.isNotEmpty == true ? ref!.name : flight.originIata,
      );
    }
    if (flight.destinationIata.isNotEmpty) {
      final ref =
          LocalAirportRegistry.instance.resolveAirport(flight.destinationIata);
      _toAirport = AirportEntity(
        id: '',
        iata: flight.destinationIata,
        name: ref?.name.isNotEmpty == true ? ref!.name : flight.destinationIata,
      );
    }
    final parsedDeparture = flight.departureDateTime;
    if (parsedDeparture != null) {
      if (flight.confidence.departureTime > 0) {
        _departureDateTime = parsedDeparture;
      } else {
        // Date only — make the user confirm the time.
        _parsedDepartureDate = DateTime(
          parsedDeparture.year,
          parsedDeparture.month,
          parsedDeparture.day,
          12,
        );
        _departureDateTime = null;
      }
    }
    if (flight.seat != null && flight.seat!.isNotEmpty) {
      _seatController.text = flight.seat!;
    }
    if (flight.gate != null && flight.gate!.isNotEmpty) {
      _gateController.text = flight.gate!;
    }
    setState(() {
      _errorMessage = null;
      _showOcrInput = false;
    });
  }

  void _handleRawInput(String text) {
    final result = _coordinator.parseRaw(text);
    _recordCapture(TicketCaptureSource.pastedText, text, result);
    if (result == null || !result.hasRequiredRoute) {
      setState(() {
        _errorMessage =
            'Could not reliably parse flight details. Please enter manually.';
      });
      return;
    }
    _applyParsedFlight(result);
  }

  void _handleScan(String raw) {
    final result = _coordinator.parseRaw(raw);
    _recordCapture(TicketCaptureSource.liveBarcode, raw, result);
    if (result == null || !result.hasRequiredRoute) {
      // Keep the camera running — likely a non-boarding-pass code in frame.
      setState(
        () => _scanMessage =
            "That code isn't a readable boarding pass. Try the barcode on "
                'your pass, or enter the flight manually.',
      );
      return;
    }
    _scanAccepted = true;
    _scanMessage = null;
    _applyParsedFlight(result);
  }

  /// Fallback for tickets without a usable barcode: photo (or screenshot)
  /// → barcode-in-image → OCR, via [ticketExtractionPipelineProvider]. The
  /// result lands in the same confirmation form as a live scan.
  Future<void> _scanFromPhoto(ImageSource source) async {
    setState(() {
      _readingPhoto = true;
      _scanMessage = null;
    });
    String? path;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Enough resolution for text recognition without huge files.
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (picked == null || !mounted) return;
      path = picked.path;

      final result =
          await ref.read(ticketExtractionPipelineProvider).extract(path);
      final recorder = ref.read(ticketCaptureRecorderProvider);
      if (recorder != null) {
        final fromBarcode = result?.source == BoardingPassSource.bcbp;
        _recordCapture(
          fromBarcode
              ? TicketCaptureSource.photoBarcode
              : TicketCaptureSource.photoText,
          (fromBarcode ? recorder.lastBarcode : recorder.lastText) ?? '',
          result,
        );
      }
      if (!mounted) return;
      if (result == null) {
        setState(
          () => _scanMessage = "Couldn't find flight details in that photo. "
              'Try a sharp, well-lit photo of the whole ticket, or enter it '
              'manually.',
        );
        return;
      }
      _scanAccepted = true;
      _applyParsedFlight(result);
    } on Object catch (_) {
      if (mounted) {
        setState(
          () => _scanMessage =
              "Couldn't read that photo. Try again, or enter the flight "
                  'manually.',
        );
      }
    } finally {
      // The picker hands us a private copy; the ticket image isn't kept.
      if (path != null) {
        unawaited(File(path).delete().then((_) {}, onError: (_) {}));
      }
      if (mounted) setState(() => _readingPhoto = false);
    }
  }

  String _acceptedLabel() {
    final flight = _parsedCandidate;
    if (flight == null || flight.source != BoardingPassSource.ocr) {
      return 'Boarding pass scanned — review the details below.';
    }
    return flight.hasRequiredRoute
        ? 'Read from your ticket photo — check every field below.'
        : "Some details couldn't be read — fill in the rest below.";
  }

  /// Debug-only: copies a redacted fixture of the last extraction, with the
  /// form's current (user-corrected) values as ground truth. Save it under
  /// test/fixtures/tickets/ — see the README there.
  Future<void> _copyDebugFixture() async {
    final capture = _debugCapture;
    if (capture == null) return;
    final departure = _departureDateTime;
    final barcodeSource = capture.source == TicketCaptureSource.liveBarcode ||
        capture.source == TicketCaptureSource.photoBarcode;
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final json = buildTicketFixtureJson(
      capture: capture,
      capturedOn: DateTime.now(),
      expected: {
        'flightNumber': FlightNormalizer.normalizeFlightNumber(
          _flightNumberController.text,
        ),
        'origin': _fromAirport?.iata,
        'destination': _toAirport?.iata,
        'departureDate': departure?.toIso8601String().substring(0, 10),
        // Boarding-pass barcodes carry no time; only check printed times.
        'departureTime': barcodeSource || departure == null
            ? null
            : '${departure.hour.toString().padLeft(2, '0')}:'
                '${departure.minute.toString().padLeft(2, '0')}',
        'seat': text(_seatController),
        'gate': text(_gateController),
      },
    );
    await Clipboard.setData(ClipboardData(text: json));
    debugPrint('--- ticket fixture ---\n$json');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Fixture copied. Check it for personal data before committing.',
        ),
      ),
    );
  }

  void _setMode(BoardingPassEntryMode mode) {
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _scanMessage = null;
      _showOcrInput = false;
      if (mode == BoardingPassEntryMode.camera) _scanAccepted = false;
    });
  }

  Future<void> _pickAirport(bool isFrom) async {
    final selected = await AirportPickerSheet.show(
      context,
      title: isFrom ? 'Select Departure Airport' : 'Select Arrival Airport',
      excludeCode: isFrom ? _toAirport?.iata : _fromAirport?.iata,
    );
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromAirport = selected;
        } else {
          _toAirport = selected;
        }
      });
    }
  }

  Future<void> _pickDateTime(bool isDeparture) async {
    final initialDate = isDeparture
        ? (_departureDateTime ??
            _parsedDepartureDate ??
            DateTime.now().add(const Duration(hours: 3)))
        : (_returnDateTime ??
            (_departureDateTime ?? DateTime.now())
                .add(const Duration(days: 7)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isDeparture) {
        _departureDateTime = combined;
        if (_returnDateTime != null && _returnDateTime!.isBefore(combined)) {
          _returnDateTime = combined.add(const Duration(days: 7));
        }
      } else {
        _returnDateTime = combined;
      }
    });
  }

  Future<void> _handleSubmit() async {
    final flightNum = _flightNumberController.text.trim();
    if (flightNum.isEmpty) {
      setState(() => _errorMessage = 'Flight number is required.');
      return;
    }
    if (_fromAirport == null) {
      setState(() => _errorMessage = 'Please select a departure airport.');
      return;
    }
    if (_toAirport == null) {
      setState(() => _errorMessage = 'Please select an arrival airport.');
      return;
    }
    if (_fromAirport!.iata == _toAirport!.iata) {
      setState(
        () => _errorMessage =
            'Origin and destination airports must be different.',
      );
      return;
    }
    if (_departureDateTime == null) {
      setState(
        () => _errorMessage = _parsedDepartureDate != null
            ? 'Your boarding pass has no departure time — please set it.'
            : 'Please specify departure date/time.',
      );
      return;
    }
    if (_returnDateTime != null &&
        _returnDateTime!.isBefore(_departureDateTime!)) {
      setState(
        () => _errorMessage = 'Return date must be after departure date.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success =
        await ref.read(flightControllerProvider.notifier).saveFlightTicket(
              flightNumber: flightNum,
              fromAirport: _fromAirport!.iata,
              toAirport: _toAirport!.iata,
              departureDateTime: _departureDateTime!,
              returnDateTime: _returnDateTime,
              seat: _seatController.text.trim().isNotEmpty
                  ? _seatController.text.trim()
                  : null,
              gate: _gateController.text.trim().isNotEmpty
                  ? _gateController.text.trim()
                  : null,
              idempotencyKey: _idempotencyKey,
            );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      widget.onCompleted?.call();
    } else {
      final err = ref.read(flightControllerProvider).error;
      setState(() {
        _errorMessage = err ?? 'Failed to save flight ticket. Try again.';
      });
    }
  }

  String _confidenceLabel(ParseConfidence confidence) {
    final pct = (confidence.overall * 100).round();
    if (confidence.isHigh) {
      return 'High Confidence Match ($pct%) — Ready to Confirm';
    }
    if (confidence.isMedium) {
      return 'Medium Confidence ($pct%) — Please review fields';
    }
    return 'Low Confidence — Verify details below';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<BoardingPassEntryMode>(
            segments: const [
              ButtonSegment(
                value: BoardingPassEntryMode.camera,
                icon: Icon(Icons.qr_code_scanner_rounded),
                label: Text('Scan'),
              ),
              ButtonSegment(
                value: BoardingPassEntryMode.manual,
                icon: Icon(Icons.edit_rounded),
                label: Text('Manual'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => _setMode(selection.first),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_mode == BoardingPassEntryMode.camera) ...[
            if (_scanAccepted)
              GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: colors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _acceptedLabel(),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _setMode(BoardingPassEntryMode.camera),
                      child: const Text('Scan again'),
                    ),
                  ],
                ),
              )
            else if (_readingPhoto)
              const GlassCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.sm),
                      Text('Reading your ticket…'),
                    ],
                  ),
                ),
              )
            else ...[
              BoardingPassCameraView(
                onScanned: _handleScan,
                onUseManual: () => _setMode(BoardingPassEntryMode.manual),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No barcode on your ticket?',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_camera_rounded, size: 18),
                      label: const Text('Take photo'),
                      onPressed: () => _scanFromPhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Upload screenshot'),
                      onPressed: () => _scanFromPhoto(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
            if (_scanMessage != null && !_scanAccepted) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _scanMessage!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],

          if (_mode == BoardingPassEntryMode.manual && !_showOcrInput)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Paste boarding pass text'),
                onPressed: () => setState(() => _showOcrInput = true),
              ),
            ),

          if (_showOcrInput) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste barcode string (M1...) or OCR text:',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _manualOcrController,
                    maxLines: 3,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'M1DOE/JOHN EN1234567SINNRTGA 0881 290Y...',
                      hintStyle: TextStyle(color: colors.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showOcrInput = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: () {
                          final text = _manualOcrController.text.trim();
                          _handleRawInput(text);
                        },
                        child: const Text('Extract'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (kDebugMode && _debugCapture != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.bug_report_rounded, size: 16),
                label: const Text('Copy test fixture (debug)'),
                onPressed: _copyDebugFixture,
              ),
            ),

          // Adaptive Confidence Indicator
          // (High: 1-Tap | Med: Review | Low: Edit)
          if (_parsedCandidate != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: _parsedCandidate!.confidence.isHigh
                    ? colors.accent.withValues(alpha: 0.15)
                    : (_parsedCandidate!.confidence.isMedium
                        ? Colors.amber.withValues(alpha: 0.15)
                        : colors.surface),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _parsedCandidate!.confidence.isHigh
                      ? colors.accent
                      : (_parsedCandidate!.confidence.isMedium
                          ? Colors.amber
                          : colors.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _parsedCandidate!.confidence.isHigh
                        ? Icons.verified_rounded
                        : (_parsedCandidate!.confidence.isMedium
                            ? Icons.info_outline_rounded
                            : Icons.edit_note_rounded),
                    color: _parsedCandidate!.confidence.isHigh
                        ? colors.accent
                        : (_parsedCandidate!.confidence.isMedium
                            ? Colors.amber
                            : colors.textSecondary),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _confidenceLabel(_parsedCandidate!.confidence),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Form fields
          ModernTextField(
            label: 'FLIGHT NUMBER',
            hint: 'e.g. SQ 321 or GA881',
            controller: _flightNumberController,
            prefixIcon: Icons.airplanemode_active_rounded,
          ),
          const SizedBox(height: AppSpacing.md),

          // Airport picker fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FROM AIRPORT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickAirport(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flight_takeoff_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fromAirport != null
                                    ? '${_fromAirport!.iata} '
                                        '(${_fromAirport!.name})'
                                    : 'Select origin',
                                style: TextStyle(
                                  color: _fromAirport != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TO AIRPORT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickAirport(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flight_land_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _toAirport != null
                                    ? '${_toAirport!.iata} '
                                        '(${_toAirport!.name})'
                                    : 'Select destination',
                                style: TextStyle(
                                  color: _toAirport != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Date Time picker fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEPARTURE TIME',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickDateTime(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _departureDateTime != null
                                    ? '${_departureDateTime!.month}/${_departureDateTime!.day} ${_departureDateTime!.hour.toString().padLeft(2, '0')}:${_departureDateTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Pick departure',
                                style: TextStyle(
                                  color: _departureDateTime != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RETURN TIME',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickDateTime(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_repeat_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _returnDateTime != null
                                    ? '${_returnDateTime!.month}/${_returnDateTime!.day} ${_returnDateTime!.hour.toString().padLeft(2, '0')}:${_returnDateTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Pick return',
                                style: TextStyle(
                                  color: _returnDateTime != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Optional Seat & Gate fields
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  label: 'GATE',
                  hint: 'e.g. 12 or B4',
                  controller: _gateController,
                  prefixIcon: Icons.door_front_door_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ModernTextField(
                  label: 'SEAT',
                  hint: 'e.g. 18A or 3C',
                  controller: _seatController,
                  prefixIcon: Icons.airline_seat_recline_normal_rounded,
                ),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: colors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Submit button
          AppButton(
            label: widget.completeButtonText,
            isLoading: _isSubmitting,
            onPressed: _handleSubmit,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
