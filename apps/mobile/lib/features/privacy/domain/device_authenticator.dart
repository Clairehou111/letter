abstract interface class DeviceAuthenticator {
  Future<bool> canAuthenticate();

  Future<bool> authenticate();
}

final class AllowingDeviceAuthenticator implements DeviceAuthenticator {
  const AllowingDeviceAuthenticator();

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate() async => true;
}
