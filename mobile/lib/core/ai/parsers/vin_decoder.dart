class VinDetails {
  const VinDetails({
    required this.vin,
    required this.checkDigitValid,
    this.modelYear,
    this.country,
    this.region,
    this.manufacturer,
    this.vehicleCategory,
    this.plantCode,
    required this.wmi,
    required this.vds,
    required this.vis,
  });

  final String vin;
  final bool checkDigitValid;
  final int? modelYear;
  final String? country;
  final String? region;
  final String? manufacturer;
  final String? vehicleCategory;
  final String? plantCode;
  final String wmi;
  final String vds;
  final String vis;

  List<({String label, String value})> toDisplayRows() => [
        (label: 'VIN', value: vin),
        (label: 'Check digit', value: checkDigitValid ? 'Valid' : 'Invalid — likely OCR error'),
        if (modelYear != null) (label: 'Model year', value: '$modelYear'),
        if (country != null) (label: 'Country / region', value: country!),
        if (region != null) (label: 'Market region', value: region!),
        if (manufacturer != null) (label: 'Manufacturer', value: manufacturer!),
        if (vehicleCategory != null) (label: 'Vehicle type', value: vehicleCategory!),
        (label: 'WMI (chars 1–3)', value: wmi),
        (label: 'Plant code (char 11)', value: plantCode ?? vin[10]),
        (label: 'Serial (chars 12–17)', value: vis.substring(3)),
      ];
}

const _yearCodes = {
  'A': 2010, 'B': 2011, 'C': 2012, 'D': 2013, 'E': 2014, 'F': 2015,
  'G': 2016, 'H': 2017, 'J': 2018, 'K': 2019, 'L': 2020, 'M': 2021,
  'N': 2022, 'P': 2023, 'R': 2024, 'S': 2025, 'T': 2026, 'V': 2027,
  'W': 2028, 'X': 2029, 'Y': 2030,
};

const _wmiManufacturers = {
  'MA3': 'Maruti Suzuki (India)',
  'MA7': 'Maruti Suzuki (India)',
  'MAL': 'Hyundai Motor India',
  'MAT': 'Tata Motors (India)',
  'MBJ': 'Toyota Kirloskar (India)',
  'MA1': 'Mahindra (India)',
  'MZB': 'Kia India',
  'MZA': 'Honda Cars India',
  'WBA': 'BMW (Germany)',
  'WDB': 'Mercedes-Benz (Germany)',
  'WAU': 'Audi (Germany)',
  'JHM': 'Honda (Japan)',
  'JTD': 'Toyota (Japan)',
  'KMH': 'Hyundai (South Korea)',
  '1HG': 'Honda (USA)',
  '1FA': 'Ford (USA)',
  '1G1': 'Chevrolet (USA)',
};

int _vinCharValue(String char) {
  const values = {
    'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 7, 'H': 8,
    'J': 1, 'K': 2, 'L': 3, 'M': 4, 'N': 5, 'P': 7, 'R': 9,
    'S': 2, 'T': 3, 'U': 4, 'V': 5, 'W': 6, 'X': 7, 'Y': 8, 'Z': 9,
  };
  return values[char] ?? int.parse(char);
}

bool isValidVinCheckDigit(String vin) {
  if (vin.length != 17) return false;
  const weights = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += _vinCharValue(vin[i]) * weights[i];
  }
  final remainder = sum % 11;
  final expected = remainder == 10 ? 'X' : '$remainder';
  return vin[8] == expected;
}

String? _regionFromFirstChar(String char) {
  return switch (char) {
    '1' || '2' || '3' || '4' || '5' => 'North America',
    '6' || '7' => 'Oceania / general',
    '8' => 'South America',
    '9' => 'Brazil',
    'J' => 'Japan',
    'K' => 'South Korea',
    'L' => 'China',
    'M' => 'India / South Asia',
    'N' => 'Turkey / assigned',
    'S' => 'United Kingdom',
    'T' => 'Switzerland / assigned',
    'V' => 'France / Spain',
    'W' => 'Germany',
    'X' => 'Russia / assigned',
    'Y' => 'Sweden / Finland',
    'Z' => 'Italy',
    _ => null,
  };
}

String? _countryHint(String wmi, String first) {
  if (_wmiManufacturers.containsKey(wmi)) {
    final m = _wmiManufacturers[wmi]!;
    if (m.contains('India')) return 'India';
  }
  return switch (first) {
    'M' => 'India (likely)',
    'J' => 'Japan',
    'K' => 'South Korea',
    'L' => 'China',
    'W' => 'Germany',
    '1' || '2' || '3' || '4' || '5' => 'United States',
    _ => _regionFromFirstChar(first),
  };
}

String? _vehicleCategory(String vin) {
  final code = vin[2];
  return switch (code) {
    '1' => 'Passenger car',
    '2' => 'Passenger car (MPV/SUV class)',
    '3' => 'Light commercial / multipurpose',
    '4' => 'Truck / chassis',
    '5' => 'Bus / chassis',
    '6' => 'Trailer',
    '7' => 'Motorcycle',
    '8' => 'Special purpose',
    '9' => 'Truck / tractor',
    _ => null,
  };
}

VinDetails decodeVin(String vin) {
  final normalized = vin.toUpperCase();
  final wmi = normalized.substring(0, 3);
  final vds = normalized.substring(3, 9);
  final vis = normalized.substring(9);

  return VinDetails(
    vin: normalized,
    checkDigitValid: isValidVinCheckDigit(normalized),
    modelYear: _yearCodes[normalized[9]],
    country: _countryHint(wmi, normalized[0]),
    region: _regionFromFirstChar(normalized[0]),
    manufacturer: _wmiManufacturers[wmi],
    vehicleCategory: _vehicleCategory(normalized),
    plantCode: normalized[10],
    wmi: wmi,
    vds: vds,
    vis: vis,
  );
}
