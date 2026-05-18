import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/paired_device_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('save → read → hasPaired → clear', () async {
    expect(await PairedDeviceStore.read(), isNull);
    expect(await PairedDeviceStore.hasPaired(), isFalse);

    await PairedDeviceStore.save('AA:BB:CC:DD', 'T1000-E');
    final PairedDevice? p = await PairedDeviceStore.read();
    expect(p, isNotNull);
    expect(p!.remoteId, 'AA:BB:CC:DD');
    expect(p.name, 'T1000-E');
    expect(await PairedDeviceStore.hasPaired(), isTrue);

    await PairedDeviceStore.clear();
    expect(await PairedDeviceStore.read(), isNull);
    expect(await PairedDeviceStore.hasPaired(), isFalse);
  });

  test('read falls back to id when no name stored', () async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'mm.paired.id': 'XYZ'});
    final PairedDevice? p = await PairedDeviceStore.read();
    expect(p!.remoteId, 'XYZ');
    expect(p.name, 'XYZ');
  });
}
