import 'dart:async';
import 'package:flutter/material.dart';
import 'esp_connection.dart';

class SunriseSunsetManager {
  SunriseSunsetManager._();
  static final SunriseSunsetManager I = SunriseSunsetManager._();

  Timer? _timer;
  bool _isEnabled = false;
  bool _testModeEnabled = false;
  bool _isTestSequenceRunning = false;
  
  // Hardcoded times for testing - will be replaced with location-based later
  TimeOfDay sunriseTime = const TimeOfDay(hour: 6, minute: 30);
  TimeOfDay sunsetTime = const TimeOfDay(hour: 19, minute: 0); // 7 PM
  
  bool get isEnabled => _isEnabled;
  bool get testModeEnabled => _testModeEnabled;
  bool get isTestSequenceRunning => _isTestSequenceRunning;
  
  void enable() {
    if (_isEnabled) return;
    _isEnabled = true;
    _startTimer();
    debugPrint('SunriseSunsetManager: Enabled');
  }
  
  void disable() {
    if (!_isEnabled) return;
    _isEnabled = false;
    _stopTimer();
    _isTestSequenceRunning = false;
    debugPrint('SunriseSunsetManager: Disabled');
  }
  
  void enableTestMode() {
    _testModeEnabled = true;
    debugPrint('SunriseSunsetManager: Test mode enabled');
    if (_isEnabled) {
      _startTimer(); // Restart with new timing
    }
  }
  
  void disableTestMode() {
    _testModeEnabled = false;
    _isTestSequenceRunning = false;
    debugPrint('SunriseSunsetManager: Test mode disabled');
    if (_isEnabled) {
      _startTimer(); // Restart with normal timing
    }
  }
  
