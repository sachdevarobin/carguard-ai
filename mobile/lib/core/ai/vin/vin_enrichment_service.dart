import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/database.dart';
import '../parsers/vin_decoder.dart';
import 'nhtsa_vin_client.dart';
import 'vin_wmi_registry.dart';

/// Merges ISO 3779 decode + offline WMI registry + NHTSA API (cached).
class VinEnrichmentService {
  VinEnrichmentService({NhtsaVinClient? nhtsa}) : _nhtsa = nhtsa ?? NhtsaVinClient();

  static final VinEnrichmentService instance = VinEnrichmentService();

  final NhtsaVinClient _nhtsa;
  final _registry = VinWmiRegistry.instance;

  Future<Map<String, dynamic>> enrich(
    String vin, {
    int? modelYear,
    VinDetails? baseDetails,
  }) async {
    final normalized = vin.toUpperCase();
    final local = baseDetails ?? decodeVin(normalized);
    final year = modelYear ?? local.modelYear;

    final merged = <String, dynamic>{
      ..._localFields(local),
      'model_year': year ?? local.modelYear,
    };

    final registry = await _registry.lookup(normalized);
    if (registry != null) {
      _applyRegistry(merged, registry);
    }

    final cached = await _readCache(normalized);
    if (cached != null) {
      _applyNhtsa(merged, cached);
      merged['decode_source'] = 'nhtsa_cached';
    } else {
      final live = await _fetchNhtsa(normalized, year);
      if (live.isNotEmpty) {
        _applyNhtsa(merged, live);
        await _writeCache(normalized, live);
        merged['decode_source'] = 'nhtsa_live';
      } else if (registry != null) {
        merged['decode_source'] = 'offline_registry';
      } else {
        merged['decode_source'] = 'iso3779';
      }
    }

    _fillGuaranteedFields(merged, local, registry);
    return merged;
  }

  Map<String, dynamic> _localFields(VinDetails d) => {
        'vin': d.vin,
        'check_digit_valid': d.checkDigitValid,
        'model_year': d.modelYear,
        'country': d.country,
        'region': d.region,
        'manufacturer': d.manufacturer,
        'vehicle_category': d.vehicleCategory,
        'plant_code': d.plantCode,
        'wmi': d.wmi,
        'vds': d.vds,
        'vis': d.vis,
      };

  void _applyRegistry(Map<String, dynamic> merged, WmiRegistryEntry entry) {
    merged['manufacturer'] = entry.manufacturer;
    merged['make'] ??= entry.make;
    merged['country'] ??= entry.country;
    merged['region'] ??= _regionForCountry(entry.country);
  }

  void _applyNhtsa(Map<String, dynamic> merged, Map<String, String> nhtsa) {
    void set(String key, String nhtsaKey) {
      final value = nhtsa[nhtsaKey];
      if (value != null && value.isNotEmpty) merged[key] = value;
    }

    set('make', 'Make');
    set('model', 'Model');
    set('manufacturer', 'Manufacturer');
    set('body_class', 'BodyClass');
    set('vehicle_type', 'VehicleType');
    set('drive_type', 'DriveType');
    set('fuel_type', 'FuelTypePrimary');
    set('engine', 'EngineModel');
    set('engine_cylinders', 'EngineCylinders');
    set('displacement_l', 'DisplacementL');
    set('plant_country', 'PlantCountry');
    set('plant_city', 'PlantCity');
    set('plant_company', 'PlantCompany');
    set('doors', 'Doors');
    set('series', 'Series');
    set('trim', 'Trim');

    final nhtsaYear = int.tryParse(nhtsa['ModelYear'] ?? '');
    if (nhtsaYear != null) merged['model_year'] = nhtsaYear;

    final plantCountry = nhtsa['PlantCountry'];
    if (plantCountry != null && plantCountry.isNotEmpty) {
      merged['country'] ??= plantCountry;
    }
  }

