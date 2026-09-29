import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/boarding_pass/data/datasources/ml_kit_ticket_image_reader.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Live camera preview that decodes the boarding-pass barcode on-device
/// (ML Kit on Android, Apple Vision on iOS — no image leaves the phone) and
/// hands the raw payload to [onScanned].
///
/// Boarding passes carry an IATA BCBP string in a PDF417 (paper), Aztec
/// (mobile), QR or DataMatrix code; other formats are ignored so a product
/// barcode in frame can't trigger a parse.
///
/// The camera runs only while this widget is mounted — remove it from the tree
/// to release the camera.
class BoardingPassCameraView extends StatefulWidget {
  const BoardingPassCameraView({
    required this.onScanned,
    required this.onUseManual,
    super.key,
  });

  /// Raw barcode payload (e.g. `M1DOE/JOHN ...`). Fired once per distinct
  /// code in view.
  final ValueChanged<String> onScanned;

  /// Offered when the camera can't be used (permission denied, no camera).
  final VoidCallback onUseManual;

  @override
  State<BoardingPassCameraView> createState() => _BoardingPassCameraViewState();
}

class _BoardingPassCameraViewState extends State<BoardingPassCameraView> {
  final _controller = MobileScannerController(
    formats: boardingPassBarcodeFormats,
    // Report each distinct code once instead of on every frame.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        widget.onScanned(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraUnavailable(
                error: error,
                onUseManual: widget.onUseManual,
              ),
            ),
            // Reticle: guides framing; detection itself uses the full frame.
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.accent, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Point at the barcode on your boarding pass',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, _) {
                      if (state.torchState == TorchState.unavailable) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        tooltip: 'Flashlight',
                        color: Colors.white,
                        icon: Icon(
                          state.torchState == TorchState.on
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                        ),
                        onPressed: _controller.toggleTorch,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error, required this.onUseManual});

  final MobileScannerException error;
  final VoidCallback onUseManual;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera access is off. Allow it in Settings, or enter your flight '
            'manually.',
      MobileScannerErrorCode.unsupported =>
        'No camera available on this device.',
      _ => "Couldn't start the camera.",
    };

    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: AppSpacing.edgeInsetsMd,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography_rounded, color: colors.textSecondary),
            AppSpacing.vSm,
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            AppSpacing.vSm,
            TextButton(
              onPressed: onUseManual,
              child: const Text('Enter manually'),
            ),
          ],
        ),
      ),
    );
  }
}
