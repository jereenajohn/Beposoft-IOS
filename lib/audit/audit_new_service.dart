import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beposoft/pages/api.dart';

import 'audit_context_service.dart';

/// Common application-wide audit logging service.
///
/// Usage:
///
/// await AuditLogService.log(
///   action: 'bank_created',
///   beforeData: {},
///   afterData: {
///     'name': 'Bank of India',
///   },
/// );
///
/// For order related changes:
///
/// await AuditLogService.log(
///   action: 'order_total_changed',
///   orderId: 17177,
///   beforeData: {
///     'total_amount': 25000,
///   },
///   afterData: {
///     'total_amount': 30000,
///   },
/// );
class AuditLogService {
  AuditLogService._();

  // ============================================================
  // ENDPOINT
  // ============================================================

  static String get _dataLogEndpoint =>
      '$api/api/datalog/create/';

  // ============================================================
  // HTTP TIMEOUT
  // ============================================================

  static const Duration _requestTimeout =
      Duration(seconds: 20);

  // ============================================================
  // GET TOKEN
  // ============================================================

  static Future<String?> _getToken() async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences
              .getInstance();

      final String? token =
          prefs.getString('token');

      if (token == null ||
          token.trim().isEmpty) {
        return null;
      }

      return token.trim();
    } catch (e, stackTrace) {
      debugPrint(
        'AuditLogService token error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return null;
    }
  }

  // ============================================================
  // MAIN LOG METHOD
  // ============================================================

  /// Creates an audit log.
  ///
  /// Returns true only when Django successfully creates
  /// the DataLog record.
  ///
  /// IMPORTANT:
  ///
  /// Audit failure must not throw into the calling business
  /// operation.
  ///
  /// For example:
  ///
  /// Bank successfully created
  /// +
  /// audit failed
  ///
  /// must NOT cause the UI to behave as though the bank
  /// creation itself failed.
  static Future<bool> log({
    required String action,
    Map<String, dynamic> beforeData =
        const <String, dynamic>{},
    Map<String, dynamic> afterData =
        const <String, dynamic>{},
    int? orderId,
  }) async {
    final String normalizedAction =
        action.trim();

    // ==========================================================
    // VALIDATE ACTION
    // ==========================================================

    if (normalizedAction.isEmpty) {
      debugPrint(
        'AuditLogService: '
        'action cannot be empty.',
      );

      return false;
    }

    debugPrint(
      'AuditLogService: '
      'starting [$normalizedAction].',
    );

    try {
      // ========================================================
      // TOKEN
      // ========================================================

      final String? token =
          await _getToken();

      if (token == null) {
        debugPrint(
          'AuditLogService: '
          'authentication token unavailable '
          '[$normalizedAction].',
        );

        return false;
      }

      // ========================================================
      // AUDIT CONTEXT
      // ========================================================

      Map<String, dynamic>
          auditContext;

      try {
        auditContext =
            await AuditContextService
                .collect();
      } catch (e, stackTrace) {
        // This should rarely happen because
        // AuditContextService is already fail-safe.
        //
        // Still, the audit POST must continue.

        debugPrint(
          'AuditLogService: '
          'context collection failed '
          '[$normalizedAction]: $e',
        );

        debugPrint(
          stackTrace.toString(),
        );

        auditContext =
            _emptyAuditContext();
      }

      // ========================================================
      // NORMALIZE BEFORE DATA
      // ========================================================

      final Map<String, dynamic>
          normalizedBeforeData =
          <String, dynamic>{
        'action':
            normalizedAction,
        ...beforeData,
      };

      // ========================================================
      // NORMALIZE AFTER DATA
      // ========================================================

      final Map<String, dynamic>
          normalizedAfterData =
          <String, dynamic>{
        'action':
            normalizedAction,
        ...afterData,
      };

      // ========================================================
      // REQUEST BODY
      // ========================================================

      final Map<String, dynamic>
          requestBody =
          <String, dynamic>{
        'before_data':
            normalizedBeforeData,

        'after_data':
            normalizedAfterData,

        // Explicit audit fields.
        //
        // Null values are intentionally retained.
        //
        // Therefore location permission denial still sends
        // latitude=null, longitude=null, etc.
        'ip_address':
            auditContext[
                'ip_address'],

        'device_id':
            auditContext[
                'device_id'],

        'device_name':
            auditContext[
                'device_name'],

        'platform':
            auditContext[
                'platform'],

        'app_version':
            auditContext[
                'app_version'],

        'latitude':
            auditContext[
                'latitude'],

        'longitude':
            auditContext[
                'longitude'],

        'location_accuracy':
            auditContext[
                'location_accuracy'],

        'location_captured_at':
            auditContext[
                'location_captured_at'],

        'location_name':
            auditContext[
                'location_name'],

        'street':
            auditContext[
                'street'],

        'sub_locality':
            auditContext[
                'sub_locality'],

        'locality':
            auditContext[
                'locality'],

        'district':
            auditContext[
                'district'],

        'state':
            auditContext[
                'state'],

        'postal_code':
            auditContext[
                'postal_code'],

        'country':
            auditContext[
                'country'],

        'country_code':
            auditContext[
                'country_code'],
      };

      // ========================================================
      // ORDER
      // ========================================================

      if (orderId != null) {
        requestBody['order'] =
            orderId;
      }

      // ========================================================
      // DEBUG SUMMARY
      // ========================================================

      debugPrint(
        'AuditLogService: '
        'payload ready '
        '[$normalizedAction].',
      );

      debugPrint(
        'AuditLogService: '
        'device_id='
        '${requestBody['device_id']}, '
        'platform='
        '${requestBody['platform']}, '
        'latitude='
        '${requestBody['latitude']}, '
        'longitude='
        '${requestBody['longitude']}, '
        'accuracy='
        '${requestBody['location_accuracy']}',
      );

      // Do NOT print the Bearer token.
      //
      // Also avoid printing the complete before/after payload
      // in production because it can contain business/customer
      // information.

      // ========================================================
      // CREATE DATA LOG
      // ========================================================

      debugPrint(
        'AuditLogService: '
        'POST starting '
        '[$normalizedAction].',
      );

      final http.Response response =
          await http
              .post(
                Uri.parse(
                  _dataLogEndpoint,
                ),
                headers: <String, String>{
                  'Authorization':
                      'Bearer $token',

                  'Content-Type':
                      'application/json',

                  'Accept':
                      'application/json',
                },
                body: jsonEncode(
                  requestBody,
                ),
              )
              .timeout(
                _requestTimeout,
              );

      // ========================================================
      // SUCCESS
      // ========================================================

      if (response.statusCode == 201) {
        debugPrint(
          'AuditLogService: '
          '$normalizedAction '
          'logged successfully.',
        );

        return true;
      }

      // ========================================================
      // FAILED RESPONSE
      // ========================================================

      debugPrint(
        'AuditLogService failed '
        '[$normalizedAction]. '
        'Status: '
        '${response.statusCode}.',
      );

      debugPrint(
        'AuditLogService server response '
        '[$normalizedAction]: '
        '${response.body}',
      );

      return false;
    } on TimeoutException catch (
        e,
        stackTrace) {
      debugPrint(
        'AuditLogService timeout '
        '[$normalizedAction]: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint(
        'AuditLogService exception '
        '[$normalizedAction]: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return false;
    }
  }

  // ============================================================
  // EMPTY AUDIT CONTEXT
  // ============================================================

  /// Emergency fallback.
  ///
  /// Even if AuditContextService unexpectedly fails completely,
  /// the audit POST can still be attempted.
  static Map<String, dynamic>
      _emptyAuditContext() {
    return <String, dynamic>{
      'ip_address': null,
      'device_id': null,
      'device_name': null,
      'platform': null,
      'app_version': null,

      'latitude': null,
      'longitude': null,
      'location_accuracy': null,
      'location_captured_at': null,

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
  // LOG CREATE ACTION
  // ============================================================

  /// Convenience method for CREATE operations.
  ///
  /// before_data will automatically contain only the action.
  static Future<bool> logCreate({
    required String action,
    required Map<String, dynamic>
        afterData,
    int? orderId,
  }) async {
    return log(
      action: action,
      orderId: orderId,
      beforeData:
          const <String, dynamic>{},
      afterData: afterData,
    );
  }

  // ============================================================
  // LOG UPDATE ACTION
  // ============================================================

  /// Convenience method for UPDATE operations.
  static Future<bool> logUpdate({
    required String action,
    required Map<String, dynamic>
        beforeData,
    required Map<String, dynamic>
        afterData,
    int? orderId,
  }) async {
    return log(
      action: action,
      orderId: orderId,
      beforeData: beforeData,
      afterData: afterData,
    );
  }

  // ============================================================
  // LOG DELETE ACTION
  // ============================================================

  /// Convenience method for DELETE operations.
  ///
  /// after_data will automatically contain only the action.
  static Future<bool> logDelete({
    required String action,
    required Map<String, dynamic>
        beforeData,
    int? orderId,
  }) async {
    return log(
      action: action,
      orderId: orderId,
      beforeData: beforeData,
      afterData:
          const <String, dynamic>{},
    );
  }
}