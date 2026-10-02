import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'installation_id_service.dart';

/// Collects supporting audit evidence from the Flutter application.
///
/// This service collects:
/// - Installation ID
/// - Device name/model
/// - Platform
/// - App version
/// - Public IP address
/// - Latitude
/// - Longitude
/// - Location accuracy
/// - Location capture timestamp
/// - Human-readable location details
///
/// IMPORTANT:
///
/// Device/location/IP information supplied by Flutter should be
/// considered supporting evidence.
///
/// The Django backend should remain authoritative for:
/// - Authenticated user
/// - Server timestamp
/// - Actual before/after database values
/// - Server-observed IP where possible
///
/// CRITICAL:
///
/// Failure of GPS, permission, reverse geocoding, IP lookup,
/// device information, or package information must NEVER prevent
/// the audit log itself from being created.
class AuditContextService {
  AuditContextService._();

  // ============================================================
  // PUBLIC IP ENDPOINT
  // ============================================================

  static const String _publicIpEndpoint =
      'https://api.ipify.org?format=json';

  // ============================================================
  // TIMEOUTS
  // ============================================================

  static const Duration _ipTimeout =
      Duration(seconds: 5);

  static const Duration _locationTimeout =
      Duration(seconds: 12);

  static const Duration _geocodingTimeout =
      Duration(seconds: 8);

  // ============================================================
  // DEFAULT AUDIT CONTEXT
  // ============================================================

  /// Always returns the complete audit structure.
  ///
  /// If location permission is denied, GPS is unavailable,
  /// location service is disabled, or geocoding fails,
  /// the affected fields remain null.
  ///
  /// This allows the audit API call itself to continue.
  static Map<String, dynamic> _defaultContext() {
    return <String, dynamic>{
      'device_id': null,
      'device_name': null,
      'platform': null,
      'app_version': null,
      'ip_address': null,

      // Raw GPS evidence
      'latitude': null,
      'longitude': null,
      'location_accuracy': null,
      'location_captured_at': null,

      // Human-readable location
      'location_name': null,
      'street': null,
      'sub_locality': null,
      'locality': null,
      'district': null,
      'state': null,
      'postal_code': null,
      'country': null,
      'country_code': null,
    };
  }

  // ============================================================
  // MAIN COLLECT METHOD
  // ============================================================

