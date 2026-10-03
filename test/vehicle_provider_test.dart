import 'package:car_presence/models/connection_type.dart';
import 'package:car_presence/models/vehicle_state.dart';
import 'package:car_presence/providers/vehicle_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 10, 3, 12);
  final later = DateTime.utc(2026, 10, 3, 13);

  VehicleProvider providerAt(DateTime time) {
    return VehicleProvider(clock: () => time);
  }

  test('starts off', () {
    final provider = providerAt(fixedNow);

    expect(provider.state.carMode, isFalse);
    expect(provider.state.connectionType, CarConnectionType.none);
    expect(provider.state.connectedSince, isNull);
    expect(presenceDetails(provider.state), isNull);
    expect(presenceState(provider.state), isNull);
  });

  test('manual on sets connectedSince and manual off clears it', () {
    final provider = providerAt(fixedNow);

    provider.setManualLatched(true);

    expect(provider.state.carMode, isTrue);
    expect(provider.state.connectionType, CarConnectionType.manual);
    expect(provider.state.connectedSince, fixedNow);

    provider.setManualLatched(false);

    expect(provider.state.carMode, isFalse);
    expect(provider.state.connectionType, CarConnectionType.none);
    expect(provider.state.connectedSince, isNull);
  });

  test('projection with the switch on becomes androidAuto', () {
    expect(androidAutoConnectedFromNativeType(2), isTrue);

    final provider = providerAt(fixedNow);
    provider.setAndroidAutoConnected(true);

    expect(provider.state.carMode, isTrue);
    expect(provider.state.connectionType, CarConnectionType.androidAuto);
  });

  test('native automotive type is ignored and cannot turn the car on', () {
    expect(androidAutoConnectedFromNativeType(1), isNull);
    expect(androidAutoConnectedFromNativeType(99), isNull);

    final provider = providerAt(fixedNow);
    expect(provider.state.connectionType, isNot(CarConnectionType.androidAuto));
  });

  test('not connected native type is false', () {
    expect(androidAutoConnectedFromNativeType(0), isFalse);
  });

  test('carPlay outranks androidAuto and androidAuto outranks manual', () {
    final provider = providerAt(fixedNow);
    provider.setManualLatched(true);
    provider.setAndroidAutoConnected(true);
    provider.setCarPlayConnected(true);

    expect(provider.state.connectionType, CarConnectionType.carPlay);

    provider.setCarPlayConnected(false);

    expect(provider.state.connectionType, CarConnectionType.androidAuto);

    provider.setAndroidAutoConnected(false);

    expect(provider.state.connectionType, CarConnectionType.manual);
  });

  test('manual then projection keeps connectedSince and falls back to manual', () {
    var now = fixedNow;
    final provider = VehicleProvider(clock: () => now);
    provider.setManualLatched(true);
    now = later;
    provider.setAndroidAutoConnected(true);

    expect(provider.state.connectionType, CarConnectionType.androidAuto);
    expect(provider.state.connectedSince, fixedNow);

    provider.setAndroidAutoConnected(false);

    expect(provider.state.carMode, isTrue);
    expect(provider.state.connectionType, CarConnectionType.manual);
    expect(provider.state.connectedSince, fixedNow);
  });

  test('projection without latch clears the car when it disconnects', () {
    final provider = providerAt(fixedNow);
    provider.setAndroidAutoConnected(true);
    provider.setAndroidAutoConnected(false);

    expect(provider.state.carMode, isFalse);
    expect(provider.state.connectedSince, isNull);
  });

  test('turning off android auto detection clears the car without a latch', () {
    final provider = providerAt(fixedNow);
    provider.setAndroidAutoConnected(true);
    provider.setAutoDetectAndroid(false);

    expect(provider.state.carMode, isFalse);
    expect(provider.state.connectionType, CarConnectionType.none);
    expect(provider.state.connectedSince, isNull);
  });

  test('turning off carplay detection ignores a carplay connection', () {
    final provider = providerAt(fixedNow);
    provider.setAutoDetectCarPlay(false);
    provider.setCarPlayConnected(true);

    expect(provider.state.carMode, isFalse);
    expect(provider.state.connectionType, CarConnectionType.none);
  });

  test('a new provider does not keep another instance latch', () {
    final first = providerAt(fixedNow);
    first.setManualLatched(true);

    final second = providerAt(later);

    expect(second.state.carMode, isFalse);
    expect(second.state.connectionType, CarConnectionType.none);
    expect(second.state.connectedSince, isNull);
  });

  test('presence text follows the connection type', () {
    final off = const VehicleState(
      carMode: false,
      connectionType: CarConnectionType.none,
      connectedSince: null,
    );
    expect(presenceDetails(off), isNull);
    expect(presenceState(off), isNull);

    final manual = VehicleState(
      carMode: true,
      connectionType: CarConnectionType.manual,
      connectedSince: fixedNow,
    );
    expect(presenceDetails(manual), 'Driving');
    expect(presenceState(manual), 'Car Mode');

    final androidAuto = VehicleState(
      carMode: true,
      connectionType: CarConnectionType.androidAuto,
      connectedSince: fixedNow,
    );
    expect(presenceDetails(androidAuto), 'Driving');
    expect(presenceState(androidAuto), 'Connected via Android Auto');

    final carPlay = VehicleState(
      carMode: true,
      connectionType: CarConnectionType.carPlay,
      connectedSince: fixedNow,
    );
    expect(presenceDetails(carPlay), 'Driving');
    expect(presenceState(carPlay), 'Connected via CarPlay');
  });
}
