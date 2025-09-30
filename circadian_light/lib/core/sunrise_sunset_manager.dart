import 'dart:async';
import 'package:flutter/material.dart';
import 'esp_connection.dart';
import '../services/location_service.dart';

class SunriseSunsetManager {
  SunriseSunsetManager._();
  static final SunriseSunsetManager I = SunriseSunsetManager._();

  Timer? _timer;
  bool _isEnabled = false;
  bool _useLocationBasedTimes = false;

  // Default times used when location is not available or disabled
  TimeOfDay sunriseTime = const TimeOfDay(hour: 6, minute: 30);
  TimeOfDay sunsetTime = const TimeOfDay(hour: 19, minute: 0); // 7 PM
  
  bool get isEnabled => _isEnabled;
  bool get useLocationBasedTimes => _useLocationBasedTimes;

  void enable() {
    if (_isEnabled) return;
    _isEnabled = true;
    _startTimer();
    debugPrint('SunriseSunsetManager: Enabled');
  }

  /// Enable or disable location-based sunrise/sunset times
  Future<void> setLocationBasedTimes(bool enabled) async {
    _useLocationBasedTimes = enabled;

    if (enabled) {
      await _updateLocationBasedTimes();
    }

    // Restart timer to apply new times if enabled
    if (_isEnabled) {
      _startTimer();
    }

    debugPrint('SunriseSunsetManager: Location-based times ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Update sunrise/sunset times based on current location
  Future<void> _updateLocationBasedTimes() async {
    if (!_useLocationBasedTimes) return;

    try {
      final result = await LocationService.I.calculateSunriseSunset();
      if (result != null) {
        sunriseTime = result.sunrise;
        sunsetTime = result.sunset;
        debugPrint('SunriseSunsetManager: Updated to location-based times - Sunrise: ${sunriseTime.hour}:${sunriseTime.minute.toString().padLeft(2, '0')}, Sunset: ${sunsetTime.hour}:${sunsetTime.minute.toString().padLeft(2, '0')}');
      } else {
        debugPrint('SunriseSunsetManager: Could not get location-based times, using defaults');
      }
    } catch (e) {
      debugPrint('SunriseSunsetManager: Error updating location-based times: $e');
    }
  }
  
  void disable() {
    if (!_isEnabled) return;
    _isEnabled = false;
    _stopTimer();
    debugPrint('SunriseSunsetManager: Disabled');
  }
  
  void _startTimer() {
    _stopTimer();

    // Update location-based times if enabled
    if (_useLocationBasedTimes) {
      _updateLocationBasedTimes();
    }

    // Check every minute for transitions
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndExecuteTransitions();
    });

    // Also check immediately
    _checkAndExecuteTransitions();
  }
  
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
  
  void _checkAndExecuteTransitions() {
    if (!_isEnabled) return;
    
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    // Calculate transition time windows
    final sunriseStart = _subtractMinutes(sunriseTime, 15); // 15 min before sunrise
    final sunriseEnd = _addMinutes(sunriseTime, 15);        // 15 min after sunrise
    final sunsetStart = _subtractMinutes(sunsetTime, 15);   // 15 min before sunset
    final sunsetEnd = _addMinutes(sunsetTime, 15);          // 15 min after sunset
    
    final sunriseStartMinutes = sunriseStart.hour * 60 + sunriseStart.minute;
    final sunriseEndMinutes = sunriseEnd.hour * 60 + sunriseEnd.minute;
    final sunsetStartMinutes = sunsetStart.hour * 60 + sunsetStart.minute;
    final sunsetEndMinutes = sunsetEnd.hour * 60 + sunsetEnd.minute;
    
    // Check if we're in sunrise transition
    if (currentMinutes >= sunriseStartMinutes && currentMinutes <= sunriseEndMinutes) {
      _executeSunriseTransition(currentMinutes, sunriseStartMinutes, sunriseEndMinutes);
    }
    // Check if we're in sunset transition
    else if (currentMinutes >= sunsetStartMinutes && currentMinutes <= sunsetEndMinutes) {
      _executeSunsetTransition(currentMinutes, sunsetStartMinutes, sunsetEndMinutes);
    }
    // Outside transition periods - check if we should be fully on or off
    else {
      _executeStaticState(currentMinutes, sunriseEndMinutes, sunsetStartMinutes);
    }
  }
  
  void _executeSunriseTransition(int currentMinutes, int startMinutes, int endMinutes) {
    // Progress from 0.0 (start) to 1.0 (end)
    final progress = (currentMinutes - startMinutes) / (endMinutes - startMinutes);
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    // Use a smooth curve for natural sunrise feel
    final brightness = (15 * _smoothStep(clampedProgress)).round();
    
    debugPrint('Sunrise transition: progress=$clampedProgress, brightness=$brightness');
    
    // Send commands to lamp - both warm and white for sunrise
    EspConnection.I.setOn(true);
    EspConnection.I.setMode(2); // MODE_BOTH (warm + white)
    EspConnection.I.setBrightness(brightness);
  }
  
