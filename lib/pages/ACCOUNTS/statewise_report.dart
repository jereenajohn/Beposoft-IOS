import 'dart:async';
import 'dart:convert';

import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/statewise_order_list.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StateWiseReport2 extends StatefulWidget {
  const StateWiseReport2({super.key});

  @override
  State<StateWiseReport2> createState() => _StateWiseReport2State();
}

class _StateWiseReport2State extends State<StateWiseReport2> {
  // ============================================================
  // THEME
  // ============================================================

  static const Color primaryBlue = Color(0xFF175CD3);
  static const Color darkBlue = Color(0xFF102A56);
  static const Color backgroundColor = Color(0xFFF4F7FC);
  static const Color textColor = Color(0xFF172B4D);
  static const Color secondaryText = Color(0xFF667085);

  static const Color successColor = Color(0xFF079455);
  static const Color warningColor = Color(0xFFF79009);
  static const Color dangerColor = Color(0xFFD92D20);

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> expensedata = [];

  List<Map<String, dynamic>> sta = [];

  int? selectedstaffId;

  final TextEditingController searchController =
      TextEditingController();

  Timer? _searchDebounce;

  DateTime startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime endDate = DateTime.now();

  // ============================================================
  // PAGINATION
  // ============================================================

  int currentPage = 1;

  int totalPages = 1;

  int totalCount = 0;

  int pageSize = 50;

  bool hasNextPage = false;

  bool hasPreviousPage = false;

  // ============================================================
  // LOADING
  // ============================================================

  bool isLoading = false;

  bool isStaffLoading = false;

  String? errorMessage;

  int _requestId = 0;

  // ============================================================
  // FORMATTERS
  // ============================================================

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  final NumberFormat numberFormat = NumberFormat.decimalPattern(
    'en_IN',
  );

  final DateFormat apiDateFormat = DateFormat('yyyy-MM-dd');

  final DateFormat displayDateFormat =
      DateFormat('dd MMM yyyy');

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    getstatewisereport();

