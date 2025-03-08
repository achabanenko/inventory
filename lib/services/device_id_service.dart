import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'dart:io';

/// Service for retrieving and managing device identification
class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._internal();

  // Singleton pattern
  factory DeviceIdService() {
    return _instance;
  }

  DeviceIdService._internal();

  String _deviceId = 'unknown_device';
  bool _initialized = false;

  /// Get the device ID, initializing it if necessary
  Future<String> getDeviceId() async {
    if (!_initialized) {
      await _initializeDeviceId();
    }
    return _deviceId;
  }

  /// Initialize the device ID by fetching from the device
  Future<void> _initializeDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isIOS) {
        // For iOS devices
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
      } else if (Platform.isAndroid) {
        // For Android devices
        final androidIdPlugin = const AndroidId();
        final androidId = await androidIdPlugin.getId();
        _deviceId = androidId ?? 'unknown_android_device';
      } else {
        // For other platforms (web, desktop, etc.)
        if (kIsWeb) {
          _deviceId = 'web_browser';
        } else {
          _deviceId = 'unknown_platform';
        }
      }

      _initialized = true;
      debugPrint('Device ID initialized: $_deviceId');
    } catch (e) {
      debugPrint('Error initializing device ID: $e');
      _deviceId = 'error_device_${DateTime.now().millisecondsSinceEpoch}';
      _initialized = true;
    }
  }
}