  /// Collects all available audit context.
  ///
  /// Every metadata source is isolated so that one failure does
  /// not prevent the remaining audit evidence from being
  /// collected.
  ///
  /// Examples:
  ///
  /// Device info failure:
  /// audit continues.
  ///
  /// IP lookup failure:
  /// audit continues.
  ///
  /// Location denied:
  /// audit continues with null location fields.
  ///
  /// GPS timeout:
  /// audit continues with null location fields or last known
  /// position when available.
  ///
  /// Reverse geocoding failure:
  /// audit continues with raw latitude/longitude.
  static Future<Map<String, dynamic>> collect() async {
    final Map<String, dynamic> context =
        _defaultContext();

    debugPrint(
      'AuditContextService: collection started.',
    );

    // ==========================================================
    // INSTALLATION ID
    // ==========================================================

    try {
      final String deviceId =
          await InstallationIdService.getId();

      final String normalizedDeviceId =
          deviceId.trim();

      if (normalizedDeviceId.isNotEmpty) {
        context['device_id'] =
            normalizedDeviceId;
      }

      debugPrint(
        'AuditContextService: '
        'installation ID collected.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'installation ID error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    // ==========================================================
    // DEVICE INFORMATION
    // ==========================================================

    try {
      final Map<String, dynamic>
          deviceInformation =
          await _getDeviceInformation();

      context['device_name'] =
          deviceInformation['device_name'];

      context['platform'] =
          deviceInformation['platform'];

      debugPrint(
        'AuditContextService: '
        'device information collected.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'device information error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    // ==========================================================
    // APP VERSION
    // ==========================================================

    try {
      final String appVersion =
          await _getAppVersion();

      context['app_version'] =
          appVersion;

      debugPrint(
        'AuditContextService: '
        'app version collected.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'app version error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    // ==========================================================
    // PUBLIC IP
    // ==========================================================

    try {
      final String? ipAddress =
          await _getPublicIpAddress();

      context['ip_address'] =
          ipAddress;

      debugPrint(
        'AuditContextService: '
        'public IP collection completed.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'public IP error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    // ==========================================================
    // GPS LOCATION
    // ==========================================================

    Position? position;

    try {
      position =
          await _getCurrentLocation();

      if (position != null) {
        // ------------------------------------------------------
        // IMPORTANT:
        //
        // Django uses:
        //
        // DecimalField(
        //   max_digits=9,
        //   decimal_places=6,
        // )
        //
        // Mobile GPS may return values such as:
        //
        // 9.9040488
        // 76.8024015
        //
        // DRF rejects these because they contain more than
        // 6 decimal places.
        //
        // Therefore normalize them BEFORE sending them.
        // ------------------------------------------------------

        final double normalizedLatitude =
            double.parse(
          position.latitude.toStringAsFixed(6),
        );

        final double normalizedLongitude =
            double.parse(
          position.longitude.toStringAsFixed(6),
        );

        context['latitude'] =
            normalizedLatitude;

        context['longitude'] =
            normalizedLongitude;

        context['location_accuracy'] =
            position.accuracy;

        // Use the timestamp belonging to the position itself.
        context['location_captured_at'] =
            position.timestamp
                .toUtc()
                .toIso8601String();

        debugPrint(
          'AuditContextService: '
          'GPS collected. '
          'lat=$normalizedLatitude, '
          'lng=$normalizedLongitude, '
          'accuracy=${position.accuracy}',
        );
      } else {
        debugPrint(
          'AuditContextService: '
          'GPS unavailable. '
          'Audit will continue without GPS.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'GPS collection error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      // Keep GPS fields null.
      // Audit creation must continue.
    }

    // ==========================================================
    // REVERSE GEOCODING
    // ==========================================================

    if (position != null) {
      try {
        // Use original device coordinates here.
        //
        // The 6-decimal normalization is required only for the
        // Django DecimalField payload. There is no reason to
        // reduce precision before reverse geocoding.
        final Map<String, dynamic>?
            locationDetails =
            await _getLocationDetails(
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (locationDetails != null) {
          context['location_name'] =
              locationDetails[
                  'location_name'];

          context['street'] =
              locationDetails['street'];

          context['sub_locality'] =
              locationDetails[
                  'sub_locality'];

          context['locality'] =
              locationDetails['locality'];

          context['district'] =
              locationDetails['district'];

          context['state'] =
              locationDetails['state'];

          context['postal_code'] =
              locationDetails[
                  'postal_code'];

          context['country'] =
              locationDetails['country'];

          context['country_code'] =
              locationDetails[
                  'country_code'];

          debugPrint(
            'AuditContextService: '
            'reverse geocoding completed.',
          );
        } else {
          debugPrint(
            'AuditContextService: '
            'reverse geocoding unavailable. '
            'Raw GPS will still be used.',
          );
        }
      } catch (e, stackTrace) {
        debugPrint(
          'AuditContextService '
          'reverse geocoding error: $e',
        );

        debugPrint(
          stackTrace.toString(),
        );

        // Raw GPS remains available.
        // Human-readable address fields remain null.
      }
    }

    // ==========================================================
    // COMPLETED
    // ==========================================================

    debugPrint(
      'AuditContextService: '
      'collection completed.',
    );

    return context;
  }

  // ============================================================
  // DEVICE INFORMATION
  // ============================================================

  static Future<Map<String, dynamic>>
      _getDeviceInformation() async {
    try {
      final DeviceInfoPlugin deviceInfo =
          DeviceInfoPlugin();

      // ========================================================
      // ANDROID
      // ========================================================

      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo =
            await deviceInfo.androidInfo;

        final String manufacturer =
            androidInfo.manufacturer.trim();

        final String model =
            androidInfo.model.trim();

        String deviceName;

        if (manufacturer.isNotEmpty &&
            model.isNotEmpty) {
          deviceName =
              '$manufacturer $model';
        } else if (model.isNotEmpty) {
          deviceName =
              model;
        } else {
          deviceName =
              'Android Device';
        }

        return <String, dynamic>{
          'device_name':
              deviceName,
          'platform':
              'android',
        };
      }

      // ========================================================
      // IOS
      // ========================================================

      if (Platform.isIOS) {
        final IosDeviceInfo iosInfo =
            await deviceInfo.iosInfo;

        String deviceName =
            iosInfo.name.trim();

        if (deviceName.isEmpty) {
          deviceName =
              iosInfo
                  .utsname
                  .machine
                  .trim();
        }

        if (deviceName.isEmpty) {
          deviceName =
              'iOS Device';
        }

        return <String, dynamic>{
          'device_name':
              deviceName,
          'platform':
              'ios',
        };
      }

      // ========================================================
      // MACOS
      // ========================================================

      if (Platform.isMacOS) {
        final MacOsDeviceInfo macInfo =
            await deviceInfo.macOsInfo;

        String deviceName =
            macInfo.computerName.trim();

        if (deviceName.isEmpty) {
          deviceName =
              'macOS Device';
        }

        return <String, dynamic>{
          'device_name':
              deviceName,
          'platform':
              'macos',
        };
      }

      // ========================================================
      // WINDOWS
      // ========================================================

      if (Platform.isWindows) {
        final WindowsDeviceInfo windowsInfo =
            await deviceInfo.windowsInfo;

        String deviceName =
            windowsInfo
                .computerName
                .trim();

        if (deviceName.isEmpty) {
          deviceName =
              'Windows Device';
        }

        return <String, dynamic>{
          'device_name':
              deviceName,
          'platform':
              'windows',
        };
      }

      // ========================================================
      // LINUX
      // ========================================================

      if (Platform.isLinux) {
        final LinuxDeviceInfo linuxInfo =
            await deviceInfo.linuxInfo;

        String deviceName =
            linuxInfo.prettyName.trim();

        if (deviceName.isEmpty) {
          deviceName =
              'Linux Device';
        }

        return <String, dynamic>{
          'device_name':
              deviceName,
          'platform':
              'linux',
        };
      }

      // ========================================================
      // UNKNOWN PLATFORM
      // ========================================================

      return <String, dynamic>{
        'device_name':
            'Unknown Device',
        'platform':
            Platform.operatingSystem,
      };
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'device info error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return <String, dynamic>{
        'device_name':
            'Unknown Device',
        'platform':
            Platform.operatingSystem,
      };
    }
  }

  // ============================================================
  // APP VERSION
  // ============================================================

  static Future<String>
      _getAppVersion() async {
    try {
      final PackageInfo packageInfo =
          await PackageInfo
              .fromPlatform();

      final String version =
          packageInfo.version.trim();

      if (version.isEmpty) {
        return 'unknown';
      }

      return version;
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'app version error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return 'unknown';
    }
  }

  // ============================================================
  // PUBLIC IP ADDRESS
  // ============================================================

  static Future<String?>
      _getPublicIpAddress() async {
    try {
      final Uri uri =
          Uri.parse(
        _publicIpEndpoint,
      );

      final http.Response response =
          await http
              .get(
                uri,
                headers:
                    const <String, String>{
                  'Accept':
                      'application/json',
                },
              )
              .timeout(
                _ipTimeout,
              );

      if (response.statusCode != 200) {
        debugPrint(
          'AuditContextService '
          'IP request failed. '
          'Status: '
          '${response.statusCode}',
        );

        return null;
      }

      final dynamic decoded =
          jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        debugPrint(
          'AuditContextService: '
          'invalid IP response.',
        );

        return null;
      }

      final dynamic ipValue =
          decoded['ip'];

      if (ipValue == null) {
        return null;
      }

      final String ip =
          ipValue
              .toString()
              .trim();

      if (ip.isEmpty) {
        return null;
      }

      return ip;
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'IP error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return null;
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  static Future<Position?>
      _getCurrentLocation() async {
    try {
      // ========================================================
      // CHECK LOCATION SERVICE
      // ========================================================

      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          'AuditContextService: '
          'location service disabled. '
          'Continuing without location.',
        );

        return null;
      }

      // ========================================================
      // CHECK PERMISSION
      // ========================================================

      LocationPermission permission =
          await Geolocator
              .checkPermission();

      debugPrint(
        'AuditContextService: '
        'location permission before request: '
        '$permission',
      );

      // ========================================================
      // REQUEST PERMISSION
      // ========================================================

      if (permission ==
          LocationPermission.denied) {
        try {
          permission =
              await Geolocator
                  .requestPermission();

          debugPrint(
            'AuditContextService: '
            'location permission after request: '
            '$permission',
          );
        } catch (e, stackTrace) {
          debugPrint(
            'AuditContextService '
            'permission request error: $e',
          );

          debugPrint(
            stackTrace.toString(),
          );

          return null;
        }
      }

      // ========================================================
      // PERMISSION DENIED
      // ========================================================

      if (permission ==
          LocationPermission.denied) {
        debugPrint(
          'AuditContextService: '
          'location permission denied. '
          'Continuing without location.',
        );

        return null;
      }

      // ========================================================
      // PERMISSION PERMANENTLY DENIED
      // ========================================================

      if (permission ==
          LocationPermission.deniedForever) {
        debugPrint(
          'AuditContextService: '
          'location permission permanently denied. '
          'Continuing without location.',
        );

        return null;
      }

      // ========================================================
      // GET CURRENT POSITION
      // ========================================================

      try {
        final Position position =
            await Geolocator
                .getCurrentPosition(
          locationSettings:
              const LocationSettings(
            accuracy:
                LocationAccuracy.high,
            timeLimit:
                _locationTimeout,
          ),
        );

        debugPrint(
          'AuditContextService: '
          'location received. '
          'lat=${position.latitude}, '
          'lng=${position.longitude}, '
          'accuracy=${position.accuracy}',
        );

        return position;
      } catch (e, stackTrace) {
        debugPrint(
          'AuditContextService: '
          'current position failed: $e',
        );

        debugPrint(
          stackTrace.toString(),
        );

        // ======================================================
        // FALLBACK TO LAST KNOWN POSITION
        // ======================================================
        //
        // If permission exists but the device cannot obtain a
        // fresh GPS position within the timeout, try the most
        // recent cached position.
        //
        // The location_accuracy field is still stored so the
        // quality of the location remains visible in the audit.

        try {
          final Position? lastPosition =
              await Geolocator
                  .getLastKnownPosition();

          if (lastPosition != null) {
            debugPrint(
              'AuditContextService: '
              'using last known location. '
              'lat=${lastPosition.latitude}, '
              'lng=${lastPosition.longitude}, '
              'accuracy=${lastPosition.accuracy}',
            );

            return lastPosition;
          }

          debugPrint(
            'AuditContextService: '
            'no last known location available.',
          );
        } catch (
            fallbackError,
            fallbackStackTrace) {
          debugPrint(
            'AuditContextService: '
            'last known position failed: '
            '$fallbackError',
          );

          debugPrint(
            fallbackStackTrace
                .toString(),
          );
        }

        return null;
      }
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'location error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return null;
    }
  }

  // ============================================================
  // REVERSE GEOCODING
  // ============================================================

  /// Converts latitude/longitude into human-readable location.
  ///
  /// Reverse geocoding is supporting metadata only.
  ///
  /// Failure here must never remove the original GPS evidence.
  static Future<Map<String, dynamic>?>
      _getLocationDetails({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final List<Placemark> placemarks =
          await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(
        _geocodingTimeout,
      );

      if (placemarks.isEmpty) {
        debugPrint(
          'AuditContextService: '
          'reverse geocoding returned '
          'no placemarks.',
        );

        return null;
      }

      final Placemark place =
          placemarks.first;

      // ========================================================
      // STREET
      // ========================================================

      final String? street =
          _normalizeLocationValue(
        place.street,
      );

      // ========================================================
      // SUB LOCALITY
      // ========================================================

      final String? subLocality =
          _normalizeLocationValue(
        place.subLocality,
      );

      // ========================================================
      // LOCALITY
      // ========================================================

      final String? locality =
          _normalizeLocationValue(
        place.locality,
      );

      // ========================================================
      // DISTRICT
      // ========================================================

      final String? district =
          _normalizeLocationValue(
        place.subAdministrativeArea,
      );

      // ========================================================
      // STATE
      // ========================================================

      final String? state =
          _normalizeLocationValue(
        place.administrativeArea,
      );

      // ========================================================
      // POSTAL CODE
      // ========================================================

      final String? postalCode =
          _normalizeLocationValue(
        place.postalCode,
      );

      // ========================================================
      // COUNTRY
      // ========================================================

      final String? country =
          _normalizeLocationValue(
        place.country,
      );

      // ========================================================
      // COUNTRY CODE
      // ========================================================

      final String? countryCode =
          _normalizeLocationValue(
        place.isoCountryCode,
      )?.toUpperCase();

      // ========================================================
      // LOCATION NAME
      // ========================================================

      final String locationName =
          _buildLocationName(
        street: street,
        subLocality: subLocality,
        locality: locality,
        district: district,
        state: state,
        postalCode: postalCode,
        country: country,
      );

      // ========================================================
      // RESULT
      // ========================================================

      return <String, dynamic>{
        'location_name':
            locationName.isNotEmpty
                ? locationName
                : null,

        'street':
            street,

        'sub_locality':
            subLocality,

        'locality':
            locality,

        'district':
            district,

        'state':
            state,

        'postal_code':
            postalCode,

        'country':
            country,

        'country_code':
            countryCode,
      };
    } catch (e, stackTrace) {
      debugPrint(
        'AuditContextService '
        'reverse geocoding error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      // Reverse geocoding is optional supporting evidence.
      //
      // Returning null here must NOT prevent latitude and
      // longitude from being included in the audit.
      return null;
    }
  }

  // ============================================================
  // LOCATION VALUE NORMALIZATION
  // ============================================================

  static String?
      _normalizeLocationValue(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    final String normalized =
        value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  // ============================================================
  // HUMAN-READABLE LOCATION BUILDER
  // ============================================================

  static String _buildLocationName({
    String? street,
    String? subLocality,
    String? locality,
    String? district,
    String? state,
    String? postalCode,
    String? country,
  }) {
    final List<String> parts =
        <String>[];

    void addUnique(
      String? value,
    ) {
      if (value == null ||
          value.trim().isEmpty) {
        return;
      }

      final String normalized =
          value.trim();

      final bool alreadyExists =
          parts.any(
        (String existing) =>
            existing
                .toLowerCase() ==
            normalized
                .toLowerCase(),
      );

      if (!alreadyExists) {
        parts.add(
          normalized,
        );
      }
    }

    addUnique(
      street,
    );

    addUnique(
      subLocality,
    );

    addUnique(
      locality,
    );

    addUnique(
      district,
    );

    addUnique(
      state,
    );

    addUnique(
      postalCode,
    );

    addUnique(
      country,
    );

    return parts.join(', ');
  }
}