  void _executeSunsetTransition(int currentMinutes, int startMinutes, int endMinutes) {
    // Progress from 0.0 (start) to 1.0 (end)
    final progress = (currentMinutes - startMinutes) / (endMinutes - startMinutes);
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    if (clampedProgress == 0.0) {
      // Just started sunset - switch to warm only
      EspConnection.I.setMode(0); // MODE_WARM only
      EspConnection.I.setBrightness(15); // Full brightness initially
      debugPrint('Sunset started: switched to warm mode');
    } else {
      // Gradually dim the warm light
      final brightness = (15 * (1.0 - _smoothStep(clampedProgress))).round();
      EspConnection.I.setBrightness(brightness);
      debugPrint('Sunset transition: progress=$clampedProgress, brightness=$brightness');
      
      if (clampedProgress >= 1.0) {
        // Sunset complete - turn off
        EspConnection.I.setOn(false);
        debugPrint('Sunset complete: turned off');
      }
    }
  }
  
  void _executeStaticState(int currentMinutes, int sunriseEndMinutes, int sunsetStartMinutes) {
    // Between sunrise end and sunset start - gradually transition from both LEDs to warm-only
    if (currentMinutes > sunriseEndMinutes && currentMinutes < sunsetStartMinutes) {
      EspConnection.I.setOn(true);
      
      // Calculate progress through the day (0.0 = just after sunrise, 1.0 = just before sunset)
      final dayProgress = (currentMinutes - sunriseEndMinutes) / (sunsetStartMinutes - sunriseEndMinutes);
      final clampedProgress = dayProgress.clamp(0.0, 1.0);
      
      // Create a gradual transition throughout the day
      if (clampedProgress < 0.3) {
        // Morning (0-30%): Full both LEDs
        EspConnection.I.setMode(2); // MODE_BOTH
        EspConnection.I.setBrightness(15);
        debugPrint('Day state: Morning - Both LEDs full brightness');
      } else if (clampedProgress < 0.7) {
        // Mid-day (30-70%): Still both LEDs but preparing for transition
        EspConnection.I.setMode(2); // MODE_BOTH  
        EspConnection.I.setBrightness(15);
        debugPrint('Day state: Midday - Both LEDs, preparing for transition');
      } else {
        // Late afternoon (70-100%): Switch to warm-only in preparation for sunset
        EspConnection.I.setMode(0); // MODE_WARM only
        EspConnection.I.setBrightness(15);
        debugPrint('Day state: Late afternoon - Warm only, preparing for sunset');
      }
    }
    // Before sunrise start or after sunset end - keep off
    else {
      EspConnection.I.setOn(false);
    }
  }
  
  // Smooth step function for natural transitions
  double _smoothStep(double t) {
    return t * t * (3.0 - 2.0 * t);
  }
  
  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
  }
  
  TimeOfDay _subtractMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute - minutes;
    final adjustedMinutes = totalMinutes < 0 ? totalMinutes + 24 * 60 : totalMinutes;
    return TimeOfDay(hour: (adjustedMinutes ~/ 60) % 24, minute: adjustedMinutes % 60);
  }
  
  // Get current status for UI display
  String getCurrentStatus() {
    if (!_isEnabled) return 'Disabled';

    final locationStatus = _useLocationBasedTimes
        ? ' (Location-based)'
        : ' (Manual times)';

    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final sunriseStart = _subtractMinutes(sunriseTime, 15);
    final sunriseEnd = _addMinutes(sunriseTime, 15);
    final sunsetStart = _subtractMinutes(sunsetTime, 15);
    final sunsetEnd = _addMinutes(sunsetTime, 15);

    final sunriseStartMinutes = sunriseStart.hour * 60 + sunriseStart.minute;
    final sunriseEndMinutes = sunriseEnd.hour * 60 + sunriseEnd.minute;
    final sunsetStartMinutes = sunsetStart.hour * 60 + sunsetStart.minute;
    final sunsetEndMinutes = sunsetEnd.hour * 60 + sunsetEnd.minute;

    if (currentMinutes >= sunriseStartMinutes && currentMinutes <= sunriseEndMinutes) {
      return 'Sunrise in progress$locationStatus';
    } else if (currentMinutes >= sunsetStartMinutes && currentMinutes <= sunsetEndMinutes) {
      return 'Sunset in progress$locationStatus';
    } else if (currentMinutes > sunriseEndMinutes && currentMinutes < sunsetStartMinutes) {
      // Calculate day progress for more detailed status
      final dayProgress = (currentMinutes - sunriseEndMinutes) / (sunsetStartMinutes - sunriseEndMinutes);

      if (dayProgress < 0.3) {
        return 'Morning - Full brightness$locationStatus';
      } else if (dayProgress < 0.7) {
        return 'Midday - Full brightness$locationStatus';
      } else {
        return 'Late afternoon - Warm light$locationStatus';
      }
    } else {
      return 'Night time - Off$locationStatus';
    }
  }
  
  // Update sunrise/sunset times (for future location-based feature)
  void updateTimes({TimeOfDay? sunrise, TimeOfDay? sunset}) {
    if (sunrise != null) sunriseTime = sunrise;
    if (sunset != null) sunsetTime = sunset;
    
    // If enabled, restart timer to apply new times immediately
    if (_isEnabled) {
      _startTimer();
    }
  }
  
  void dispose() {
    _stopTimer();
  }
}