    getstaff();
  }

  @override
  void dispose() {
    _requestId++;

    _searchDebounce?.cancel();

    searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String?> gettokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('token');
  }

  Future<String?> getdepFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('department');
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _currency(dynamic value) {
    return currencyFormat.format(_toDouble(value));
  }

  String _number(dynamic value) {
    return numberFormat.format(_toInt(value));
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkBlue,
      ),
    );
  }

  // ============================================================
  // BUILD API URL
  // ============================================================

  Uri _buildReportUri(int page) {
    final Map<String, String> queryParameters = {
      'start_date': apiDateFormat.format(startDate),
      'end_date': apiDateFormat.format(endDate),
      'page': page.toString(),
    };

    // Staff filter

    if (selectedstaffId != null) {
      queryParameters['staff'] =
          selectedstaffId.toString();
    }

    // Search filter

    final search = searchController.text.trim();

    if (search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    final baseUri = Uri.parse(
      '$api/api/state/wise/report/',
    );

    return baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        ...queryParameters,
      },
    );
  }

  // ============================================================
  // STATE WISE REPORT API
  // ============================================================

  Future<void> getstatewisereport({
    int page = 1,
  }) async {
    final int requestId = ++_requestId;

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = true;

      errorMessage = null;
    });

    try {
      final token = await gettokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Session expired. Please login again.',
        );
      }

      final uri = _buildReportUri(page);

      debugPrint(
        'STATE WISE REPORT REQUEST: $uri',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (!mounted || requestId != _requestId) {
        return;
      }

      debugPrint(
        'STATE WISE REPORT STATUS: ${response.statusCode}',
      );

      if (response.statusCode == 401) {
        throw Exception(
          'Session expired. Please login again.',
        );
      }

      if (response.statusCode != 200) {
        String message =
            'Unable to fetch state-wise report.';

        try {
          final error = jsonDecode(response.body);

          if (error is Map) {
            message =
                error['message']?.toString() ??
                error['detail']?.toString() ??
                message;
          }
        } catch (_) {}

        throw Exception(message);
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Invalid API response format.',
        );
      }

      if (decoded['status'] != null &&
          decoded['status'] != 'success') {
        throw Exception(
          decoded['message'] ??
              'Unable to fetch report.',
        );
      }

      final rawData = decoded['data'];

      if (rawData is! List) {
        throw const FormatException(
          'Invalid state-wise report data.',
        );
      }

      final List<Map<String, dynamic>> reportData =
          rawData
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(
                  item,
                ),
              )
              .toList();

      final int fetchedTotalPages =
          _toInt(decoded['total_pages']);

      final int fetchedCurrentPage =
          _toInt(decoded['current_page']);

      final int fetchedPageSize =
          _toInt(decoded['page_size']);

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        expensedata = reportData;

        currentPage = fetchedCurrentPage > 0
            ? fetchedCurrentPage
            : page;

        totalPages = fetchedTotalPages > 0
            ? fetchedTotalPages
            : 1;

        totalCount = _toInt(decoded['count']);

        pageSize = fetchedPageSize > 0
            ? fetchedPageSize
            : 50;

        hasNextPage = decoded['next'] != null;

        hasPreviousPage =
            decoded['previous'] != null;

        isLoading = false;

        errorMessage = null;
      });
    } on TimeoutException {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        isLoading = false;

        errorMessage =
            'Request timed out. Please try again.';
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      debugPrint(
        'STATE WISE REPORT ERROR: $error',
      );

      setState(() {
        isLoading = false;

        errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // STAFF API
  // ============================================================

  Future<void> getstaff() async {
    if (!mounted) {
      return;
    }

    setState(() {
      isStaffLoading = true;
    });

    try {
      final token = await gettokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception('Token missing');
      }

      final response = await http
          .get(
            Uri.parse('$api/api/staffs/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch staff.',
        );
      }

      final parsed = jsonDecode(response.body);

      if (parsed is! Map) {
        throw const FormatException(
          'Invalid staff response.',
        );
      }

      final rawStaff = parsed['data'];

      if (rawStaff is! List) {
        throw const FormatException(
          'Invalid staff data.',
        );
      }

      final List<Map<String, dynamic>> staffList = [];

      for (final item in rawStaff) {
        if (item is! Map) {
          continue;
        }

        final id = int.tryParse(
          item['id'].toString(),
        );

        if (id == null) {
          continue;
        }

        staffList.add({
          'id': id,
          'name':
              item['name']?.toString() ??
              'Unknown Staff',
        });
      }

      staffList.sort(
        (a, b) => a['name']
            .toString()
            .toLowerCase()
            .compareTo(
              b['name'].toString().toLowerCase(),
            ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        sta = staffList;

        isStaffLoading = false;
      });
    } catch (error) {
      debugPrint(
        'STAFF API ERROR: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isStaffLoading = false;
      });
    }
  }

  // ============================================================
  // DATE FILTER
  // ============================================================

  Future<void> _selectDateRange(
    BuildContext context,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(
        start: startDate,
        end: endDate,
      ),
      helpText: 'SELECT REPORT DATE RANGE',
      saveText: 'APPLY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      startDate = picked.start;

      endDate = picked.end;

      currentPage = 1;
    });

    await getstatewisereport(
      page: 1,
    );
  }

  // ============================================================
  // SEARCH FILTER
  // ============================================================

  void _filterProducts(String query) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          currentPage = 1;
        });

        getstatewisereport(
          page: 1,
        );
      },
    );
  }

  // ============================================================
  // STAFF FILTER
  // ============================================================

  void _filterOrdersByStaffId(int? staffId) {
    _searchDebounce?.cancel();

    setState(() {
      selectedstaffId = staffId;

      currentPage = 1;
    });

    getstatewisereport(
      page: 1,
    );
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  Future<void> _clearFilters() async {
    _searchDebounce?.cancel();

    searchController.clear();

    setState(() {
      selectedstaffId = null;

      startDate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );

      endDate = DateTime.now();

      currentPage = 1;
    });

    await getstatewisereport(
      page: 1,
    );
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  Future<void> _goToPage(int page) async {
    if (isLoading) {
      return;
    }

    if (page < 1 || page > totalPages) {
      return;
    }

    await getstatewisereport(
      page: page,
    );
  }

  // ============================================================
  // BACK NAVIGATION
  // ============================================================

  Future<void> _navigateBack() async {
    final dep = await getdepFromPrefs();

    if (!mounted) {
      return;
    }

    Widget destination;

    switch (dep) {
      case 'BDO':
        destination = bdo_dashbord();
        break;

      case 'COO':
      case 'CEO':
        destination = ceo_dashboard();
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

      case 'Warehouse Admin':
        destination = WarehouseAdmin();
        break;

      default:
        destination = dashboard();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => destination,
      ),
    );
  }

  // ============================================================
  // COMMON CARD
  // ============================================================

  Widget _whiteCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE7ECF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
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
        gradient: const LinearGradient(
          colors: [
            darkBlue,
            primaryBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'SALES ANALYTICS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'State Wise Sales Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Track sales performance across states',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.white,
                  size: 19,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    '${displayDateFormat.format(startDate)}'
                    '  -  '
                    '${displayDateFormat.format(endDate)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                InkWell(
                  onTap: () => _selectDateRange(context),
                  child: const Icon(
                    Icons.edit_calendar_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER SECTION
  // ============================================================

  Widget _buildFilterSection() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: primaryBlue,
                size: 21,
              ),

              const SizedBox(width: 9),

              const Expanded(
                child: Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),

              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(
                  Icons.refresh,
                  size: 16,
                ),
                label: const Text(
                  'Reset',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: primaryBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // SEARCH

          TextField(
            controller: searchController,
            onChanged: _filterProducts,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search states...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: secondaryText,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: primaryBlue,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                      ),
                      onPressed: () {
                        searchController.clear();

                        _filterProducts('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: backgroundColor,
              contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 15,
                  ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // STAFF DROPDOWN

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: primaryBlue,
                  size: 21,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: sta.any(
                        (staff) =>
                            staff['id'] ==
                            selectedstaffId,
                      )
                          ? selectedstaffId
                          : null,
                      isExpanded: true,
                      hint: Text(
                        isStaffLoading
                            ? 'Loading staff...'
                            : 'All Staff',
                        style: const TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                        ),
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text(
                            'All Staff',
                            style: TextStyle(
                              fontSize: 13,
                            ),
                          ),
                        ),

                        ...sta.map(
                          (staff) =>
                              DropdownMenuItem<int>(
                            value: staff['id'],
                            child: Text(
                              staff['name'].toString(),
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: isStaffLoading
                          ? null
                          : _filterOrdersByStaffId,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // DATE FILTER

          InkWell(
            onTap: () => _selectDateRange(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_outlined,
                    color: primaryBlue,
                    size: 20,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      '${displayDateFormat.format(startDate)}'
                      ' - '
                      '${displayDateFormat.format(endDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: secondaryText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummarySection() {
    final int startItem = totalCount == 0
        ? 0
        : ((currentPage - 1) * pageSize) + 1;

    final int endItem = totalCount == 0
        ? 0
        : (startItem + expensedata.length - 1);

    return _whiteCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.public,
              color: primaryBlue,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Records',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _number(totalCount),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Showing $startItem - $endItem',
                  style: const TextStyle(
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$currentPage / $totalPages',
              style: const TextStyle(
                color: primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS ROW
  // ============================================================

  Widget _buildStatusRow({
    required String title,
    required dynamic count,
    required dynamic amount,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 17,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '${_number(count)} Orders',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Flexible(
            child: Text(
              _currency(amount),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATE CARD
  // ============================================================

  Widget _buildStateCard(
    Map<String, dynamic> stateData,
    int index,
  ) {
    final String stateName =
        stateData['name']?.toString() ??
        'Unknown State';

    final int totalOrders =
        _toInt(stateData['total_orders_count']);

    final double totalAmount =
        _toDouble(stateData['total_amount']);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StatewiseOrderList(
              state: stateName,
              initialReportPage: currentPage,
              initialStartDate: startDate,
              initialEndDate: endDate,
              initialStateData: stateData,
              initialStaffId: selectedstaffId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: _whiteCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // HEADER

            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F5FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: primaryBlue,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Text(
                      stateName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios,
                    color: primaryBlue,
                    size: 15,
                  ),
                ],
              ),
            ),

            // TOTAL

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL SALES AMOUNT',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    _currency(totalAmount),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(
                        0.08,
                      ),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_number(totalOrders)} Total Orders',
                      style: const TextStyle(
                        color: primaryBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Divider(
                    color: Color(0xFFEAECF0),
                  ),

                  // INVOICE: matches the web report's Invoice Bill/Amount columns.
                  _buildStatusRow(
                    title: 'Invoice',
                    count: stateData['total_orders_count'],
                    amount: stateData['total_amount'],
                    color: primaryBlue,
                    icon: Icons.receipt_long_outlined,
                  ),

                  // DELIVERED: API currently exposes completed_* fields.
                  _buildStatusRow(
                    title: 'Delivered',
                    count: stateData['delivered_orders_count'] ??
                        stateData['completed_orders_count'],
                    amount: stateData['delivered_amount'] ??
                        stateData['completed_amount'],
                    color: successColor,
                    icon: Icons.local_shipping_outlined,
                  ),

                  // CANCELLED
                  _buildStatusRow(
                    title: 'Cancelled',
                    count: stateData['cancelled_orders_count'],
                    amount: stateData['cancelled_amount'],
                    color: dangerColor,
                    icon: Icons.cancel_outlined,
                  ),

                  // RETURN
                  _buildStatusRow(
                    title: 'Return',
                    count: stateData['returned_orders_count'],
                    amount: stateData['returned_amount'],
                    color: const Color(0xFF7A5AF8),
                    icon: Icons.keyboard_return,
                  ),

                  // REJECTED
                  _buildStatusRow(
                    title: 'Rejected',
                    count: stateData['rejected_orders_count'],
                    amount: stateData['rejected_amount'],
                    color: warningColor,
                    icon: Icons.highlight_off_outlined,
                  ),

                  const SizedBox(height: 10),

                  const Divider(
                    color: Color(0xFFEAECF0),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'View State Orders',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),

                      const Icon(
                        Icons.arrow_forward,
                        color: primaryBlue,
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAGINATION FOOTER
  // ============================================================

  Widget _buildPagination() {
    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    return _whiteCard(
      child: Column(
        children: [
          Text(
            'Page $currentPage of $totalPages',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '${_number(totalCount)} total records',
            style: const TextStyle(
              fontSize: 11,
              color: secondaryText,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      hasPreviousPage && !isLoading
                          ? () => _goToPage(
                                currentPage - 1,
                              )
                          : null,
                  icon: const Icon(
                    Icons.chevron_left,
                    size: 19,
                  ),
                  label: const Text(
                    'Previous',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    side: const BorderSide(
                      color: Color(0xFFD0DDF5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed:
                      hasNextPage && !isLoading
                          ? () => _goToPage(
                                currentPage + 1,
                              )
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(11),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                      ),

                      SizedBox(width: 5),

                      Icon(
                        Icons.chevron_right,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // PAGE NUMBERS

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: List.generate(
                totalPages,
                (index) {
                  final page = index + 1;

                  // Show nearby pages and boundaries.

                  if (page != 1 &&
                      page != totalPages &&
                      (page - currentPage).abs() >
                          2) {
                    return const SizedBox.shrink();
                  }

                  final bool selected =
                      page == currentPage;

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 3,
                    ),
                    child: InkWell(
                      onTap: isLoading
                          ? null
                          : () => _goToPage(page),
                      borderRadius:
                          BorderRadius.circular(9),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? primaryBlue
                              : backgroundColor,
                          borderRadius:
                              BorderRadius.circular(
                            9,
                          ),
                        ),
                        child: Text(
                          page.toString(),
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : textColor,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 60,
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: primaryBlue,
            ),

            SizedBox(height: 18),

            Text(
              'Loading state-wise report...',
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return _whiteCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 35,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_outlined,
                size: 42,
                color: primaryBlue,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'No Records Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'No state-wise sales records match'
              ' the selected filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: secondaryText,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(
                Icons.refresh,
                size: 18,
              ),
              label: const Text(
                'Reset Filters',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return _whiteCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 30,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: dangerColor,
              size: 42,
            ),

            const SizedBox(height: 14),

            const Text(
              'Unable to Load Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              errorMessage ??
                  'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: secondaryText,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: () {
                getstatewisereport(
                  page: currentPage,
                );
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try Again',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();

        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,

        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,

          title: const Text(
            'State Wise Report',
            style: TextStyle(
              color: darkBlue,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: darkBlue,
              size: 19,
            ),
            onPressed: _navigateBack,
          ),

          actions: [
            IconButton(
              tooltip: 'Select Date Range',
              icon: const Icon(
                Icons.calendar_month_outlined,
                color: primaryBlue,
              ),
              onPressed: () {
                _selectDateRange(context);
              },
            ),

            IconButton(
              tooltip: 'Refresh Report',
              icon: const Icon(
                Icons.refresh,
                color: primaryBlue,
              ),
              onPressed: isLoading
                  ? null
                  : () {
                      getstatewisereport(
                        page: currentPage,
                      );
                    },
            ),

            const SizedBox(width: 6),
          ],
        ),

        body: RefreshIndicator(
          color: primaryBlue,

          onRefresh: () async {
            await getstatewisereport(
              page: currentPage,
            );
          },

          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.all(15),

            children: [
              // HEADER

              _buildHeader(),

              const SizedBox(height: 16),

              // FILTERS

             // FILTERS

_buildFilterSection(),

const SizedBox(height: 16),

// TOP PAGINATION

if (!isLoading &&
    errorMessage == null &&
    totalCount > 0) ...[
  _buildPagination(),

  const SizedBox(height: 16),
],

// SUMMARY

if (!isLoading &&
    errorMessage == null)
  _buildSummarySection(),

              const SizedBox(height: 16),

              // LOADING

              if (isLoading)
                _buildLoading()

              // ERROR

              else if (errorMessage != null)
                _buildErrorState()

              // EMPTY

              else if (expensedata.isEmpty)
                _buildEmptyState()

              // REPORT DATA

              else ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'State Performance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ),

                    Text(
                      '${expensedata.length} Records',
                      style: const TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                ...List.generate(
                  expensedata.length,
                  (index) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 13,
                      ),
                      child: _buildStateCard(
                        expensedata[index],
                        index,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 5),

                // PAGINATION

                _buildPagination(),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}