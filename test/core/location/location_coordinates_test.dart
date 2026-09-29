import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';

void main() {
  group('LocationCoordinates Domain Entity & Quantization', () {
    test('quantizes coordinates to 3 decimal places by default (~110m privacy)',
        () {
      const coords = LocationCoordinates(
        latitude: 1.36442849201,
        longitude: 103.9915382012,
      );

      final quantized = coords.quantize();

      expect(quantized.latitude, 1.364);
      expect(quantized.longitude, 103.992);
    });

    test('supports custom precision quantization', () {
      const coords = LocationCoordinates(
        latitude: 51.4700223,
        longitude: -0.4542955,
      );

      final precision2 = coords.quantize(precision: 2);
      expect(precision2.latitude, 51.47);
      expect(precision2.longitude, -0.45);

      final precision4 = coords.quantize(precision: 4);
      expect(precision4.latitude, 51.4700);
      expect(precision4.longitude, -0.4543);
    });

    test('handles negative and boundary coordinates accurately', () {
      const coords = LocationCoordinates(
        latitude: -33.946111,
        longitude: 151.177222,
      );

      final quantized = coords.quantize();
      expect(quantized.latitude, -33.946);
      expect(quantized.longitude, 151.177);
    });
  });
}
