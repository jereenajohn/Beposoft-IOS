import 'dart:convert';

import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffMonthlySalaryPage extends StatefulWidget {
  const StaffMonthlySalaryPage({super.key});

  @override
  State<StaffMonthlySalaryPage> createState() =>
      _StaffMonthlySalaryPageState();
}

class _StaffMonthlySalaryPageState extends State<StaffMonthlySalaryPage> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController searchController = TextEditingController();
  final TextEditingController bonusController = TextEditingController();
  final TextEditingController incentivesController = TextEditingController();
  final TextEditingController lateComesController = TextEditingController();
  final TextEditingController finesController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  // ============================================================
  // STAFF DATA
  // ============================================================

  List<Map<String, dynamic>> sta = [];

  int totalCount = 0;
  int currentPage = 1;

  String? nextPageUrl;
  String? previousPageUrl;

  bool hasNextPage = false;
  bool isStaffLoading = false;
  bool isPaginationLoading = false;

  // ============================================================
  // STAFF SELECTION
  // ============================================================

  Map<String, dynamic>? selectedStaff;

  // ============================================================
  // YEAR / MONTH
  // ============================================================

  late int selectedYear;
  late int selectedMonth;
  late List<int> availableYears;

  final List<Map<String, dynamic>> months = const [
    {'value': 1, 'name': 'January', 'short': 'Jan'},
    {'value': 2, 'name': 'February', 'short': 'Feb'},
    {'value': 3, 'name': 'March', 'short': 'Mar'},
    {'value': 4, 'name': 'April', 'short': 'Apr'},
    {'value': 5, 'name': 'May', 'short': 'May'},
    {'value': 6, 'name': 'June', 'short': 'Jun'},
    {'value': 7, 'name': 'July', 'short': 'Jul'},
    {'value': 8, 'name': 'August', 'short': 'Aug'},
    {'value': 9, 'name': 'September', 'short': 'Sep'},
    {'value': 10, 'name': 'October', 'short': 'Oct'},
    {'value': 11, 'name': 'November', 'short': 'Nov'},
    {'value': 12, 'name': 'December', 'short': 'Dec'},
  ];

  // ============================================================
  // SALARY CALCULATION DATA
  // ============================================================

  bool isSalaryLoading = false;
  String? salaryError;

  Map<String, dynamic>? salaryResponse;
  Map<String, dynamic>? staffData;
  Map<String, dynamic>? salaryData;
  Map<String, dynamic>? attendanceData;
  Map<String, dynamic>? paidLeaveData;
  Map<String, dynamic>? deductionsData;

  String payableSalary = '0.00';

  // ============================================================
  // MONTHLY SALARY SAVE / UPDATE
  // ============================================================

  int? monthlySalaryId;
  bool isMonthlySalaryLoading = false;
  bool isSavingSalary = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedYear = now.year;
    selectedMonth = now.month;

    // React page: current year - 10 through current year + 1.
    availableYears = List.generate(
      12,
      (index) => now.year - 10 + index,
    );

    getstaff(isInitial: true);
  }

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String?> gettokenFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    debugPrint(
      'AUTH TOKEN: ${token == null || token.isEmpty ? 'MISSING' : 'AVAILABLE'}',
    );

    return token;
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ============================================================
  // STAFF URI
  // ============================================================

  Uri _buildStaffUri({int? page}) {
    final queryParams = <String, String>{};

    if (page != null) {
      queryParams['page'] = page.toString();
    }

    if (searchController.text.trim().isNotEmpty) {
      queryParams['search'] = searchController.text.trim();
    }

    // Kept from the existing Flutter page because this is the working
    // paginated staff endpoint used by the mobile app.
    return Uri.parse('$api/api/get/staffs/').replace(
      queryParameters: queryParams,
    );
  }

  // ============================================================
  // GET STAFF
  // ============================================================

  Future<void> getstaff({
    bool isInitial = false,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      if (!hasNextPage || nextPageUrl == null || isPaginationLoading) {
        return;
      }
    }

    try {
      final token = await gettokenFromPrefs();

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        _showMessage(
          'Authentication token not found.',
          isError: true,
        );
        return;
      }

      if (!loadMore) {
        setState(() {
          isStaffLoading = true;
          currentPage = 1;
          nextPageUrl = null;
          previousPageUrl = null;
          hasNextPage = false;

          if (isInitial || sta.isNotEmpty) {
            sta = [];
          }
        });
      } else {
        setState(() {
          isPaginationLoading = true;
        });
      }

      final Uri requestUri =
          loadMore && nextPageUrl != null
              ? Uri.parse(nextPageUrl!)
              : _buildStaffUri(page: 1);

      debugPrint('========== GET STAFF LIST ==========');
      debugPrint('URL: $requestUri');

      final response = await http.get(
        requestUri,
        headers: _authHeaders(token),
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('====================================');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractBackendMessage(
            response.body,
            fallback: 'Failed to fetch staff list.',
          ),
        );
      }

      final dynamic parsed = jsonDecode(response.body);

      if (parsed is! Map) {
        throw Exception('Invalid staff API response.');
      }

      totalCount =
          int.tryParse(parsed['count']?.toString() ?? '0') ?? 0;

      nextPageUrl = parsed['next']?.toString();
      previousPageUrl = parsed['previous']?.toString();
      hasNextPage = nextPageUrl != null && nextPageUrl!.isNotEmpty;

      final dynamic results = parsed['results'];
      final dynamic productsData = results is Map ? results['data'] : null;

      final List<dynamic> staffItems =
          productsData is List ? productsData : [];

      final List<Map<String, dynamic>> staffList = [];

      for (final productData in staffItems) {
        if (productData is! Map) continue;

        staffList.add({
          'id': productData['id'],
          'eid': productData['eid'],
          'staff_id': productData['staff_id'],
          'name': productData['name'],
          'username': productData['username'],
          'email': productData['email'],
          'phone': productData['phone'],
          'designation': productData['designation'],
          'department_name': productData['department_name'],
          'supervisor_name': productData['supervisor_name'],
          'family_name': productData['family_name'],
          'image': productData['image'],
          'approval_status': productData['approval_status'],
          'blood_group': productData['blood_group'],
          'allocated_states_names': List<String>.from(
            productData['allocated_states_names'] ?? [],
          ),
          'country_code': productData['country_code'],
          'department_id': productData['department_id'],
          'supervisor_id': productData['supervisor_id'],
          'warehouse_id': productData['warehouse_id'],
          'family': productData['family'],
        });
      }

      if (!mounted) return;

      setState(() {
        if (loadMore) {
          sta.addAll(staffList);
          currentPage += 1;
        } else {
          sta = staffList;
          currentPage = 1;
        }
      });
    } catch (error, stackTrace) {
      debugPrint('GET STAFF ERROR: $error');
      debugPrint('GET STAFF STACKTRACE: $stackTrace');

      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isStaffLoading = false;
          isPaginationLoading = false;
        });
      }
    }
  }

  // ============================================================
  // RESET MONTHLY SALARY FORM
  // ============================================================

  void _resetMonthlySalaryForm() {
    monthlySalaryId = null;
    bonusController.clear();
    incentivesController.clear();
    lateComesController.clear();
    finesController.clear();
    noteController.clear();
  }

  // ============================================================
  // POPULATE MONTHLY SALARY FORM
  // ============================================================

  void _populateMonthlySalaryForm(Map<String, dynamic>? data) {
    if (data == null) {
      _resetMonthlySalaryForm();
      return;
    }

    monthlySalaryId = _toInt(data['id']);

    bonusController.text = _editableValue(data['bonus']);
    incentivesController.text = _editableValue(data['incentives']);
    lateComesController.text = _editableValue(data['late_comes']);
    finesController.text = _editableValue(data['fines']);
    noteController.text = data['note']?.toString() ?? '';
  }

  String _editableValue(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  // ============================================================
  // GET SAVED MONTHLY SALARY
  // LIST -> FIND EXACT RECORD -> DETAIL GET USING ID
  // ============================================================

  Future<Map<String, dynamic>?> fetchSavedMonthlySalary({
    required int staffId,
    required int year,
    required int month,
  }) async {
    try {
      if (mounted) {
        setState(() {
          isMonthlySalaryLoading = true;
        });
      }

      final token = await gettokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found.');
      }

      final listUri = Uri.parse('$api/api/staff/monthly/salary/').replace(
        queryParameters: {
          'staff_id': staffId.toString(),
          'year': year.toString(),
          'month': month.toString(),
        },
      );

      debugPrint('======= GET MONTHLY SALARY LIST =======');
      debugPrint('URL: $listUri');

      final listResponse = await http.get(
        listUri,
        headers: _authHeaders(token),
      );

      debugPrint('STATUS CODE: ${listResponse.statusCode}');
      debugPrint('RESPONSE: ${listResponse.body}');
      debugPrint('=======================================');

      if (listResponse.statusCode == 404) {
        if (mounted) {
          setState(_resetMonthlySalaryForm);
        }
        return null;
      }

      if (listResponse.statusCode < 200 || listResponse.statusCode >= 300) {
        throw Exception(
          _extractBackendMessage(
            listResponse.body,
            fallback: 'Unable to load saved monthly salary.',
          ),
        );
      }

      final dynamic decodedList = jsonDecode(listResponse.body);

      if (decodedList is! Map) {
        throw Exception('Invalid monthly salary list response.');
      }

      if (decodedList['status']?.toString().toLowerCase() != 'success') {
        if (mounted) {
          setState(_resetMonthlySalaryForm);
        }
        return null;
      }

      final dynamic rawRecords = decodedList['data'];
      final List<dynamic> records = rawRecords is List ? rawRecords : [];

      if (records.isEmpty) {
        if (mounted) {
          setState(_resetMonthlySalaryForm);
        }
        return null;
      }

      Map<String, dynamic>? exactRecord;

      for (final item in records) {
        if (item is! Map) continue;

        final map = Map<String, dynamic>.from(item);

        if (_toInt(map['staff']) == staffId &&
            _toInt(map['year']) == year &&
            _toInt(map['month']) == month) {
          exactRecord = map;
          break;
        }
      }

      exactRecord ??= records.first is Map
          ? Map<String, dynamic>.from(records.first as Map)
          : null;

      final recordId = _toInt(exactRecord?['id']);

      if (recordId == null) {
        if (mounted) {
          setState(_resetMonthlySalaryForm);
        }
        return null;
      }

      final detailUri = Uri.parse(
        '$api/api/staff/monthly/salary/$recordId/',
      );

      debugPrint('====== GET MONTHLY SALARY DETAIL ======');
      debugPrint('URL: $detailUri');

      final detailResponse = await http.get(
        detailUri,
        headers: _authHeaders(token),
      );

      debugPrint('STATUS CODE: ${detailResponse.statusCode}');
      debugPrint('RESPONSE: ${detailResponse.body}');
      debugPrint('=======================================');

      if (detailResponse.statusCode == 404) {
        if (mounted) {
          setState(_resetMonthlySalaryForm);
        }
        return null;
      }

      if (detailResponse.statusCode < 200 ||
          detailResponse.statusCode >= 300) {
        throw Exception(
          _extractBackendMessage(
            detailResponse.body,
            fallback: 'Unable to load monthly salary detail.',
          ),
        );
      }

      final dynamic decodedDetail = jsonDecode(detailResponse.body);

      if (decodedDetail is! Map ||
          decodedDetail['status']?.toString().toLowerCase() != 'success' ||
          decodedDetail['data'] is! Map) {
        if (mounted) {
          setState(_resetMonthlySalaryForm);
        }
        return null;
      }

      final savedData = Map<String, dynamic>.from(
        decodedDetail['data'] as Map,
      );

      if (mounted) {
        setState(() {
          _populateMonthlySalaryForm(savedData);
        });
      }

      return savedData;
    } catch (error, stackTrace) {
      debugPrint('SAVED MONTHLY SALARY FETCH ERROR: $error');
      debugPrint('STACKTRACE: $stackTrace');

      if (mounted) {
        setState(_resetMonthlySalaryForm);
      }

      return null;
    } finally {
      if (mounted) {
        setState(() {
          isMonthlySalaryLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SALARY CALCULATION API
  // ============================================================

  Future<void> calculateSalary() async {
    if (selectedStaff == null) {
      _showMessage(
        'Please select a staff member.',
        isError: true,
      );
      return;
    }

    final int? staffId = _toInt(selectedStaff!['id']);

    if (staffId == null) {
      _showMessage(
        'Invalid staff ID.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSalaryLoading = true;
      salaryError = null;
      _clearSalaryResult(resetForm: true);
    });

    try {
      final token = await gettokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found.');
      }

      final Uri uri = Uri.parse(
        '$api/api/staff/salary/calculate/',
      ).replace(
        queryParameters: {
          'staff_id': staffId.toString(),
          'year': selectedYear.toString(),
          'month': selectedMonth.toString(),
        },
      );

      debugPrint('========== CALCULATE SALARY ==========');
      debugPrint('URL: $uri');
      debugPrint('STAFF ID: $staffId');
      debugPrint('YEAR: $selectedYear');
      debugPrint('MONTH: $selectedMonth');

      final response = await http.get(
        uri,
        headers: _authHeaders(token),
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('======================================');

      final dynamic decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Failed to calculate monthly salary.';

        if (decoded is Map) {
          message =
              decoded['message']?.toString() ??
              decoded['detail']?.toString() ??
              decoded['error']?.toString() ??
              message;

          final errors = decoded['errors'];
          if (errors is String && errors.trim().isNotEmpty) {
            message = errors;
          }
        }

        throw Exception(message);
      }

      if (decoded is! Map) {
        throw Exception('Invalid salary API response.');
      }

      final Map<String, dynamic> responseMap =
          Map<String, dynamic>.from(decoded);

      if (responseMap['status']?.toString().toLowerCase() != 'success') {
        throw Exception(
          responseMap['message']?.toString() ??
              'Unable to calculate salary.',
        );
      }

      final dynamic rawData = responseMap['data'];

      if (rawData is! Map) {
        throw Exception('Salary calculation data not found.');
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(rawData);

      if (!mounted) return;

      setState(() {
        salaryResponse = data;
        staffData = _safeMap(data['staff']);
        salaryData = _safeMap(data['salary']);
        attendanceData = _safeMap(data['attendance']);
        paidLeaveData = _safeMap(data['paid_leave']);
        deductionsData = _safeMap(data['deductions']);
        payableSalary = data['payable_salary']?.toString() ?? '0.00';
      });

      // Exact React flow: after calculation, load an existing monthly
      // salary record so the form switches between POST and PUT.
      await fetchSavedMonthlySalary(
        staffId: staffId,
        year: selectedYear,
        month: selectedMonth,
      );

      if (!mounted) return;

      _showMessage(
        responseMap['message']?.toString() ??
            'Monthly salary calculated successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint('SALARY CALCULATION ERROR: $error');
      debugPrint('SALARY CALCULATION STACKTRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        salaryError = error.toString().replaceFirst('Exception: ', '');
        _clearSalaryResult(resetForm: true, clearError: false);
      });

      _showMessage(
        salaryError ?? 'Failed to calculate monthly salary.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSalaryLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE / UPDATE MONTHLY SALARY
  // ============================================================

  Future<void> saveMonthlySalary() async {
    if (salaryResponse == null) {
      _showMessage(
        'Please calculate salary first.',
        isError: true,
      );
      return;
    }

    if (selectedStaff == null) {
      _showMessage(
        'Please select a staff member.',
        isError: true,
      );
      return;
    }

    final staffId = _toInt(selectedStaff!['id']);

    if (staffId == null) {
      _showMessage(
        'Invalid staff ID.',
        isError: true,
      );
      return;
    }

    final double? bonus = _parseOptionalDouble(bonusController.text);
    final double? incentives =
        _parseOptionalDouble(incentivesController.text);
    final int? lateComes = _parseOptionalInt(lateComesController.text);
    final double? fines = _parseOptionalDouble(finesController.text);

    if (bonus == null) {
      _showMessage(
        'Bonus must be a valid number.',
        isError: true,
      );
      return;
    }

    if (incentives == null) {
      _showMessage(
        'Incentives must be a valid number.',
        isError: true,
      );
      return;
    }

    if (lateComes == null) {
      _showMessage(
        'Number of late comes must be a valid whole number.',
        isError: true,
      );
      return;
    }

    if (fines == null) {
      _showMessage(
        'Fines must be a valid number.',
        isError: true,
      );
      return;
    }

    if (bonus < 0 || incentives < 0 || fines < 0) {
      _showMessage(
        'Bonus, incentives and fines cannot be negative.',
        isError: true,
      );
      return;
    }

    if (lateComes < 0) {
      _showMessage(
        'Number of late comes must be a valid whole number.',
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        isSavingSalary = true;
      });

      final token = await gettokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found.');
      }

      final payload = <String, dynamic>{
        'staff': staffId,
        'month': selectedMonth,
        'year': selectedYear,
        'present': _toNum(attendanceData?['present']),
        'absent': _toNum(attendanceData?['absent']),
        'half_day': _toNum(attendanceData?['half_day']),
        'paid_leaves': _toNum(paidLeaveData?['used']),
        'bonus': bonus,
        'incentives': incentives,
        'late_comes': lateComes,
        'fines': fines,
        'note': noteController.text.trim(),
      };

      debugPrint('========== MONTHLY SALARY SAVE ==========');
      debugPrint('MONTHLY SALARY ID: $monthlySalaryId');
      debugPrint('PAYLOAD: ${jsonEncode(payload)}');

      late final http.Response response;

      if (monthlySalaryId != null) {
        final uri = Uri.parse(
          '$api/api/staff/monthly/salary/$monthlySalaryId/',
        );

        debugPrint('METHOD: PUT');
        debugPrint('URL: $uri');

        response = await http.put(
          uri,
          headers: _authHeaders(token),
          body: jsonEncode(payload),
        );
      } else {
        final uri = Uri.parse('$api/api/staff/monthly/salary/');

        debugPrint('METHOD: POST');
        debugPrint('URL: $uri');

        response = await http.post(
          uri,
          headers: _authHeaders(token),
          body: jsonEncode(payload),
        );
      }

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=========================================');

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractSaveError(
            decoded,
            fallback: monthlySalaryId != null
                ? 'Failed to update monthly salary data.'
                : 'Failed to save monthly salary data.',
          ),
        );
      }

      if (decoded is! Map ||
          decoded['status']?.toString().toLowerCase() != 'success') {
        throw Exception(
          decoded is Map
              ? decoded['message']?.toString() ??
                  (monthlySalaryId != null
                      ? 'Failed to update monthly salary data.'
                      : 'Failed to save monthly salary data.')
              : (monthlySalaryId != null
                  ? 'Failed to update monthly salary data.'
                  : 'Failed to save monthly salary data.'),
        );
      }

      if (!mounted) return;

      _showMessage(
        decoded['message']?.toString() ??
            (monthlySalaryId != null
                ? 'Monthly salary data updated successfully.'
                : 'Monthly salary data saved successfully.'),
      );

      // Exact React behavior: fetch saved data again after POST/PUT.
      await fetchSavedMonthlySalary(
        staffId: staffId,
        year: selectedYear,
        month: selectedMonth,
      );
    } catch (error, stackTrace) {
      debugPrint('MONTHLY SALARY SAVE/UPDATE ERROR: $error');
      debugPrint('STACKTRACE: $stackTrace');

      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingSalary = false;
        });
      }
    }
  }

  // ============================================================
  // RESET FILTERS
  // ============================================================

  void resetFilters() {
    final now = DateTime.now();

    setState(() {
      selectedStaff = null;
      selectedYear = now.year;
      selectedMonth = now.month;
      salaryError = null;
      _clearSalaryResult(resetForm: true);
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  double? _parseOptionalDouble(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text);
  }

  int? _parseOptionalInt(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;

    // Prevent "3.5" from silently becoming 3.
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return null;
    }

    return int.tryParse(text);
  }

  String _extractBackendMessage(
    String body, {
    required String fallback,
  }) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        return decoded['message']?.toString() ??
            decoded['detail']?.toString() ??
            decoded['error']?.toString() ??
            fallback;
      }
    } catch (_) {}

    return fallback;
  }

  String _extractSaveError(
    dynamic responseData, {
    required String fallback,
  }) {
    if (responseData is! Map) return fallback;

    String message = responseData['message']?.toString() ?? fallback;
    final dynamic errors = responseData['errors'];

    if (errors == null) return message;

    if (errors is String && errors.trim().isNotEmpty) {
      return errors;
    }

    if (errors is Map) {
      final dynamic messageError = errors['message'];

      if (messageError is List && messageError.isNotEmpty) {
        return messageError.first.toString();
      }

      if (messageError != null && messageError.toString().trim().isNotEmpty) {
        return messageError.toString();
      }

      if (errors.isNotEmpty) {
        final firstKey = errors.keys.first;
        final firstError = errors[firstKey];

        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }

        if (firstError != null && firstError.toString().trim().isNotEmpty) {
          return firstError.toString();
        }
      }
    }

    return message;
  }

  void _clearSalaryResult({
    bool resetForm = false,
    bool clearError = true,
  }) {
    salaryResponse = null;
    staffData = null;
    salaryData = null;
    attendanceData = null;
    paidLeaveData = null;
    deductionsData = null;
    payableSalary = '0.00';

    if (clearError) {
      salaryError = null;
    }

    if (resetForm) {
      _resetMonthlySalaryForm();
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? Colors.red : Colors.green,
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // STAFF SELECTOR
  // ============================================================

  Future<void> _showStaffSelector() async {
    if (_isBusy) return;

    searchController.clear();

    await getstaff();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setSheetState) {
            Future<void> searchStaff() async {
              await getstaff();

              if (bottomSheetContext.mounted) {
                setSheetState(() {});
              }
            }

            Future<void> clearSearch() async {
              searchController.clear();
              await getstaff();

              if (bottomSheetContext.mounted) {
                setSheetState(() {});
              }
            }

            Future<void> loadMoreStaff() async {
              await getstaff(loadMore: true);

              if (bottomSheetContext.mounted) {
                setSheetState(() {});
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Staff',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Search by name, staff ID, EID, designation or department',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(bottomSheetContext);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) async {
                        await searchStaff();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search staff...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (searchController.text.isNotEmpty)
                              IconButton(
                                onPressed: clearSearch,
                                icon: const Icon(Icons.clear_rounded),
                              ),
                            IconButton(
                              onPressed: searchStaff,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                      ),
                      onChanged: (_) {
                        setSheetState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isStaffLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : sta.isEmpty
                            ? _buildNoStaffFound()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  6,
                                  20,
                                  20,
                                ),
                                itemCount: sta.length + (hasNextPage ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index == sta.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: OutlinedButton(
                                        onPressed: isPaginationLoading
                                            ? null
                                            : loadMoreStaff,
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(
                                            double.infinity,
                                            48,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: isPaginationLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Load More Staff'),
                                      ),
                                    );
                                  }

                                  final staff = sta[index];

                                  return _buildStaffListTile(
                                    staff: staff,
                                    onTap: () {
                                      setState(() {
                                        selectedStaff =
                                            Map<String, dynamic>.from(staff);
                                        _clearSalaryResult(resetForm: true);
                                      });

                                      Navigator.pop(bottomSheetContext);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchController.clear();
  }

  Widget _buildNoStaffFound() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 54,
              color: Colors.black26,
            ),
            SizedBox(height: 12),
            Text(
              'No staff found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Try another staff name or ID.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffListTile({
    required Map<String, dynamic> staff,
    required VoidCallback onTap,
  }) {
    final String name = staff['name']?.toString() ?? 'Unknown Staff';

    final String staffId =
        staff['staff_id']?.toString() ?? staff['eid']?.toString() ?? '';

    final String designation = staff['designation']?.toString() ?? '';
    final String department = staff['department_name']?.toString() ?? '';

    return Material(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE4EAF2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF3FF),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _getInitials(name),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (staffId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          staffId,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    if (designation.isNotEmpty || department.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          [designation, department]
                              .where((value) => value.isNotEmpty)
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';

    if (words.length == 1) {
      return words.first[0].toUpperCase();
    }

    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  // ============================================================
  // FORMATTERS
  // ============================================================

  String _money(dynamic value) {
    final num? number = num.tryParse(value?.toString() ?? '');

    if (number == null) return '₹0.00';

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return formatter.format(number);
  }

  String _value(
    dynamic value, {
    String fallback = '-',
  }) {
    if (value == null) return fallback;

    final text = value.toString();

    if (text.trim().isEmpty) return fallback;

    return text;
  }

  String get selectedMonthName {
    final item = months.firstWhere(
      (month) => month['value'] == selectedMonth,
    );

    return item['name'].toString();
  }

  double get lateComeHalfDays {
    final lateComes =
        int.tryParse(lateComesController.text.trim()) ?? 0;

    return (lateComes ~/ 3) * 0.5;
  }

  // ============================================================
  // FRONTEND FINAL PAYABLE SALARY CALCULATION
  // ============================================================
  //
  // Backend payableSalary already contains attendance-based salary
  // calculation (absent / attendance half-day deductions).
  //
  // Monthly adjustments entered on this page are applied locally:
  //
  // final payable =
  //   attendance payable salary
  //   + bonus
  //   + incentives
  //   - late-coming half-day salary deduction
  //   - fines
  //
  // Rule: every 3 late comes = 0.5 day salary deduction.
  //
  // Example:
  // 3 late comes -> 0.5 day
  // 6 late comes -> 1.0 day
  // 7 late comes -> 1.0 day
  //
  // This is intentionally frontend-only. Existing API payload and
  // backend contract are not changed.

  double get _basePayableSalary {
    return double.tryParse(payableSalary.toString()) ?? 0.0;
  }

  double get _monthlyBonus {
    return double.tryParse(bonusController.text.trim()) ?? 0.0;
  }

  double get _monthlyIncentives {
    return double.tryParse(incentivesController.text.trim()) ?? 0.0;
  }

  double get _monthlyFines {
    return double.tryParse(finesController.text.trim()) ?? 0.0;
  }

  double get _perDaySalary {
    return double.tryParse(
          salaryData?['per_day_salary']?.toString() ?? '',
        ) ??
        0.0;
  }

  double get _lateComeSalaryDeduction {
    return lateComeHalfDays * _perDaySalary;
  }

  double get _frontendFinalPayableSalary {
    final calculated =
        _basePayableSalary +
        _monthlyBonus +
        _monthlyIncentives -
        _lateComeSalaryDeduction -
        _monthlyFines;

    // Salary should never display as a negative payable amount.
    return calculated < 0 ? 0.0 : calculated;
  }

  bool get _isBusy =>
      isSalaryLoading ||
      isSavingSalary ||
      isMonthlySalaryLoading;

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Monthly Salary',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await getstaff();

          if (selectedStaff != null) {
            await calculateSalary();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildFilterCard(),

              if (isSalaryLoading) ...[
                const SizedBox(height: 16),
                _buildLoadingCard(),
              ],

              if (!isSalaryLoading && salaryError != null) ...[
                const SizedBox(height: 16),
                _buildErrorCard(),
              ],

              if (!isSalaryLoading &&
                  salaryError == null &&
                  salaryResponse != null) ...[
                const SizedBox(height: 16),
                _buildEmployeeCard(),
                const SizedBox(height: 16),
                _buildSalarySummaryCards(),
                const SizedBox(height: 16),
                _buildAttendanceCard(),
                const SizedBox(height: 16),
                _buildPaidLeaveCard(),
                const SizedBox(height: 16),
                _buildDeductionCard(),
                const SizedBox(height: 16),
                _buildMonthlySalaryDetailsCard(),
                const SizedBox(height: 16),
                _buildFinalPayableSalaryCard(),
              ],

              if (!isSalaryLoading &&
                  salaryResponse == null &&
                  salaryError == null)
                _buildInitialState(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220000FF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salary Calculator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Review monthly attendance, paid leave, deductions and final payable salary.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 40,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CARD
  // ============================================================

  Widget _buildFilterCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.tune_rounded,
            title: 'Calculate Monthly Salary',
            subtitle: 'Choose staff, year and month',
          ),
          const SizedBox(height: 18),
          const Text(
            'Staff',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: isStaffLoading || _isBusy ? null : _showStaffSelector,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFDCE5F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: selectedStaff == null
                        ? Text(
                            isStaffLoading
                                ? 'Loading Staff...'
                                : 'Search or Select Staff',
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                selectedStaff!['name']?.toString() ?? 'Staff',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  selectedStaff!['staff_id']?.toString() ??
                                      selectedStaff!['eid']?.toString() ??
                                      '',
                                  selectedStaff!['designation']?.toString() ??
                                      '',
                                ]
                                    .where((value) => value.isNotEmpty)
                                    .join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  height: 1.0,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (selectedStaff != null && !_isBusy)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          selectedStaff = null;
                          _clearSalaryResult(resetForm: true);
                        });
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: Colors.black45,
                      ),
                    )
                  else
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.black54,
                    ),
                ],
              ),
            ),
          ),
          if (selectedStaff != null) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
                children: [
                  const TextSpan(text: 'Selected Staff: '),
                  TextSpan(
                    text: selectedStaff!['name']?.toString() ?? '-',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((selectedStaff!['designation']?.toString() ?? '')
                      .isNotEmpty)
                    TextSpan(
                      text:
                          ' | ${selectedStaff!['designation']?.toString() ?? ''}',
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildYearDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildMonthDropdown()),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy || isStaffLoading
                        ? null
                        : calculateSalary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.blue.withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: isSalaryLoading || isMonthlySalaryLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.calculate_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isSalaryLoading
                            ? 'Calculating...'
                            : isMonthlySalaryLoading
                                ? 'Loading...'
                                : 'Calculate Salary',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : resetFilters,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Year',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFDCE5F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedYear,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: availableYears
                  .map(
                    (year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    ),
                  )
                  .toList(),
              onChanged: _isBusy
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        selectedYear = value;
                        _clearSalaryResult(resetForm: true);
                      });
                    },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFDCE5F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedMonth,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: months
                  .map(
                    (month) => DropdownMenuItem<int>(
                      value: month['value'] as int,
                      child: Text(
                        month['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isBusy
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        selectedMonth = value;
                        _clearSalaryResult(resetForm: true);
                      });
                    },
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPLOYEE DETAILS
  // ============================================================

  Widget _buildEmployeeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.badge_outlined,
            title: 'Staff Details',
          ),
          const SizedBox(height: 16),
          _detailRow('Staff Name', _value(staffData?['name'])),
          _detailRow('Staff ID', _value(staffData?['staff_id'])),
          _detailRow('Designation', _value(staffData?['designation'])),
          _detailRow(
            'EID',
            _value(staffData?['eid']),
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SALARY SUMMARY CARDS
  // ============================================================

  Widget _buildSalarySummaryCards() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Salary Summary',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _salaryMetricBox(
                  title: 'Monthly Salary',
                  value: _money(salaryData?['monthly_salary']),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _salaryMetricBox(
                  title: 'Payable Salary',
                  value: _money(payableSalary),
                  emphasize: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _salaryMetricBox(
                  title: 'Per Day Salary',
                  value: _money(salaryData?['per_day_salary']),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _salaryMetricBox(
                  title: 'Calculation Days',
                  value: _value(
                    salaryData?['salary_calculation_days'],
                    fallback: '-',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _salaryMetricBox({
    required String title,
    required String value,
    bool emphasize = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: emphasize
            ? const Color(0xFFF0FFF5)
            : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: emphasize
              ? const Color(0xFFCDEFD9)
              : const Color(0xFFE4EAF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: emphasize ? Colors.green : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  Widget _buildAttendanceCard() {
    final attendanceMonth = _toInt(attendanceData?['month']);
    final monthLabel = attendanceMonth == null
        ? '-'
        : months
            .firstWhere(
              (item) => item['value'] == attendanceMonth,
              orElse: () => {'name': attendanceMonth.toString()},
            )['name']
            .toString();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.calendar_month_outlined,
            title: 'Attendance Details',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  title: 'Year',
                  value: _value(attendanceData?['year']),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  title: 'Month',
                  value: monthLabel,
                  icon: Icons.date_range_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  title: 'Calendar Days',
                  value: _value(
                    attendanceData?['calendar_days'],
                    fallback: '0',
                  ),
                  icon: Icons.calendar_view_month_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  title: 'Attendance Records',
                  value: _value(
                    attendanceData?['total_attendance_records'],
                    fallback: '0',
                  ),
                  icon: Icons.fact_check_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  title: 'Present',
                  value: _value(
                    attendanceData?['present'],
                    fallback: '0',
                  ),
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  title: 'Absent',
                  value: _value(
                    attendanceData?['absent'],
                    fallback: '0',
                  ),
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  title: 'Half Day',
                  value: _value(
                    attendanceData?['half_day'],
                    fallback: '0',
                  ),
                  icon: Icons.timelapse_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  title: 'Payable Days',
                  value: _value(
                    attendanceData?['payable_days'],
                    fallback: '0',
                  ),
                  icon: Icons.event_available_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAID LEAVE
  // ============================================================

  Widget _buildPaidLeaveCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.beach_access_outlined,
            title: 'Paid Leave Details',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  title: 'Allowed',
                  value: _value(
                    paidLeaveData?['allowed'],
                    fallback: '0',
                  ),
                  icon: Icons.event_available_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  title: 'Used',
                  value: _value(
                    paidLeaveData?['used'],
                    fallback: '0',
                  ),
                  icon: Icons.event_busy_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  title: 'Remaining',
                  value: _value(
                    paidLeaveData?['remaining'],
                    fallback: '0',
                  ),
                  icon: Icons.event_repeat_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  title: 'Deductible Absent',
                  value: _value(
                    paidLeaveData?['deductible_absent_days'],
                    fallback: '0',
                  ),
                  icon: Icons.remove_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DEDUCTIONS
  // ============================================================

  Widget _buildDeductionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.remove_circle_outline,
            title: 'Salary Deductions',
          ),
          const SizedBox(height: 16),
          _detailRow(
            'Absent Deduction',
            _money(deductionsData?['absent_deduction']),
          ),
          _detailRow(
            'Half Day Deduction',
            _money(deductionsData?['half_day_deduction']),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(color: Color(0xFFE8EDF3)),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Deduction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _money(deductionsData?['total_deduction']),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTHLY SALARY DETAILS FORM
  // ============================================================

  Widget _buildMonthlySalaryDetailsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.edit_note_rounded,
            title: 'Monthly Salary Details',
            subtitle: monthlySalaryId != null
                ? 'Existing monthly salary record loaded'
                : 'Enter additional monthly salary details',
          ),
          if (isMonthlySalaryLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (monthlySalaryId != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCFE2FF),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Existing monthly salary record loaded. You can update the values below.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF285EA8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: bonusController,
                  label: 'Bonus',
                  hint: 'Enter bonus',
                  decimal: true,
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: incentivesController,
                  label: 'Incentives',
                  hint: 'Enter incentives',
                  decimal: true,
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _numberField(
                  controller: lateComesController,
                  label: 'Number of Late Comes',
                  hint: 'Enter late comes',
                  decimal: false,
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: finesController,
                  label: 'Fines',
                  hint: 'Enter fines',
                  decimal: true,
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '3 late comes = 0.5 day leave',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.black54,
            ),
          ),
          if ((int.tryParse(lateComesController.text.trim()) ?? 0) >= 3) ...[
            const SizedBox(height: 4),
            Text(
              'Late Leave: ${_formatDayValue(lateComeHalfDays)} '
              '${lateComeHalfDays == 1 ? 'Day' : 'Days'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Note',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            enabled: !isSavingSalary && !isMonthlySalaryLoading,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Enter note',
              filled: true,
              fillColor: const Color(0xFFF8FAFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFFDCE5F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFFDCE5F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE1E5EA),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _miniSummary(
                    'Number of Late Comes',
                    (int.tryParse(lateComesController.text.trim()) ?? 0)
                        .toString(),
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: const Color(0xFFE1E5EA),
                ),
                Expanded(
                  child: _miniSummary(
                    'Half Day Leave from Late Comes',
                    _formatDayValue(lateComeHalfDays),
                    warning: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSavingSalary ||
                      isSalaryLoading ||
                      isMonthlySalaryLoading
                  ? null
                  : saveMonthlySalary,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    monthlySalaryId != null ? Colors.blue : Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: isSavingSalary
                  ? const SizedBox(
                      height: 19,
                      width: 19,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      monthlySalaryId != null
                          ? Icons.save_as_outlined
                          : Icons.save_outlined,
                    ),
              label: Text(
                isSavingSalary
                    ? monthlySalaryId != null
                        ? 'Updating...'
                        : 'Saving...'
                    : monthlySalaryId != null
                        ? 'Update Monthly Salary'
                        : 'Save Monthly Salary',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool decimal,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !isSavingSalary && !isMonthlySalaryLoading,
          keyboardType: TextInputType.numberWithOptions(
            decimal: decimal,
            signed: false,
          ),
          inputFormatters: [
            if (decimal)
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,2}'),
              )
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFFDCE5F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFFDCE5F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniSummary(
    String title,
    String value, {
    bool warning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.3,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: warning ? Colors.orange : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDayValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  // ============================================================
  // FINAL PAYABLE SALARY
  // ============================================================

  Widget _buildFinalPayableSalaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF132238),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Final Payable Salary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Attendance payable salary with monthly bonus, incentives, late-coming deduction and fines applied.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          _finalSalaryBreakdownRow(
            label: 'Attendance Payable',
            value: _basePayableSalary,
          ),
          _finalSalaryBreakdownRow(
            label: 'Bonus',
            value: _monthlyBonus,
            positive: true,
          ),
          _finalSalaryBreakdownRow(
            label: 'Incentives',
            value: _monthlyIncentives,
            positive: true,
          ),
          _finalSalaryBreakdownRow(
            label:
                'Late Deduction (${_formatDayValue(lateComeHalfDays)} day)',
            value: _lateComeSalaryDeduction,
            negative: true,
          ),
          _finalSalaryBreakdownRow(
            label: 'Fines',
            value: _monthlyFines,
            negative: true,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: Colors.white24,
              height: 1,
            ),
          ),

          const Text(
            'FINAL PAYABLE SALARY',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(_frontendFinalPayableSalary),
              style: const TextStyle(
                color: Color(0xFF57D987),
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalSalaryBreakdownRow({
    required String label,
    required double value,
    bool positive = false,
    bool negative = false,
  }) {
    final String prefix = positive
        ? '+ '
        : negative
            ? '- '
            : '';

    final Color valueColor = positive
        ? const Color(0xFF57D987)
        : negative
            ? const Color(0xFFFF8A80)
            : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$prefix${_money(value)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON UI
  // ============================================================

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE3EAF2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: Colors.blue,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : 13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE4EAF2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 19,
            color: Colors.blue,
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 1.1,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 35,
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 55,
            color: Colors.black26,
          ),
          SizedBox(height: 14),
          Text(
            'Select Salary Period',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Select a staff member, year and month, then tap Calculate Salary to view the complete monthly breakdown.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return _card(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Calculating monthly salary...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return _card(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Unable to Calculate Salary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            salaryError ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : calculateSalary,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    searchController.dispose();
    bonusController.dispose();
    incentivesController.dispose();
    lateComesController.dispose();
    finesController.dispose();
    noteController.dispose();
    super.dispose();
  }
}
