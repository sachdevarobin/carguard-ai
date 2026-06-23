import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carguard_ai/core/ai/vin/vin_wmi_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VinWmiRegistry.instance;
  });

  test('Indian Maruti WMI resolves offline', () async {
    final entry = await VinWmiRegistry.instance.lookup('MA3ERLF1S00458086');
    expect(entry, isNotNull);
    expect(entry!.make, 'Maruti Suzuki');
    expect(entry.country, 'India');
  });

  test('German BMW WMI resolves offline', () async {
    final entry = await VinWmiRegistry.instance.lookup('WBA3A91060NT12345');
    expect(entry, isNotNull);
    expect(entry!.make, 'BMW');
    expect(entry.country, 'Germany');
  });

  test('US Honda WMI resolves offline', () async {
    final entry = await VinWmiRegistry.instance.lookup('1HGBH41JXMN109186');
    expect(entry, isNotNull);
    expect(entry!.make, 'Honda');
  });
}
