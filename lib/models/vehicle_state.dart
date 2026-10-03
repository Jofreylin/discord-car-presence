import 'connection_type.dart';

class VehicleState {
  final bool carMode;
  final CarConnectionType connectionType;
  final DateTime? connectedSince;

  const VehicleState({
    required this.carMode,
    required this.connectionType,
    required this.connectedSince,
  });
}

String? presenceDetails(VehicleState state) {
  if (!state.carMode) {
    return null;
  }
  return 'Driving';
}

String? presenceState(VehicleState state) {
  switch (state.connectionType) {
    case CarConnectionType.carPlay:
      return 'Connected via CarPlay';
    case CarConnectionType.androidAuto:
      return 'Connected via Android Auto';
    case CarConnectionType.manual:
      return 'Car Mode';
    case CarConnectionType.none:
      return null;
  }
}
