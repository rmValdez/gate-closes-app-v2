/// Reads raw content off a photo of a ticket. Implemented on-device (see
/// `MlKitTicketImageReader`); the image is never uploaded.
///
/// Kept platform-free so extraction strategies can be unit-tested with a fake.
abstract class TicketImageReader {
  /// The payload of a boarding-pass barcode (PDF417/Aztec/QR/DataMatrix) in
  /// the image, or null if there isn't one.
  Future<String?> readBarcode(String imagePath);

  /// All printed text in the image, in reading order (may be empty).
  Future<String> readText(String imagePath);
}
