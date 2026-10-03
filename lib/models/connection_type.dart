enum CarConnectionType { none, carPlay, androidAuto, manual }

bool? androidAutoConnectedFromNativeType(int type) {
  switch (type) {
    case 0:
      return false;
    case 2:
      return true;
    default:
      return null;
  }
}
