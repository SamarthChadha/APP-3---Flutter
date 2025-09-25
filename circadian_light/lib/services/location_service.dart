import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';

class LocationService {
  LocationService._();
  static final LocationService I = LocationService._();

  static final Logger _logger = Logger('LocationService');
  Position? _lastKnownPosition;
  bool _hasLocationPermission = false;

  // Cache for calculated sunrise/sunset times
  DateTime? _lastCalculationDate;
  TimeOfDay? _cachedSunrise;
  TimeOfDay? _cachedSunset;

  bool get hasLocationPermission => _hasLocationPermission;
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Request location permission from the user
  Future<bool> requestLocationPermission() async {
    try {
      _logger.info('Requesting location permission...');

      // Check current permission status
      PermissionStatus permission = await Permission.location.status;

      if (permission.isGranted) {
        _hasLocationPermission = true;
        _logger.info('Location permission already granted');
        return true;
      }

      if (permission.isDenied) {
        // Request permission
        permission = await Permission.location.request();
      }

      if (permission.isGranted) {
        _hasLocationPermission = true;
        _logger.info('Location permission granted');
        return true;
      } else if (permission.isPermanentlyDenied) {
        _logger.warning('Location permission permanently denied');
        // User needs to enable it from app settings
        return false;
      } else {
        _logger.warning('Location permission denied');
        return false;
      }

    } catch (e) {
      _logger.severe('Error requesting location permission: $e');
      return false;
    }
  }

  /// Get the user's current location
  Future<Position?> getCurrentLocation() async {
    try {
      if (!_hasLocationPermission) {
        final granted = await requestLocationPermission();
        if (!granted) {
          _logger.warning('Cannot get location without permission');
          return null;
        }
      }

      _logger.info('Getting current location...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.warning('Location services are disabled');
        return null;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // We don't need high accuracy for sunrise/sunset
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lastKnownPosition = position;
      _logger.info('Location obtained: ${position.latitude}, ${position.longitude}');

      return position;

    } catch (e) {
      _logger.severe('Error getting current location: $e');

      // Try to return last known position if available
      if (_lastKnownPosition != null) {
        _logger.info('Returning last known position');
        return _lastKnownPosition;
      }

      return null;
    }
  }

  /// Calculate sunrise and sunset times for the given location and date
  Future<({TimeOfDay sunrise, TimeOfDay sunset})?> calculateSunriseSunset({
    Position? position,
    DateTime? date,
  }) async {
    try {
      // Use provided position or get current location
      position ??= await getCurrentLocation();
      if (position == null) {
        _logger.warning('Cannot calculate sunrise/sunset without location');
        return null;
      }

      // Use provided date or current date
      date ??= DateTime.now();

      // Check if we have cached results for today
      if (_lastCalculationDate?.day == date.day &&
          _lastCalculationDate?.month == date.month &&
          _lastCalculationDate?.year == date.year &&
          _cachedSunrise != null &&
          _cachedSunset != null) {
        _logger.info('Using cached sunrise/sunset times');
        return (sunrise: _cachedSunrise!, sunset: _cachedSunset!);
      }

      _logger.info('Calculating sunrise/sunset for ${position.latitude}, ${position.longitude} on ${date.toString()}');

      // Calculate sunrise and sunset using astronomical formulas
      final result = _calculateSunriseSunsetAstronomical(
        position.latitude,
        position.longitude,
        date,
      );

      // Cache the results
      _lastCalculationDate = date;
      _cachedSunrise = result.sunrise;
      _cachedSunset = result.sunset;

      _logger.info('Calculated sunrise: ${result.sunrise.hour}:${result.sunrise.minute.toString().padLeft(2, '0')}, sunset: ${result.sunset.hour}:${result.sunset.minute.toString().padLeft(2, '0')}');

      return result;

    } catch (e) {
      _logger.severe('Error calculating sunrise/sunset: $e');
      return null;
    }
  }

  /// Astronomical calculation for sunrise and sunset
  ({TimeOfDay sunrise, TimeOfDay sunset}) _calculateSunriseSunsetAstronomical(
    double latitude,
    double longitude,
    DateTime date,
  ) {
    // Convert latitude and longitude to radians
    final latRad = latitude * math.pi / 180;

    // Calculate day of year
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;

    // Solar declination angle
    final declination = 23.45 * math.sin((360 * (284 + dayOfYear) / 365) * math.pi / 180);
    final declinationRad = declination * math.pi / 180;

    // Hour angle for sunrise/sunset (civil twilight = -6 degrees)
    // Using -0.833 degrees for geometric horizon (accounting for atmospheric refraction)
    final zenithAngle = 90.833 * math.pi / 180;

    final hourAngleRad = math.acos(
      math.cos(zenithAngle) / (math.cos(latRad) * math.cos(declinationRad)) -
      math.tan(latRad) * math.tan(declinationRad)
    );

    final hourAngle = hourAngleRad * 180 / math.pi;

    // Calculate sunrise and sunset times (in hours from solar noon)
    final sunriseHour = 12 - hourAngle / 15 - longitude / 15;
    final sunsetHour = 12 + hourAngle / 15 - longitude / 15;

    // Convert to TimeOfDay, handling day boundary crossing
    TimeOfDay sunrise = _hoursToTimeOfDay(sunriseHour);
    TimeOfDay sunset = _hoursToTimeOfDay(sunsetHour);

    return (sunrise: sunrise, sunset: sunset);
  }

  /// Convert decimal hours to TimeOfDay
  TimeOfDay _hoursToTimeOfDay(double hours) {
    // Normalize hours to 0-24 range
    while (hours < 0) {
      hours += 24;
    }
    while (hours >= 24) {
      hours -= 24;
    }

    final hour = hours.floor();
    final minute = ((hours - hour) * 60).round();

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Open device settings for location permissions
  Future<void> openLocationSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      _logger.severe('Error opening location settings: $e');
    }
  }

  /// Check if location permissions are granted without requesting
  Future<bool> checkLocationPermission() async {
    try {
      final permission = await Permission.location.status;
      _hasLocationPermission = permission.isGranted;
      return _hasLocationPermission;
    } catch (e) {
      _logger.severe('Error checking location permission: $e');
      return false;
    }
  }

  /// Get a user-friendly status message
  String getLocationStatusMessage() {
    if (!_hasLocationPermission) {
      return 'Location permission required';
    }

    if (_lastKnownPosition == null) {
      return 'Getting location...';
    }

    if (_cachedSunrise != null && _cachedSunset != null) {
      return 'Using location-based times';
    }

    return 'Location available';
  }
}