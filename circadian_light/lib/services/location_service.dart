import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

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

      // Calculate sunrise and sunset using sunrisesunset.io API
      final result = await _fetchSunriseSunsetFromAPI(
        position.latitude,
        position.longitude,
        date,
      );

      if (result == null) {
        _logger.warning('API call failed, could not get sunrise/sunset times');
        return null;
      }

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

  /// Fetch sunrise and sunset times from sunrisesunset.io API
  Future<({TimeOfDay sunrise, TimeOfDay sunset})?> _fetchSunriseSunsetFromAPI(
    double latitude,
    double longitude,
    DateTime date,
  ) async {
    try {
      // Format date as YYYY-MM-DD
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Build API URL
      final url = Uri.parse('https://api.sunrisesunset.io/json')
          .replace(queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'date': dateString,
        'time_format': '24', // Use 24-hour format for easier parsing
      });

      _logger.info('Fetching sunrise/sunset from API: $url');

      // Make HTTP request with timeout
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('API request timed out', const Duration(seconds: 10));
        },
      );

      if (response.statusCode != 200) {
        _logger.severe('API request failed with status ${response.statusCode}: ${response.body}');
        return null;
      }

      // Parse JSON response
      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        _logger.severe('API returned error status: ${data['status']}');
        return null;
      }

      final results = data['results'];
      final sunriseString = results['sunrise'] as String;
      final sunsetString = results['sunset'] as String;

      // Parse time strings (format: "HH:MM:SS" in 24-hour format)
      final sunrise = _parseTimeString(sunriseString);
      final sunset = _parseTimeString(sunsetString);

      if (sunrise == null || sunset == null) {
        _logger.severe('Failed to parse sunrise/sunset times from API response');
        return null;
      }

      _logger.info('Successfully fetched times from API - Sunrise: ${sunrise.hour}:${sunrise.minute.toString().padLeft(2, '0')}, Sunset: ${sunset.hour}:${sunset.minute.toString().padLeft(2, '0')}');

      return (sunrise: sunrise, sunset: sunset);

    } catch (e) {
      _logger.severe('Error fetching sunrise/sunset from API: $e');
      return null;
    }
  }

  /// Parse time string in format "HH:MM:SS" to TimeOfDay
  TimeOfDay? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
      return null;
    } catch (e) {
      _logger.severe('Error parsing time string "$timeString": $e');
      return null;
    }
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