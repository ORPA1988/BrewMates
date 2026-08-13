import 'package:geolocator/geolocator.dart';

/// Ergebnis einer Standortabfrage – bewusst grob, damit die UI je Fall
/// einen klaren Pfad hat (Beacon mit Position / Fallback manuelle Venue).
sealed class LocationResult {
  const LocationResult();
}

class LocationGranted extends LocationResult {
  const LocationGranted(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Nutzer hat die Berechtigung (dauerhaft) verweigert.
class LocationDenied extends LocationResult {
  const LocationDenied({this.forever = false});

  final bool forever;
}

/// Ortungsdienste sind aus oder die Plattform liefert keinen Standort.
class LocationUnavailable extends LocationResult {
  const LocationUnavailable();
}

/// Kapselt geolocator; in Tests per Provider-Override durch einen Fake
/// ersetzbar (kein Plattform-Channel nötig).
class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationDenied(forever: true);
      }
      if (permission == LocationPermission.denied) {
        return const LocationDenied();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationGranted(position.latitude, position.longitude);
    } catch (_) {
      // Timeout, fehlende Plattform-Implementierung (z. B. mancher
      // Windows-PC ohne Ortung) o. Ä.
      return const LocationUnavailable();
    }
  }
}
