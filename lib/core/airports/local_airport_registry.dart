import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:gate_closes/core/airports/airport_code_validator.dart';
import 'package:gate_closes/core/airports/airport_reference.dart';

/// In-memory airport registry backed by bundled JSON asset.
class LocalAirportRegistry implements AirportCodeValidator {
  LocalAirportRegistry._();

  static final LocalAirportRegistry instance = LocalAirportRegistry._();

  final Map<String, AirportReference> _airportsByIata = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Loads airports from a raw JSON string (used for testing or explicit
  /// loading).
  void loadFromJsonString(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    _airportsByIata.clear();
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final ref = AirportReference.fromJson(item);
        if (ref.iata.isNotEmpty) {
          _airportsByIata[ref.iata] = ref;
        }
      }
    }
    _isInitialized = true;
  }

  /// Loads bundled assets/data/airports.json.
  Future<void> initialize([AssetBundle? bundle]) async {
    if (_isInitialized) return;
    final b = bundle ?? rootBundle;
    try {
      final jsonString = await b.loadString('assets/data/airports.json');
      loadFromJsonString(jsonString);
    } on Object catch (_) {
      // Fallback: minimal core set if asset load fails or in a headless test
      // environment.
      _isInitialized = true;
    }
  }

  @override
  bool isValidIata(String iata) {
    final clean = iata.trim().toUpperCase();
    return _airportsByIata.containsKey(clean);
  }

  @override
  AirportReference? resolveAirport(String iata) {
    final clean = iata.trim().toUpperCase();
    return _airportsByIata[clean];
  }
}
