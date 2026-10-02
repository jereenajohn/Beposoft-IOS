import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Manages a persistent installation identifier for this
/// Beposoft application installation.
///
/// IMPORTANT:
/// This is NOT:
/// - IMEI
/// - Android hardware ID
/// - MAC address
/// - Device serial number
///
/// It is an application-generated UUID stored securely.
///
/// Example:
/// beposoft_1c246f8e-9e22-4f90-9c14-8a4fdaf0e713
class InstallationIdService {
  InstallationIdService._();

  // ============================================================
  // SECURE STORAGE
  // ============================================================

  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  // ============================================================
  // STORAGE KEY
  // ============================================================

  static const String _installationIdKey =
      'beposoft_installation_id';

  // ============================================================
  // UUID GENERATOR
  // ============================================================

  static const Uuid _uuid = Uuid();

  // ============================================================
  // GET INSTALLATION ID
  // ============================================================

  /// Returns the existing installation ID.
  ///
  /// If one does not exist, a new ID is generated and stored.
  static Future<String> getId() async {
    try {
      // ----------------------------------------------------------
      // Check existing ID
      // ----------------------------------------------------------

      final String? existingId =
          await _secureStorage.read(
        key: _installationIdKey,
      );

      if (existingId != null &&
          existingId.trim().isNotEmpty) {
        return existingId.trim();
      }

      // ----------------------------------------------------------
      // Generate new installation ID
      // ----------------------------------------------------------

      final String newId =
          'beposoft_${_uuid.v4()}';

      // ----------------------------------------------------------
      // Store securely
      // ----------------------------------------------------------

      await _secureStorage.write(
        key: _installationIdKey,
        value: newId,
      );

      debugPrint(
        'InstallationIdService: '
        'new installation ID generated.',
      );

      return newId;
    } catch (e, stackTrace) {
      debugPrint(
        'InstallationIdService error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      // We don't want audit metadata collection
      // to crash the business operation.
      //
      // Returning "unknown" means the audit can
      // still be created without a device ID.
      return 'unknown';
    }
  }

  // ============================================================
  // CHECK IF ID EXISTS
  // ============================================================

  static Future<bool> exists() async {
    try {
      final String? existingId =
          await _secureStorage.read(
        key: _installationIdKey,
      );

      return existingId != null &&
          existingId.trim().isNotEmpty;
    } catch (e) {
      debugPrint(
        'InstallationIdService exists error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // READ WITHOUT GENERATING
  // ============================================================

  static Future<String?> readExistingId() async {
    try {
      final String? existingId =
          await _secureStorage.read(
        key: _installationIdKey,
      );

      if (existingId == null ||
          existingId.trim().isEmpty) {
        return null;
      }

      return existingId.trim();
    } catch (e) {
      debugPrint(
        'InstallationIdService read error: $e',
      );

      return null;
    }
  }
}