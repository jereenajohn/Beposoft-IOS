import 'dart:async';
import 'dart:convert';

import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ADMIN/Operation_executive_dashboard.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/HR/hr_dashboard.dart';
import 'package:beposoft/pages/MARKETING/marketing_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SalesPointRankingPage extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? staffId;

  const SalesPointRankingPage({
    super.key,
    this.startDate,
    this.endDate,
    this.staffId,
  });

  @override
  State<SalesPointRankingPage> createState() =>
      _SalesPointRankingPageState();
}

class _SalesPointRankingPageState extends State<SalesPointRankingPage> {
  static const Color _blue = Color(0xFF287BE4);
  static const Color _ink = Color(0xFF101828);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE4E7EC);

  final http.Client _client = http.Client();
  final TextEditingController _searchController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedStaffId;

  List<Map<String, dynamic>> _staffOptions = [];
  List<Map<String, dynamic>> _records = [];
  List<String> _departments = [];
  Map<String, dynamic> _summary = {};

  String? _department;
  String? _error;
  String? _staffError;
  String _loadedPeriod = '';
  String _responseStatus = '';
  String _responseMessageText = '';
  String _responseCount = '0';

  bool _loading = false;
  bool _loadingStaff = true;
  bool _hasRequested = false;

  int _requestId = 0;
  int _staffRequestId = 0;

  String get _baseUrl =>
      api.toString().replaceFirst(RegExp(r'/+$'), '');

  bool get _filtersComplete =>
      _startDate != null && _endDate != null;

  @override
  void initState() {
    super.initState();

    _fetchStaff();
  }

  @override
  void dispose() {
    _requestId++;
    _staffRequestId++;
    _client.close();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _apiDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _responseDate(dynamic value, DateTime fallback) {
    final parsed = DateTime.tryParse(_text(value, ''));

    return _displayDate(parsed ?? fallback);
  }

  String _text(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }

  String _points(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '');

    return number?.toStringAsFixed(2) ?? '0.00';
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> get _visibleRecords {
    final query = _searchController.text.trim().toLowerCase();

    return _records.where((record) {
      final matchesDepartment =
          _department == null || record['department'] == _department;

      final matchesSearch = query.isEmpty ||
          [
            record['staff_name'],
            record['staff_id'],
            record['department'],
            record['family'],
          ].any(
            (value) => _text(value, '').toLowerCase().contains(query),
          );

      return matchesDepartment && matchesSearch;
    }).toList();
  }

  String _responseMessage(dynamic decoded, String fallback) {
    if (decoded is Map) {
      for (final key in ['message', 'detail', 'error']) {
        final value = decoded[key];

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }

      if (decoded['results'] is Map) {
        return _responseMessage(decoded['results'], fallback);
      }
    }

    return fallback;
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.trim().isEmpty) {
      throw const _RankingException(
        'Your session is unavailable. Please log in again.',
      );
    }

    return token;
  }

  Future<dynamic> _getJson(Uri uri, String token) async {
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw const _RankingException(
        'Your session has expired. Please log in again.',
      );
    }

    if (response.statusCode == 403) {
      throw const _RankingException(
        'You do not have permission to view this data.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    } on FormatException {
      throw const _RankingException(
        'The server returned an invalid response.',
      );
    }

    if (response.statusCode != 200) {
      throw _RankingException(
        _responseMessage(
          decoded,
          'Unable to load data. Please try again.',
        ),
      );
    }

    return decoded;
  }

  Future<List<Map<String, dynamic>>> _loadStaffOptions(
    String search, {
    bool Function()? isCurrent,
  }) async {
    final token = await _getToken();

    if (!mounted || (isCurrent != null && !isCurrent())) return [];

    final firstUri = Uri.parse(
      '$_baseUrl/api/get/staffs/',
    ).replace(
      queryParameters: {
        'page': '1',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    Uri? nextUri = firstUri;

    final visited = <String>{};
    final staffById = <int, Map<String, dynamic>>{};

    while (nextUri != null) {
      if (!visited.add(nextUri.toString())) {
        throw const _RankingException(
          'Unable to load the complete staff list. Please retry.',
        );
      }

      final currentUri = nextUri;
      final decoded = await _getJson(currentUri, token);

      if (!mounted || (isCurrent != null && !isCurrent())) return [];

      if (decoded is! Map ||
          decoded['results'] is! Map ||
          decoded['results']['data'] is! List) {
        throw const _RankingException(
          'Unexpected staff list response.',
        );
      }

      final staffData = _maps(decoded['results']['data']);

      for (final staff in staffData) {
        final id = int.tryParse(
          _text(staff['id'], ''),
        );

        if (id == null || id <= 0) continue;

        staffById[id] = {
          'id': id,
          'name': _text(
            staff['name'],
            _text(staff['username'], 'Unnamed staff'),
          ),
          'department_name': _text(
            staff['department_name'],
            '',
          ),
        };
      }

      final next = _text(decoded['next'], '');

      if (next.isEmpty) {
        nextUri = null;
      } else {
        final resolved = currentUri.resolve(next);

        if (resolved.origin != firstUri.origin) {
          throw const _RankingException(
            'The staff pagination URL is invalid.',
          );
        }

        nextUri = resolved.replace(
          queryParameters: {
            ...resolved.queryParameters,
            if (search.trim().isNotEmpty) 'search': search.trim(),
          },
        );
      }
    }

    final options = staffById.values.toList()
      ..sort(
        (a, b) => _text(a['name'])
            .toLowerCase()
            .compareTo(
              _text(b['name']).toLowerCase(),
            ),
      );

    return options;
  }

  Future<void> _fetchStaff() async {
    final requestId = ++_staffRequestId;

    setState(() {
      _loadingStaff = true;
      _staffError = null;
    });

    try {
      final options = await _loadStaffOptions(
        '',
        isCurrent: () => requestId == _staffRequestId,
      );
      if (!mounted || requestId != _staffRequestId) return;

      setState(() {
        _staffOptions = options;

        if (!options.any(
          (staff) => staff['id'] == _selectedStaffId,
        )) {
          _selectedStaffId = null;
        }
      });
    } on _RankingException catch (error) {
      if (mounted && requestId == _staffRequestId) {
        setState(() {
          _staffError = error.message;
        });
      }
    } on TimeoutException {
      if (mounted && requestId == _staffRequestId) {
        setState(() {
          _staffError = 'Staff loading timed out. Please retry.';
        });
      }
    } catch (_) {
      if (mounted && requestId == _staffRequestId) {
        setState(() {
          _staffError = 'Unable to load staff. Check your connection.';
        });
      }
    } finally {
      if (mounted && requestId == _staffRequestId) {
        setState(() {
          _loadingStaff = false;
        });
      }
    }
  }

  void _clearReport() {
    _requestId++;
    _records = [];
    _summary = {};
    _departments = [];
    _department = null;
    _error = null;
    _loadedPeriod = '';
    _responseStatus = '';
    _responseMessageText = '';
    _responseCount = '0';
    _hasRequested = false;
    _loading = false;
    _searchController.clear();
  }

  Future<void> _fetchRanking() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    final start = _startDate;
    final end = _endDate;
    final staffId = _selectedStaffId;

    if (start == null || end == null) {
      _message('Please select start date and end date.');
      return;
    }

    if (start.isAfter(end)) {
      _message('Start date must be on or before end date.');
      return;
    }

    final requestId = ++_requestId;

    setState(() {
      _loading = true;
      _hasRequested = true;
      _error = null;
    });

    try {
      final token = await _getToken();

      if (!mounted || requestId != _requestId) return;

      final uri = Uri.parse(
        '$_baseUrl/api/sales/point/ranking/',
      ).replace(
        queryParameters: {
          'start_date': _apiDate(start),
          'end_date': _apiDate(end),
          if (staffId != null)
            'staff_id': staffId.toString(),
        },
      );

      final decoded = await _getJson(uri, token);

      if (!mounted || requestId != _requestId) return;

      if (decoded is! Map ||
          decoded['data'] is! List ||
          decoded['status'] != 'success') {
        throw _RankingException(
          _responseMessage(
            decoded,
            'Unexpected ranking response.',
          ),
        );
      }

      final records = _maps(decoded['data']);

      final departments = <String>{
        if (decoded['departments'] is List)
          ...(decoded['departments'] as List)
              .map((value) => _text(value, ''))
              .where((value) => value.isNotEmpty),
        ...records
            .map(
              (record) => _text(record['department'], ''),
            )
            .where((value) => value.isNotEmpty),
      }.toList()
        ..sort();

      setState(() {
        _records = records;

        _summary = decoded['summary'] is Map
            ? Map<String, dynamic>.from(
                decoded['summary'],
              )
            : {};

        _departments = departments;
        _department = null;

        _responseStatus = _text(decoded['status']);
        _responseMessageText = _text(decoded['message'], '');
        _responseCount = _text(
          decoded['count'],
          records.length.toString(),
        );

        _loadedPeriod =
            '${_responseDate(decoded['start_date'], start)} – '
            '${_responseDate(decoded['end_date'], end)}';
      });
    } on _RankingException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = error.message;
        });
      }
    } on TimeoutException {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = 'Request timed out. Please try again.';
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = 'Unable to connect. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial =
        (isStart ? _startDate : _endDate) ?? DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(
        initial.year < 2000 ? initial.year : 2000,
      ),
      lastDate: DateTime(
        initial.year > 2100 ? initial.year : 2100,
        12,
        31,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _blue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = _dateOnly(selected);
      } else {
        _endDate = _dateOnly(selected);
      }

      _clearReport();
    });
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedStaffId = null;
      _clearReport();
    });
  }

  Future<void> _refresh() async {
    if (_loading) return;

    if (_hasRequested && _filtersComplete) {
      await _fetchRanking();
    } else if (_staffError != null && !_loadingStaff) {
      await _fetchStaff();
    }
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: _muted,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _blue,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _surface(
    Widget child, {
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _dateButton(
    String label,
    DateTime? date,
    bool isStart,
  ) {
    return OutlinedButton(
      onPressed: _loading ? null : () => _pickDate(isStart),
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        padding: const EdgeInsets.all(13),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 19,
            color: _blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date == null
                      ? 'Select date'
                      : _displayDate(date),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: date == null ? _muted : _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffDropdown() {
    if (_loadingStaff) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading staff...',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      );
    }

    if (_staffError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _staffError!,
            style: const TextStyle(
              color: Color(0xFFD92D20),
            ),
          ),
          TextButton.icon(
            onPressed: _fetchStaff,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry staff list'),
          ),
        ],
      );
    }

    Map<String, dynamic>? selectedStaff;
    for (final staff in _staffOptions) {
      if (staff['id'] == _selectedStaffId) {
        selectedStaff = staff;
        break;
      }
    }
    final name = _text(selectedStaff?['name'], 'Choose staff');
    final department = _text(selectedStaff?['department_name'], '');

    return InkWell(
      onTap: _loading ? null : _openStaffPicker,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: false,
        decoration: _inputDecoration(
          'Select staff (optional)',
          Icons.badge_outlined,
        ).copyWith(
          enabled: !_loading,
          helperText: _staffOptions.isEmpty
              ? 'No staff available. You can filter by dates.'
              : 'Leave unselected to view all staff rankings.',
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          department.isEmpty ? name : '$name • $department',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _selectedStaffId == null ? _muted : _ink,
          ),
        ),
      ),
    );
  }

  Future<void> _openStaffPicker() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StaffSearchDialog(
        initialOptions: _staffOptions,
        selectedStaffId: _selectedStaffId,
        searchStaff: (query, isCurrent) => _loadStaffOptions(
          query,
          isCurrent: isCurrent,
        ),
      ),
    );
    if (!mounted || result == null) return;

    final id = result['id'] as int?;
    if (id == _selectedStaffId) return;
    setState(() {
      if (id != null && !_staffOptions.any((staff) => staff['id'] == id)) {
        _staffOptions = [..._staffOptions, result];
      }
      _selectedStaffId = id;
      _clearReport();
    });
  }

  Widget _filters() {
    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: _blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Report filters',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _resetFilters,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final start = _dateButton(
                'Start date',
                _startDate,
                true,
              );

              final end = _dateButton(
                'End date',
                _endDate,
                false,
              );

              if (constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    start,
                    const SizedBox(height: 10),
                    end,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: start),
                  const SizedBox(width: 10),
                  Expanded(child: end),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _staffDropdown(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading || !_filtersComplete
                  ? null
                  : _fetchRanking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.insights_rounded,
                size: 20,
              ),
              label: const Text(
                'Show ranking',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    Map<String, dynamic>? selectedStaffRecord;
    if (_selectedStaffId != null) {
      for (final record in _records) {
        if (int.tryParse(_text(record['staff_id'], '')) ==
            _selectedStaffId) {
          selectedStaffRecord = record;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF153A77),
            Color(0xFF287BE4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: Color(0xFFFFD678),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Sales leaderboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _loadedPeriod,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 36,
            runSpacing: 16,
            children: [
              _summaryValue(
                'Total points',
                _points(_summary['total_points']),
              ),
              if (_selectedStaffId != null)
                _summaryValue(
                  'Rank',
                  _text(selectedStaffRecord?['rank']),
                )
              else
                _summaryValue(
                  'Total staff',
                  _text(
                    _summary['total_staff'],
                    _records.length.toString(),
                  ),
                ),
              // _summaryValue(
              //   'Ranking count',
              //   _responseCount,
              // ),
            ],
          ),
          // const SizedBox(height: 16),
          // Text(
          //   'Status: $_responseStatus',
          //   style: const TextStyle(
          //     color: Colors.white70,
          //     fontSize: 11,
          //   ),
          // ),
          // if (_responseMessageText.isNotEmpty) ...[
          //   const SizedBox(height: 5),
          //   Text(
          //     _responseMessageText,
          //     style: const TextStyle(
          //       color: Colors.white70,
          //       fontSize: 11,
          //     ),
          //   ),
          // ],
          // if (_departments.isNotEmpty) ...[
          //   const SizedBox(height: 8),
          //   Text(
          //     'Departments: ${_departments.join(', ')}',
          //     style: const TextStyle(
          //       color: Colors.white70,
          //       fontSize: 11,
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _summaryValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _blue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    String value, {
    String? subtitle,
  }) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text(
              product['product_name'],
              'Unnamed product',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                'Sold quantity: '
                '${_text(product['sold_quantity'], '0')}',
              ),
              _tag(
                'Required quantity: '
                '${_text(product['required_quantity'], '0')}',
              ),
              _tag(
                'Completed blocks: '
                '${_text(product['completed_blocks'], '0')}',
              ),
              _tag(
                'Points per block: '
                '${_points(product['point_per_block'])}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Earned points: ${_points(product['earned_points'])}',
            style: const TextStyle(
              color: _blue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> record) {
    final rank = int.tryParse(
          _text(record['rank'], ''),
        ) ??
        0;

    final products = _maps(record['products']);

    final rankColor = switch (rank) {
      1 => const Color(0xFFB7790A),
      2 => const Color(0xFF667085),
      3 => const Color(0xFFAD683A),
      _ => _blue,
    };

    return _surface(
      Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: PageStorageKey(
            '${record['staff_id']}-$_loadedPeriod',
          ),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            16,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Container(
            width: 43,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              rank > 0 ? '#$rank' : '-',
              style: TextStyle(
                color: rankColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          title: Text(
            _text(
              record['staff_name'],
              'Unnamed staff',
            ),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_text(record['department'])} • '
                  '${_text(record['family'])}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${_points(record['total_points'])} points',
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(
              color: _border,
              height: 24,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag('Department: ${_text(record['department'])}'),
                _tag('Family: ${_text(record['family'])}'),
                _tag('Rank: ${_text(record['rank'])}'),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Points breakdown',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final blockWidth = (constraints.maxWidth - 8) / 2;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                        _metric(
                      'Total points',
                      _points(record['total_points']),
                    ),
                    _metric(
                      'Product points',
                      _points(record['product_points']),
                    ),
                    _metric(
                      'MD points',
                      _points(record['md_points']),
                      subtitle:
                          'MD count: ${_text(record['md_count'], '0')}',
                    ),
                    _metric(
                      'SD points',
                      _points(record['sd_points']),
                      subtitle:
                          'SD count: ${_text(record['sd_count'], '0')}',
                    ),
                    // _metric(
                    //   'New lead points',
                    //   _points(record['new_lead_points']),
                    //   subtitle:
                    //       'New leads: ${_text(record['new_leads'], '0')}',
                    // ),
                    // _metric(
                    //   'New customer points',
                    //   _points(record['new_customer_points']),
                    //   subtitle:
                    //       'New customers: '
                    //       '${_text(record['new_customers'], '0')}',
                    // ),
                    // _metric(
                    //   'New conversion points',
                    //   _points(record['new_conversion_points']),
                    //   subtitle:
                    //       'New conversions: '
                    //       '${_text(record['new_conversions'], '0')}',
                    // ),
                
                  ].map((block) {
                    return SizedBox(
                      width: blockWidth,
                      child: block,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Product performance (${products.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No product activity for this period.',
                  style: TextStyle(color: _muted),
                ),
              )
            else
              ...products.map(_productCard),
          ],
        ),
      ),
      padding: EdgeInsets.zero,
    );
  }

  Widget _searchAndDepartments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(
            'Search staff or family',
            Icons.search_rounded,
          ).copyWith(
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All departments'),
                  selected: _department == null,
                  onSelected: (_) {
                    setState(() {
                      _department = null;
                    });
                  },
                ),
              ),
              ..._departments.map(
                (department) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(department),
                    selected: _department == department,
                    onSelected: (selected) {
                      setState(() {
                        _department = selected
                            ? department
                            : null;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String message,
    bool retry = false,
  }) {
    return _surface(
      SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(
              icon,
              color: _blue,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            if (retry) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _fetchRanking,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
      padding: const EdgeInsets.all(26),
    );
  }

  bool _isNavigatingBack = false;

  Future<void> _navigateBack() async {
    if (_isNavigatingBack || !mounted) return;
    _isNavigatingBack = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final department = prefs.getString('department');
      if (!mounted) return;

      final Widget destination;
      switch (department) {
        case 'BDO':
          destination = bdo_dashbord();
          break;
        case 'COO':
        case 'CEO':
          destination = ceo_dashboard();
          break;
        case 'OPERATIONS':
          destination = OperationsExecutiveDashboard();
          break;
        case 'HR':
          destination = HrDashboard();
          break;
        case 'CSO':
          destination = cso_dashboard();
          break;
        case 'BDM':
          destination = bdm_dashbord();
          break;
        case 'warehouse':
          destination = WarehouseDashboard();
          break;
        case 'Marketing':
          destination = marketing_dashboard();
          break;
        case 'Warehouse Admin':
          destination = WarehouseAdmin();
          break;
        default:
          destination = dashboard();
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => destination),
      );
    } catch (error, stack) {
      _isNavigatingBack = false;
      debugPrint('Sales Point Ranking back navigation failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              'Unable to return to dashboard. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecords = _visibleRecords;

    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();
        return false;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
          onPressed: _navigateBack,
        ),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Point Ranking',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Track your team’s performance',
              style: TextStyle(
                fontSize: 11,
                color: _muted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: _loading || !_hasRequested
                ? null
                : _fetchRanking,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _filters(),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (!_hasRequested)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _statusCard(
                      icon: Icons.manage_search_rounded,
                      title: 'Choose your report filters',
                      message:
                          'Select both dates, then tap Show ranking. '
                          'Staff selection is optional.',
                    ),
                  ),
                )
              else if (_error != null)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _statusCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Could not load ranking',
                      message: _error!,
                      retry: true,
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _summaryCard(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _searchAndDepartments(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${visibleRecords.length} staff shown • '
                      'Tap a card for details',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (visibleRecords.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      24,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _statusCard(
                        icon: Icons.person_search_outlined,
                        title: 'No rankings found',
                        message:
                            'Try another date range, staff member '
                            'or search filter.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: _staffCard(
                            visibleRecords[index],
                          ),
                        ),
                        childCount: visibleRecords.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _RankingException implements Exception {
  final String message;

  const _RankingException(this.message);
}
class _StaffSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialOptions;
  final int? selectedStaffId;
  final Future<List<Map<String, dynamic>>> Function(
    String query,
    bool Function() isCurrent,
  ) searchStaff;

  const _StaffSearchDialog({
    required this.initialOptions,
    required this.selectedStaffId,
    required this.searchStaff,
  });

  @override
  State<_StaffSearchDialog> createState() => _StaffSearchDialogState();
}

class _StaffSearchDialogState extends State<_StaffSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _options = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _options = List<Map<String, dynamic>>.from(widget.initialOptions);
  }

  @override
  void dispose() {
    _requestId++;
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _options = [];
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value.trim(), requestId);
    });
  }

  Future<void> _search(String query, int requestId) async {
    bool isCurrent() => mounted && requestId == _requestId;
    try {
      final options = await widget.searchStaff(query, isCurrent);
      if (!isCurrent()) return;
      setState(() => _options = options);
    } on _RankingException catch (error) {
      if (isCurrent()) setState(() => _error = error.message);
    } on TimeoutException {
      if (isCurrent()) {
        setState(() => _error = 'Staff search timed out. Please retry.');
      }
    } catch (_) {
      if (isCurrent()) {
        setState(() => _error = 'Unable to search staff. Check your connection.');
      }
    } finally {
      if (isCurrent()) setState(() => _loading = false);
    }
  }

  Widget _selectionMark(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF287BE4) : Colors.white,
        border: Border.all(
          color: selected
              ? const Color(0xFF287BE4)
              : const Color(0xFFD0D5DD),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }

  Widget _staffOption({
    required String name,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool allStaff = false,
  }) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();

    return Material(
      color: selected ? const Color(0xFFF0F6FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? const Color(0xFFB8D5FA) : const Color(0xFFEAECF0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFDCEBFF)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: allStaff
                    ? const Icon(Icons.groups_rounded,
                        color: Color(0xFF287BE4), size: 22)
                    : Text(
                        initials,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF287BE4)
                              : const Color(0xFF475467),
                          fontSize: 13,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085), fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _selectionMark(selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerStatus(IconData icon, String title, String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: const Color(0xFF98A2B3)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF101828),
                )),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
            if (_error != null)
              TextButton.icon(
                onPressed: () => _onSearchChanged(_controller.text),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF287BE4)),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.badge_outlined,
                        size: 22, color: Color(0xFF287BE4)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select staff', style: TextStyle(
                          color: Color(0xFF101828), fontSize: 18,
                          fontWeight: FontWeight.w800,
                        )),
                        SizedBox(height: 3),
                        Text('Choose a staff member', style: TextStyle(
                          color: Color(0xFF667085), fontSize: 12,
                        )),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F4F7),
                      foregroundColor: const Color(0xFF667085),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14, color: Color(0xFF101828)),
                cursorColor: const Color(0xFF287BE4),
                decoration: InputDecoration(
                  hintText: 'Search staff',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF98A2B3)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 21, color: Color(0xFF667085)),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _controller.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Color(0xFF667085)),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: Color(0xFF287BE4), width: 1.5),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: _staffOption(
                name: 'All staff',
                subtitle: 'View the complete leaderboard',
                allStaff: true,
                selected: widget.selectedStaffId == null,
                onTap: () => Navigator.pop(context, <String, dynamic>{'id': null}),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAECF0)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Color(0xFF287BE4)))
                  : _error != null
                      ? _pickerStatus(Icons.wifi_off_rounded,
                          'Unable to load staff', _error!)
                      : _options.isEmpty
                          ? _pickerStatus(Icons.person_search_outlined,
                              'No staff found', 'Try a different staff name.')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: _options.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final staff = _options[index];
                                return _staffOption(
                                  name: staff['name']?.toString() ?? 'Unnamed staff',
                                  subtitle: staff['department_name']?.toString() ?? '',
                                  selected: staff['id'] == widget.selectedStaffId,
                                  onTap: () => Navigator.pop(context, staff),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
