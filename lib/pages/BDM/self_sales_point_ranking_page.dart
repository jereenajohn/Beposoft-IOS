import 'dart:async';
import 'dart:convert';

import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MySalesPointRankingPage extends StatefulWidget {
  const MySalesPointRankingPage({super.key});

  @override
  State<MySalesPointRankingPage> createState() =>
      _MySalesPointRankingPageState();
}

class _MySalesPointRankingPageState
    extends State<MySalesPointRankingPage> {
  static const Color _blue = Color(0xFF287BE4);
  static const Color _ink = Color(0xFF101828);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE4E7EC);

  final http.Client _client = http.Client();
  final TextEditingController _searchController =
      TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  int? _loggedInStaffId;
  String _loggedInStaffName = '';

  List<Map<String, dynamic>> _records = [];
  List<String> _departments = [];

  String? _department;
  String? _error;
  String? _profileError;

  String _loadedPeriod = '';
  String _responseStatus = '';
  String _responseMessageText = '';

  bool _loading = false;
  bool _loadingProfile = true;
  bool _hasRequested = false;

  int _requestId = 0;
  int _profileRequestId = 0;

  String get _baseUrl =>
      api.toString().replaceFirst(RegExp(r'/+$'), '');

  bool get _filtersComplete =>
      _startDate != null &&
      _endDate != null &&
      _loggedInStaffId != null;

  @override
  void initState() {
    super.initState();

    // Load the authenticated profile only.
    // Ranking loads after the user selects dates.
    _fetchProfile();
  }

  @override
  void dispose() {
    _requestId++;
    _profileRequestId++;
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
          _department == null ||
          record['department'] == _department;

      final matchesSearch = query.isEmpty ||
          [
            record['staff_name'],
            record['department'],
            record['family'],
          ].any(
            (value) => _text(value, '')
                .toLowerCase()
                .contains(query),
          );

      return matchesDepartment && matchesSearch;
    }).toList();
  }

  String _responseMessage(dynamic decoded, String fallback) {
    if (decoded is Map) {
      for (final key in ['message', 'detail', 'error']) {
        final value = decoded[key];

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }

      if (decoded['results'] is Map) {
        return _responseMessage(
          decoded['results'],
          fallback,
        );
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
      throw const _MyRankingException(
        'Your session is unavailable. Please log in again.',
      );
    }

    return token;
  }

  Future<dynamic> _getJson(
    Uri uri,
    String token,
  ) async {
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw const _MyRankingException(
        'Your session has expired. Please log in again.',
      );
    }

    if (response.statusCode == 403) {
      throw const _MyRankingException(
        'You do not have permission to view this data.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    } on FormatException {
      throw const _MyRankingException(
        'The server returned an invalid response.',
      );
    }

    if (response.statusCode != 200) {
      throw _MyRankingException(
        _responseMessage(
          decoded,
          'Unable to load data. Please try again.',
        ),
      );
    }

    return decoded;
  }

  // Uses the same authenticated profile endpoint as your profile page.
  Future<void> _fetchProfile() async {
    final requestId = ++_profileRequestId;

    setState(() {
      _loadingProfile = true;
      _profileError = null;
      _loggedInStaffId = null;
      _loggedInStaffName = '';
    });

    try {
      final token = await _getToken();

      if (!mounted || requestId != _profileRequestId) {
        return;
      }

      final decoded = await _getJson(
        Uri.parse('$_baseUrl/api/profile/'),
        token,
      );

      if (!mounted || requestId != _profileRequestId) {
        return;
      }

      if (decoded is! Map || decoded['data'] is! Map) {
        throw const _MyRankingException(
          'Invalid profile response.',
        );
      }

      final profile = Map<String, dynamic>.from(
        decoded['data'],
      );

      final staffId = int.tryParse(
        _text(profile['id'], ''),
      );

      if (staffId == null || staffId <= 0) {
        throw const _MyRankingException(
          'The logged-in staff account could not be identified.',
        );
      }

      setState(() {
        _loggedInStaffId = staffId;
        _loggedInStaffName = _text(
          profile['name'],
          _text(profile['username'], 'My account'),
        );
      });
    } on _MyRankingException catch (error) {
      if (mounted && requestId == _profileRequestId) {
        setState(() {
          _profileError = error.message;
        });
      }
    } on TimeoutException {
      if (mounted && requestId == _profileRequestId) {
        setState(() {
          _profileError =
              'Profile loading timed out. Please retry.';
        });
      }
    } catch (_) {
      if (mounted && requestId == _profileRequestId) {
        setState(() {
          _profileError =
              'Unable to load your profile. Check your connection.';
        });
      }
    } finally {
      if (mounted && requestId == _profileRequestId) {
        setState(() {
          _loadingProfile = false;
        });
      }
    }
  }

  void _clearReport() {
    _requestId++;
    _records = [];
    _departments = [];
    _department = null;
    _error = null;
    _loadedPeriod = '';
    _responseStatus = '';
    _responseMessageText = '';
    _hasRequested = false;
    _loading = false;
    _searchController.clear();
  }

  Future<void> _fetchRanking() async {
    if (_loading || _loadingProfile) return;

    FocusScope.of(context).unfocus();

    final start = _startDate;
    final end = _endDate;
    final staffId = _loggedInStaffId;

    if (staffId == null) {
      _message('Please load your profile before viewing ranking.');
      return;
    }

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
          'staff_id': staffId.toString(),
        },
      );

      final decoded = await _getJson(uri, token);

      if (!mounted || requestId != _requestId) return;

      if (decoded is! Map ||
          decoded['data'] is! List ||
          decoded['status'] != 'success') {
        throw _MyRankingException(
          _responseMessage(
            decoded,
            'Unexpected ranking response.',
          ),
        );
      }

      // Keep only the authenticated user's records, even if
      // the endpoint unexpectedly returns additional staff.
      final records = _maps(decoded['data']).where((record) {
        final recordStaffId = int.tryParse(
          _text(record['staff_id'], ''),
        );

        return recordStaffId == staffId;
      }).toList();

      // Derive displayed departments only from this user's data.
      final departments = records
          .map((record) => _text(record['department'], ''))
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _records = records;
        _departments = departments;
        _department = null;
        _responseStatus = _text(decoded['status']);
        _responseMessageText = _text(
          decoded['message'],
          '',
        );

        _loadedPeriod =
            '${_responseDate(decoded['start_date'], start)} – '
            '${_responseDate(decoded['end_date'], end)}';
      });
    } on _MyRankingException catch (error) {
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
          _error =
              'Unable to connect. Check your connection and try again.';
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
      _clearReport();
    });
  }

  Future<void> _refresh() async {
    if (_loading || _loadingProfile) return;

    if (_profileError != null || _loggedInStaffId == null) {
      await _fetchProfile();
    } else if (_hasRequested && _filtersComplete) {
      await _fetchRanking();
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

  Widget _profileSection() {
    if (_loadingProfile) {
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
            Expanded(
              child: Text(
                'Loading your profile...',
                style: TextStyle(color: _muted),
              ),
            ),
          ],
        ),
      );
    }

    if (_profileError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _profileError!,
            style: const TextStyle(
              color: Color(0xFFD92D20),
            ),
          ),
          TextButton.icon(
            onPressed: _fetchProfile,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry profile'),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_outline_rounded,
            color: _blue,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Staff',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loggedInStaffName,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: _muted,
          ),
        ],
      ),
    );
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
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
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
          _profileSection(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ||
                      _loadingProfile ||
                      !_filtersComplete
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
    // Calculate the personal summary from the filtered records.
    // This prevents an unfiltered API summary showing team totals.
    final totalPoints = _records.fold<double>(
      0,
      (total, record) =>
          total +
          (double.tryParse(
                _text(record['total_points'], '0'),
              ) ??
              0),
    );

    final totalStaff = _records
        .map((record) => record['staff_id'].toString())
        .toSet()
        .length;

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
                  'My sales leaderboard',
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
            _loggedInStaffName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _loadedPeriod,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _summaryValue(
                  'Total points',
                  _points(totalPoints),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _summaryValue(
                  'Rank',
                  _records.isEmpty
                      ? '-'
                      : _text(_records.first['rank']),
                ),
              ),
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
          expandedCrossAxisAlignment:
              CrossAxisAlignment.start,
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
              _loggedInStaffName,
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
                _tag(
                  'Department: ${_text(record['department'])}',
                ),
                _tag(
                  'Family: ${_text(record['family'])}',
                ),
                _tag(
                  'Rank: ${_text(record['rank'])}',
                ),
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
                        _department =
                            selected ? department : null;
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
              style: const TextStyle(
                color: _muted,
              ),
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

  @override
  Widget build(BuildContext context) {
    final visibleRecords = _visibleRecords;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Sales Point Ranking',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Track your sales performance',
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
                      title: 'Choose your report dates',
                      message:
                          'Select both dates, then tap Show ranking '
                          'to view your sales points.',
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
                // SliverPadding(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 16,
                //   ),
                //   sliver: SliverToBoxAdapter(
                //     child: _searchAndDepartments(),
                //   ),
                // ),
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
                            'No personal ranking matches this period '
                            'and the current search filters.',
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
    );
  }
}

class _MyRankingException implements Exception {
  final String message;

  const _MyRankingException(this.message);
}