  Future<Map<String, String>> _fetchNhtsa(String vin, int? year) async {
    try {
      var result = await _nhtsa.decodeVinValues(vin, modelYear: year);
      if (result.isEmpty) {
        final wmiData = await _nhtsa.decodeWmi(vin.substring(0, 3));
        if (wmiData.isNotEmpty) {
          result = {
            if (wmiData['Manufacturer']?.isNotEmpty == true) 'Manufacturer': wmiData['Manufacturer']!,
            if (wmiData['Country']?.isNotEmpty == true) 'PlantCountry': wmiData['Country']!,
            if (wmiData['VehicleType']?.isNotEmpty == true) 'VehicleType': wmiData['VehicleType']!,
          };
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  void _fillGuaranteedFields(
    Map<String, dynamic> merged,
    VinDetails local,
    WmiRegistryEntry? registry,
  ) {
    merged['make'] ??= registry?.make ?? _makeFromManufacturer(merged['manufacturer'] as String?);
    merged['model'] ??= _modelFallback(merged);
    merged['manufacturer'] ??=
        registry?.manufacturer ?? 'Manufacturer WMI ${local.wmi} (ISO 3779)';
    merged['country'] ??= registry?.country ?? local.country ?? 'See VIN region code';
    merged['region'] ??= local.region ?? _regionForCountry('${merged['country']}');
    merged['body_class'] ??= merged['vehicle_type'] ?? local.vehicleCategory ?? 'Passenger vehicle';
    merged['vehicle_type'] ??= local.vehicleCategory ?? 'Passenger vehicle';
    merged['fuel_type'] ??= 'Petrol / diesel (confirm on RC book)';
    merged['engine'] ??= 'See RC book / window sticker';
    merged['plant_country'] ??= merged['country'];
    merged['plant_city'] ??= 'Plant code ${local.plantCode}';
    merged['drive_type'] ??= 'Confirm on variant sticker';
    merged['model_year'] ??= local.modelYear ?? _yearFromVin(local.vin);
  }

  String _makeFromManufacturer(String? manufacturer) {
    if (manufacturer == null || manufacturer.isEmpty) return 'Unknown make (WMI registered)';
    return manufacturer.split(' ').first;
  }

  String _modelFallback(Map<String, dynamic> merged) {
    final series = merged['series'] as String?;
    if (series != null && series.isNotEmpty) return series;
    final trim = merged['trim'] as String?;
    if (trim != null && trim.isNotEmpty) return trim;
    return 'Confirm model on registration certificate';
  }

  String _regionForCountry(String country) {
    return switch (country) {
      'India' => 'India / South Asia',
      'United States' => 'North America',
      'Japan' => 'Japan',
      'Germany' => 'Germany',
      'South Korea' => 'South Korea',
      'United Kingdom' => 'United Kingdom',
      _ => country,
    };
  }

  int? _yearFromVin(String vin) {
    if (vin.length < 10) return null;
    const yearCodes = {
      'A': 2010, 'B': 2011, 'C': 2012, 'D': 2013, 'E': 2014, 'F': 2015,
      'G': 2016, 'H': 2017, 'J': 2018, 'K': 2019, 'L': 2020, 'M': 2021,
      'N': 2022, 'P': 2023, 'R': 2024, 'S': 2025, 'T': 2026, 'V': 2027,
      'W': 2028, 'X': 2029, 'Y': 2030,
    };
    return yearCodes[vin[9]];
  }

  Future<Map<String, String>?> _readCache(String vin) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('vin_decode_cache', where: 'vin = ?', whereArgs: [vin], limit: 1);
    if (rows.isEmpty) return null;
    final payload = jsonDecode(rows.first['payload_json'] as String) as Map<String, dynamic>;
    return payload.map((k, v) => MapEntry(k, '$v'));
  }

  Future<void> _writeCache(String vin, Map<String, String> payload) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'vin_decode_cache',
      {
        'vin': vin,
        'payload_json': jsonEncode(payload),
        'fetched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
