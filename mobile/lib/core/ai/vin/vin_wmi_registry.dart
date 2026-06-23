import 'dart:convert';

import 'package:flutter/services.dart';

class WmiRegistryEntry {
  const WmiRegistryEntry({
    required this.wmi,
    required this.manufacturer,
    required this.make,
    required this.country,
  });

  final String wmi;
  final String manufacturer;
  final String make;
  final String country;

  factory WmiRegistryEntry.fromJson(Map<String, dynamic> json) {
    return WmiRegistryEntry(
      wmi: '${json['wmi']}'.toUpperCase(),
      manufacturer: '${json['manufacturer']}',
      make: '${json['make']}',
      country: '${json['country']}',
    );
  }
}

/// Offline WMI → manufacturer/make lookup (India + global imports).
class VinWmiRegistry {
  VinWmiRegistry._();
  static final VinWmiRegistry instance = VinWmiRegistry._();

  Map<String, WmiRegistryEntry>? _byWmi;

  Future<void> _ensureLoaded() async {
    if (_byWmi != null) return;
    final raw = await rootBundle.loadString('assets/data/vin_wmi_registry.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>)
        .map((e) => WmiRegistryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    _byWmi = {for (final e in entries) e.wmi: e};
  }

  Future<WmiRegistryEntry?> lookup(String vin) async {
    await _ensureLoaded();
    if (vin.length < 3) return null;
    return _byWmi![vin.substring(0, 3).toUpperCase()];
  }
}
