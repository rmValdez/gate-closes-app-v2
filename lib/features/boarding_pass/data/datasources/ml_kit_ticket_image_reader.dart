import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_image_reader.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Barcode symbologies that carry an IATA BCBP payload: PDF417 (paper
/// passes), Aztec (mobile passes), plus QR/DataMatrix used by some airlines.
/// Anything else (product barcodes, ...) is ignored.
const List<BarcodeFormat> boardingPassBarcodeFormats = [
  BarcodeFormat.pdf417,
  BarcodeFormat.aztec,
  BarcodeFormat.qrCode,
  BarcodeFormat.dataMatrix,
];

/// On-device [TicketImageReader]: barcodes via mobile_scanner (ML Kit on
/// Android, Apple Vision on iOS) and printed text via ML Kit Text Recognition
/// (Latin script). Nothing leaves the phone.
class MlKitTicketImageReader implements TicketImageReader {
  const MlKitTicketImageReader();

  @override
  Future<String?> readBarcode(String imagePath) async {
    final scanner = MobileScannerController(autoStart: false);
    try {
      final capture = await scanner.analyzeImage(
        imagePath,
        formats: boardingPassBarcodeFormats,
      );
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        final raw = barcode.rawValue;
        if (raw != null && raw.trim().isNotEmpty) return raw;
      }
      return null;
    } finally {
      await scanner.dispose();
    }
  }

  @override
  Future<String> readText(String imagePath) async {
    final recognizer = TextRecognizer();
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
