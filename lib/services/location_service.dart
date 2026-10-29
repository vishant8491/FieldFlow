import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? capturedAt;
  final String? errorMessage;
  final bool isPermanentlyDenied;

  LocationResult.success({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  })  : isSuccess = true,
        errorMessage = null,
        isPermanentlyDenied = false;

  LocationResult.failure(this.errorMessage, {this.isPermanentlyDenied = false})
      : isSuccess = false,
        latitude = null,
        longitude = null,
        accuracy = null,
        capturedAt = null;
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  /// Captures single location fix on explicit demand
  Future<LocationResult> getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          'Location services are disabled on the device. Please turn them on in device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure('Location permission was denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          'Location permission is permanently denied. You can enable it in device app settings or enter coordinates manually.',
          isPermanentlyDenied: true,
        );
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: position.timestamp,
      );
    } catch (e) {
      if (kIsWeb) {
        return LocationResult.failure(
          'Unable to acquire browser location ($e). Note: Web browsers require an HTTPS connection or localhost, and user permission. You may also enter coordinates manually.',
        );
      }
      return LocationResult.failure(
        'Unable to acquire location ($e). You may enter coordinates manually.',
      );
    }
  }

  /// Validates manual coordinates
  static String? validateLatitude(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite) {
      return 'Enter a valid decimal number';
    }
    if (parsed < -90.0 || parsed > 90.0) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  static String? validateLongitude(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite) {
      return 'Enter a valid decimal number';
    }
    if (parsed < -180.0 || parsed > 180.0) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }
}
