import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import 'package:geocoding/geocoding.dart';

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

  // Cache for location name
  String? _cachedLocationName;

  bool get hasLocationPermission => _hasLocationPermission;
  Position? get lastKnownPosition => _lastKnownPosition;
  String? get cachedLocationName => _cachedLocationName;

  /// Request location permission from the user
  Future<bool> requestLocationPermission() async {
    try {
      _logger.info('Requesting location permission...');

      // Check current permission status for "when in use" location
      PermissionStatus permission = await Permission.locationWhenInUse.status;

      if (permission.isGranted) {
        _hasLocationPermission = true;
        _logger.info('Location permission already granted');
        return true;
      }

      if (permission.isDenied) {
        // Request permission
        permission = await Permission.locationWhenInUse.request();
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

      // Update location name cache in background
      _updateLocationName(position);

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
    // Note: longitude / 15 gives us the time zone offset in hours
    final sunriseHour = 12 - hourAngle / 15;
    final sunsetHour = 12 + hourAngle / 15;

    // Apply timezone offset (local timezone offset from UTC)
    final now = DateTime.now();
    final utcNow = now.toUtc();
    final timezoneOffsetHours = (now.millisecondsSinceEpoch - utcNow.millisecondsSinceEpoch) / (1000 * 60 * 60);

    final localSunriseHour = sunriseHour + timezoneOffsetHours;
    final localSunsetHour = sunsetHour + timezoneOffsetHours;

    // Convert to TimeOfDay, handling day boundary crossing
    TimeOfDay sunrise = _hoursToTimeOfDay(localSunriseHour);
    TimeOfDay sunset = _hoursToTimeOfDay(localSunsetHour);

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
      final permission = await Permission.locationWhenInUse.status;
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

  /// Update location name cache using reverse geocoding
  Future<void> _updateLocationName(Position position) async {
    try {
      _logger.info('Getting location name for ${position.latitude}, ${position.longitude}');

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        // Build location string prioritizing city and country
        String locationName = '';

        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          locationName = placemark.locality!;
        } else if (placemark.subAdministrativeArea != null && placemark.subAdministrativeArea!.isNotEmpty) {
          locationName = placemark.subAdministrativeArea!;
        } else if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          locationName = placemark.administrativeArea!;
        }

        if (placemark.country != null && placemark.country!.isNotEmpty) {
          if (locationName.isNotEmpty) {
            locationName += ', ${placemark.country!}';
          } else {
            locationName = placemark.country!;
          }
        }

        if (locationName.isNotEmpty) {
          _cachedLocationName = locationName;
          _logger.info('Location name updated: $_cachedLocationName');
        } else {
          _cachedLocationName = 'Unknown Location';
        }
      } else {
        _cachedLocationName = 'Unknown Location';
      }
    } catch (e) {
      _logger.severe('Error getting location name: $e');
      _cachedLocationName = 'Unknown Location';
    }
  }

  /// Get location name for current position
  Future<String?> getLocationName() async {
    // Return cached location name if available
    if (_cachedLocationName != null) {
      return _cachedLocationName;
    }

    // Try to get current location and update name
    final position = await getCurrentLocation();
    if (position != null) {
      await _updateLocationName(position);
      return _cachedLocationName;
    }

    return null;
  }
}