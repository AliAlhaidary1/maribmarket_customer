import 'package:geolocator/geolocator.dart';

Future<({double latitude, double longitude})?> currentDevicePoint() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return (latitude: position.latitude, longitude: position.longitude);
}