  // Trigger a complete test cycle: sunrise → wait → sunset
  Future<void> startTestCycle() async {
    if (!_isEnabled || _isTestSequenceRunning) return;
    
    _isTestSequenceRunning = true;
    debugPrint('Starting complete test cycle: sunrise → wait → sunset...');
    
    try {
      // === PHASE 1: Sunrise (3 minutes) ===
      debugPrint('Phase 1: Starting sunrise sequence...');
      EspConnection.I.setOn(false);
      await Future.delayed(const Duration(seconds: 2));
      
      // Gradual sunrise over 3 minutes (180 seconds)
      const sunriseSteps = 36; // Update every 5 seconds
      for (int i = 0; i <= sunriseSteps; i++) {
        if (!_isTestSequenceRunning) return;
        
        final progress = i / sunriseSteps;
        final brightness = (15 * _smoothStep(progress)).round();
        
        EspConnection.I.setOn(true);
        EspConnection.I.setMode(2); // MODE_BOTH (warm + white)
        EspConnection.I.setBrightness(brightness);
        
        debugPrint('Sunrise: step $i/$sunriseSteps, brightness=$brightness');
        
        if (i < sunriseSteps) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
      
      if (!_isTestSequenceRunning) return;
      debugPrint('Phase 1 complete: Sunrise finished');
      
      // === PHASE 2: Wait Period (5 minutes) ===
      debugPrint('Phase 2: Waiting at full brightness...');
      EspConnection.I.setMode(2); // Keep both LEDs on
      EspConnection.I.setBrightness(15); // Full brightness
      
      // Wait for 5 minutes (300 seconds), checking every 10 seconds
      for (int i = 0; i < 30; i++) {
        if (!_isTestSequenceRunning) return;
        await Future.delayed(const Duration(seconds: 10));
        debugPrint('Wait phase: ${(i + 1) * 10}/300 seconds');
      }
      
      if (!_isTestSequenceRunning) return;
      debugPrint('Phase 2 complete: Wait period finished');
      
      // === PHASE 3: Sunset (3 minutes) ===
      debugPrint('Phase 3: Starting sunset sequence...');
      
      // Switch to warm only
      EspConnection.I.setMode(0); // MODE_WARM only
      EspConnection.I.setBrightness(15); // Start at full brightness
      await Future.delayed(const Duration(seconds: 3));
      
      // Gradual sunset over 3 minutes (180 seconds)
      const sunsetSteps = 36; // Update every 5 seconds
      for (int i = 0; i <= sunsetSteps; i++) {
        if (!_isTestSequenceRunning) return;
        
        final progress = i / sunsetSteps;
        final brightness = (15 * (1.0 - _smoothStep(progress))).round();
        
        EspConnection.I.setBrightness(brightness);
        debugPrint('Sunset: step $i/$sunsetSteps, brightness=$brightness');
        
        if (i < sunsetSteps) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
      
      // Turn off at the end
      EspConnection.I.setOn(false);
      debugPrint('Phase 3 complete: Sunset finished');
      
    } catch (e) {
      debugPrint('Test cycle error: $e');
    } finally {
      _isTestSequenceRunning = false;
      debugPrint('Complete test cycle finished! Total duration: ~11 minutes');
    }
  }
  
  void stopTestSequence() {
    _isTestSequenceRunning = false;
    debugPrint('Test sequence stopped');
  }
  
  void _startTimer() {
    _stopTimer();
    // Check every minute for normal mode, every 10 seconds for test mode
    final interval = _testModeEnabled ? const Duration(seconds: 10) : const Duration(minutes: 1);
    _timer = Timer.periodic(interval, (timer) {
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
    if (!_isEnabled || _isTestSequenceRunning) return;
    
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    // Get transition duration based on mode
    final transitionMinutes = _testModeEnabled ? 2 : 15; // 2 minutes for test, 15 for normal
    
    // Calculate transition time windows
    final sunriseStart = _subtractMinutes(sunriseTime, transitionMinutes);
    final sunriseEnd = _addMinutes(sunriseTime, transitionMinutes);
    final sunsetStart = _subtractMinutes(sunsetTime, transitionMinutes);
    final sunsetEnd = _addMinutes(sunsetTime, transitionMinutes);
    
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
    if (_isTestSequenceRunning) return 'Test sequence running...';
    
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    final transitionMinutes = _testModeEnabled ? 2 : 15;
    final sunriseStart = _subtractMinutes(sunriseTime, transitionMinutes);
    final sunriseEnd = _addMinutes(sunriseTime, transitionMinutes);
    final sunsetStart = _subtractMinutes(sunsetTime, transitionMinutes);
    final sunsetEnd = _addMinutes(sunsetTime, transitionMinutes);
    
    final sunriseStartMinutes = sunriseStart.hour * 60 + sunriseStart.minute;
    final sunriseEndMinutes = sunriseEnd.hour * 60 + sunriseEnd.minute;
    final sunsetStartMinutes = sunsetStart.hour * 60 + sunsetStart.minute;
    final sunsetEndMinutes = sunsetEnd.hour * 60 + sunsetEnd.minute;
    
    String baseStatus;
    if (currentMinutes >= sunriseStartMinutes && currentMinutes <= sunriseEndMinutes) {
      baseStatus = 'Sunrise in progress';
    } else if (currentMinutes >= sunsetStartMinutes && currentMinutes <= sunsetEndMinutes) {
      baseStatus = 'Sunset in progress';
    } else if (currentMinutes > sunriseEndMinutes && currentMinutes < sunsetStartMinutes) {
      // Calculate day progress for more detailed status
      final dayProgress = (currentMinutes - sunriseEndMinutes) / (sunsetStartMinutes - sunriseEndMinutes);
      
      if (dayProgress < 0.3) {
        baseStatus = 'Morning - Full brightness (warm + white)';
      } else if (dayProgress < 0.7) {
        baseStatus = 'Midday - Full brightness (warm + white)';
      } else {
        baseStatus = 'Late afternoon - Warm light only';
      }
    } else {
      baseStatus = 'Night time - Off';
    }
    
    return _testModeEnabled ? '$baseStatus (Test Mode)' : baseStatus;
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
