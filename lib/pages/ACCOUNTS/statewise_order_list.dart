import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beposoft/pages/ACCOUNTS/order.review.dart';
import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:excel/excel.dart';
import 'package:open_filex/open_filex.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StatewiseOrderList extends StatefulWidget {
  final String state;
  final int initialReportPage;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Map<String, dynamic>? initialStateData;
  final int? initialStaffId;

  const StatewiseOrderList({
    super.key,
    required this.state,
    this.initialReportPage = 1,
    this.initialStartDate,
    this.initialEndDate,
    this.initialStateData,
    this.initialStaffId,
  });

  @override
  State<StatewiseOrderList> createState() =>
      _StatewiseOrderListState();
}

class _StatewiseOrderListState extends State<StatewiseOrderList> {
  static const Color primaryBlue = Color(0xFF175CD3);
  static const Color darkBlue = Color(0xFF102A56);
  static const Color backgroundColor = Color(0xFFF4F7FC);

  final TextEditingController searchController =
      TextEditingController();

  final DateFormat apiDateFormat = DateFormat('yyyy-MM-dd');

  final DateFormat displayDateFormat =
      DateFormat('dd MMM yyyy');

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  List<Map<String, dynamic>> orders = [];

  List<Map<String, dynamic>> filteredOrders = [];

  String searchQuery = '';

  DateTime? selectedDate;
  DateTime? startDate;
  DateTime? endDate;

  bool isLoading = false;
  bool isExporting = false;

  String? errorMessage;

  static const int _pageSize = 10;
  int _currentPage = 1;
  String _appliedSearch = '';
  String? _selectedStaffId;
  String? _appliedStaffId;
  List<Map<String, dynamic>> _staffs = [];
  bool _loadingStaffs = false;
  String _role = '';

  int _requestId = 0;
  int _reportPage = 1;
  int _reportTotalPages = 1;
  String? _reportNotice;

  int loadedApiPages = 0;

  int totalApiPages = 0;

  int totalStateOrders = 0;
  int nextPage = 1;
  bool hasMore = false;
  bool isLoadingMore = false;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    startDate = widget.initialStartDate ??
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    endDate = widget.initialEndDate ?? DateTime.now();
    _reportPage = widget.initialReportPage;
    _selectedStaffId = widget.initialStaffId?.toString();
    _appliedStaffId = _selectedStaffId;
    _loadStaffs();
    fetchOrderData();
  }

  @override
  void dispose() {
    _requestId++;

    searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String?> getTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('token');
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }

    return <dynamic>[];
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _currency(dynamic value) {
    return currencyFormat.format(_asDouble(value));
  }

  String _displayDate(dynamic value) {
    final parsed = DateTime.tryParse(
      _asString(value),
    );

    if (parsed == null) {
      return _asString(value);
    }

    return DateFormat('dd MMM yy').format(parsed);
  }

  String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]+'),
          '_',
        );
  }

  String getDisplayStatus(dynamic rawStatus) {
    final status = _asString(rawStatus).trim();

    switch (status) {
      case 'Invoice Created':
        return 'Waiting For Approval';

      case 'To Print':
        return 'Delivery Order (DO)';

      case 'Packing under progress':
        return 'Printed';

      case 'Packed':
        return 'Packed For Delivery (PFD)';

      case 'Ready to ship':
        return 'Out For Delivery (OFD)';

      default:
        return status;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // STATE REPORT RESPONSE PARSER
  // ============================================================

  int _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  /// The report groups embedded order details by date and status.
  /// Flatten every *_orders array without assuming only waiting_orders.
  List<Map<String, dynamic>> _flattenReportOrders(dynamic groups) {
    final result = <Map<String, dynamic>>[];
    final ids = <String>{};
    if (groups is! List) return result;
    for (final rawGroup in groups) {
      if (rawGroup is! Map) continue;
      for (final entry in rawGroup.entries) {
        if (!entry.key.toString().endsWith('_orders') || entry.value is! List) {
          continue;
        }
        for (final rawOrder in entry.value as List) {
          if (rawOrder is! Map) continue;
          final order = Map<String, dynamic>.from(rawOrder);
          final id = _asString(order['id']);
          if (id.isNotEmpty && !ids.add(id)) continue;
          result.add(_normalizeOrder(order));
        }
      }
    }
    return result;
  }

  // ============================================================
  // NORMALIZE ORDER
  // ============================================================

  Map<String, dynamic> _normalizeOrder(
    Map<String, dynamic> orderData,
  ) {
    final customer = _asMap(
      orderData['customer'],
    );

    // State-wise report order details provide the customer name as
    // `customerName` rather than a nested customer.name field.
    final customerName = _asString(
      orderData['customerName'] ??
          customer['name'] ??
          orderData['customer_name'],
    ).trim();
    if (customerName.isNotEmpty) {
      customer['name'] = customerName;
    }

    final billingAddress = _asMap(
      orderData['billing_address'],
    );

    final bank = _asMap(
      orderData['bank'],
    );

    return {
      ...orderData,

      'id': orderData['id'],

      'invoice': orderData['invoice'],

      'manage_staff': orderData['manage_staff'],

      'customer': customer,

      'customer_name': customerName,

      'customer_id':
          customer['id'] ??
          orderData['customerID'],

      'status': orderData['status'],

      'state': orderData['state'],

      'total_amount':
          orderData['total_amount'] ?? 0,

      'order_date':
          orderData['order_date'] ?? '',

      'items': _asList(
        orderData['items'],
      ),

      'billing_address': billingAddress,

      'bank': bank,

      'warehouse': _asList(
        orderData['warehouse_data'],
      ),
    };
  }

  // ============================================================
  // STATE MATCHING
  // ============================================================

  String _normalizeState(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
  }

  bool _belongsToSelectedState(
    Map<String, dynamic> order,
  ) {
    final orderState = _normalizeState(
      _asString(order['state']),
    );

    final selectedState = _normalizeState(
      widget.state,
    );

    return orderState == selectedState;
  }

  // ============================================================
  // FETCH STATE REPORT (SAME API AS STATE WISE REPORT PAGE)
  // ============================================================

  Uri _reportUri(int page) {
    final from = selectedDate ?? startDate ??
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    final to = selectedDate ?? endDate ?? DateTime.now();
    return Uri.parse('$api/api/state/wise/report/').replace(
      queryParameters: {
        'start_date': apiDateFormat.format(from),
        'end_date': apiDateFormat.format(to),
        'page': '$page',
        if (_appliedStaffId != null && _appliedStaffId!.isNotEmpty)
          'staff_id': _appliedStaffId!,
        if (_appliedSearch.isNotEmpty) 'search': _appliedSearch,
      },
    );
  }

  // The report's pagination is global across states. Every API page must be
  // collected before displaying the selected state's complete order list.
  Future<void> _loadStaffs() async {
    if (!mounted) return;
    setState(() => _loadingStaffs = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final role = prefs.getString('active') ?? '';
      if (token == null || token.isEmpty) return;
      final response = await http.get(
        Uri.parse('$api/api/staffs/'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final raw = decoded is List
            ? decoded
            : decoded is Map
                ? (decoded['data'] ?? decoded['results'])
                : null;
        setState(() {
          _role = role;
          _staffs = raw is List
              ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
        });
      } else {
        setState(() => _role = role);
      }
    } catch (error) {
      debugPrint('STATEWISE STAFF FETCH ERROR: $error');
    } finally {
      if (mounted) setState(() => _loadingStaffs = false);
    }
  }

  Future<Map<String, dynamic>> _fetchReportPage(
    http.Client client,
    String token,
    int page,
  ) async {
    final uri = _reportUri(page);
    debugPrint('STATEWISE DETAIL REPORT REQUEST: $uri');
    final response = await client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 45));
    if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    }
    if (response.statusCode != 200) {
      throw Exception('Unable to load report page $page (HTTP ${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Invalid state-wise report response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> fetchOrderData() async {
    final requestId = ++_requestId;
    if (!mounted) return;
    setState(() {
      isLoading = true;
      isLoadingMore = false;
      errorMessage = null;
      orders = [];
      filteredOrders = [];
      totalStateOrders = 0;
      loadedApiPages = 0;
      totalApiPages = 0;
      _reportNotice = null;
      hasMore = false;
      _currentPage = 1;
    });

    final client = http.Client();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final role = prefs.getString('active') ?? '';
      if (token == null || token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }
      if (!mounted || requestId != _requestId) return;
      _role = role;
      final first = await _fetchReportPage(client, token, 1);
      if (!mounted || requestId != _requestId) return;
      final pages = _toInt(first['total_pages']).clamp(1, 1000000).toInt();
      final collected = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      Map<String, dynamic>? stateSummary;

      void addPage(Map<String, dynamic> payload) {
        for (final raw in payload['data'] as List) {
          if (raw is! Map) continue;
          if (_normalizeState(_asString(raw['name'])) !=
              _normalizeState(widget.state)) continue;
          final state = Map<String, dynamic>.from(raw);
          stateSummary ??= state;
          for (final order in _flattenReportOrders(state['orders'])) {
            if (role == 'CSO' &&
                _asString(order['family']).toLowerCase() == 'bepocart') {
              continue;
            }
            final id = _asString(order['id']);
            if (id.isNotEmpty && !seenIds.add(id)) continue;
            collected.add(order);
          }
        }
      }

      addPage(first);
      setState(() {
        loadedApiPages = 1;
        totalApiPages = pages;
      });
      // Four concurrent requests per batch, matching the React implementation.
      for (var page = 2; page <= pages; page += 4) {
        if (!mounted || requestId != _requestId) return;
        final last = (page + 3 < pages) ? page + 3 : pages;
        final responses = await Future.wait([
          for (var p = page; p <= last; p++)
            _fetchReportPage(client, token, p),
        ]);
        if (!mounted || requestId != _requestId) return;
        for (final payload in responses) {
          addPage(payload);
        }
        setState(() => loadedApiPages = last);
      }
      collected.sort((a, b) {
        final dateComparison = _asString(b['order_date'])
            .compareTo(_asString(a['order_date']));
        return dateComparison != 0
            ? dateComparison
            : _toInt(b['id']).compareTo(_toInt(a['id']));
      });
      if (!mounted || requestId != _requestId) return;
      final reportedCount = stateSummary == null
          ? 0
          : _toInt(stateSummary!['total_orders_count']);
      setState(() {
        orders = collected;
        totalStateOrders = reportedCount;
        _reportPage = 1;
        _reportTotalPages = pages;
        _reportNotice = role != 'CSO' && reportedCount > collected.length
            ? 'Showing ${collected.length} order details out of '
                '$reportedCount reported orders across $pages API pages.'
            : null;
        isLoading = false;
        errorMessage = null;
      });
      _applyFilters();
    } on TimeoutException {
      _handleFetchError(requestId, 'Request timed out. Please try again.');
    } catch (error) {
      debugPrint('STATEWISE DETAIL REPORT ERROR: $error');
      _handleFetchError(requestId,
          error.toString().replaceFirst('Exception: ', ''));
    } finally {
      client.close();
    }
  }

  void _applyReportFilters() {
    if (startDate != null && endDate != null && startDate!.isAfter(endDate!)) {
      _showMessage('Start date cannot be after end date.');
      return;
    }
    setState(() {
      _appliedSearch = searchController.text.trim();
      _appliedStaffId = _selectedStaffId;
      searchQuery = _appliedSearch;
      _currentPage = 1;
    });
    fetchOrderData();
  }

  void _resetToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    searchController.clear();
    setState(() {
      selectedDate = null;
      startDate = today;
      endDate = today;
      searchQuery = '';
      _appliedSearch = '';
      _selectedStaffId = null;
      _appliedStaffId = null;
      _currentPage = 1;
    });
    fetchOrderData();
  }

  void _handleFetchError(int requestId, String message) {
    if (!mounted || requestId != _requestId) return;
    setState(() {
      isLoading = false;
      isLoadingMore = false;
      errorMessage = message;
    });
  }

  // ============================================================
  // APPLY ALL LOCAL FILTERS
  // ============================================================

  void _applyFilters() {
    final query = searchQuery
        .trim()
        .toLowerCase();

    final results = orders.where(
      (order) {
        final customer = _asMap(
          order['customer'],
        );

        final customerName = _asString(
          customer['name'] ??
              order['customer_name'],
        ).toLowerCase();

        final invoice = _asString(
          order['invoice'],
        ).toLowerCase();

        final manageStaff = _asString(
          order['manage_staff'],
        ).toLowerCase();

        final totalAmount = _asString(
          order['total_amount'],
        ).toLowerCase();

        final status = getDisplayStatus(
          order['status'],
        ).toLowerCase();

        final matchesSearch =
            query.isEmpty ||
            customerName.contains(query) ||
            invoice.contains(query) ||
            manageStaff.contains(query) ||
            totalAmount.contains(query) ||
            status.contains(query);

        if (!matchesSearch) {
          return false;
        }

        final rawDate = _asString(
          order['order_date'],
        );

        final parsedDate = DateTime.tryParse(
          rawDate,
        );

        if (selectedDate != null) {
          if (parsedDate == null) {
            return false;
          }

          final orderDay = DateUtils.dateOnly(
            parsedDate,
          );

          final selectedDay = DateUtils.dateOnly(
            selectedDate!,
          );

          if (orderDay != selectedDay) {
            return false;
          }
        }

        if (startDate != null &&
            endDate != null) {
          if (parsedDate == null) {
            return false;
          }

          final orderDay = DateUtils.dateOnly(
            parsedDate,
          );

          final firstDay = DateUtils.dateOnly(
            startDate!,
          );

          final lastDay = DateUtils.dateOnly(
            endDate!,
          );

          if (orderDay.isBefore(firstDay) ||
              orderDay.isAfter(lastDay)) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      filteredOrders = results;
      _currentPage = 1;
    });
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _filterOrders(String query) {
    searchQuery = query;

    _applyFilters();
  }

  // ============================================================
  // SINGLE DATE FILTER
  // ============================================================

  Future<void> _selectSingleDate(
    BuildContext context,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      selectedDate = picked;
      _reportPage = 1;

      startDate = null;

      endDate = null;
    });

    await fetchOrderData();
  }

  // ============================================================
  // DATE RANGE FILTER
  // ============================================================

  Future<void> _selectDateRange(
    BuildContext context,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange:
          startDate != null &&
              endDate != null
          ? DateTimeRange(
              start: startDate!,
              end: endDate!,
            )
          : null,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      selectedDate = null;
      _reportPage = 1;

      startDate = picked.start;

      endDate = picked.end;
    });

    await fetchOrderData();
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  void _clearFilters() {
    searchController.clear();

    setState(() {
      searchQuery = '';

      selectedDate = null;
      _reportPage = widget.initialReportPage;
      _appliedSearch = '';
      _selectedStaffId = widget.initialStaffId?.toString();
      _appliedStaffId = _selectedStaffId;
      _currentPage = 1;

      startDate = widget.initialStartDate ??
          DateTime(DateTime.now().year, DateTime.now().month, 1);

      endDate = widget.initialEndDate ?? DateTime.now();
    });

    fetchOrderData();
  }

  // ============================================================
  // EXPORT HELPERS
  // ============================================================

  Map<String, dynamic> _customer(
    Map<String, dynamic> order,
  ) {
    return _asMap(
      order['customer'],
    );
  }

  Map<String, dynamic> _billing(
    Map<String, dynamic> order,
  ) {
    return _asMap(
      order['billing_address'],
    );
  }

  Map<String, dynamic> _bank(
    Map<String, dynamic> order,
  ) {
    return _asMap(
      order['bank'],
    );
  }

  List<dynamic> _items(
    Map<String, dynamic> order,
  ) {
    return _asList(
      order['items'],
    );
  }

  // ============================================================
  // EXCEL EXPORT
  // ============================================================

  Future<void> exportToExcel() async {
    if (isExporting) {
      return;
    }

    if (filteredOrders.isEmpty) {
      _showMessage(
        'No orders available to export.',
      );

      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final excel = Excel.createExcel();

      final Sheet sheet = excel['Order List'];

      final defaultSheet =
          excel.getDefaultSheet();

      if (defaultSheet != null &&
          defaultSheet != 'Order List') {
        excel.delete(defaultSheet);
      }

      // FIX:
      // Older excel package versions accept strings directly.
      // TextCellValue is not available in your installed version.

      sheet.appendRow([
        'Invoice',
        'Manager',
        'Customer Name',
        'Customer Phone',
        'Customer Email',
        'Customer Address',
        'Billing Name',
        'Billing Email',
        'Billing Phone',
        'Billing Address',
        'Billing City',
        'Billing State',
        'Billing Zipcode',
        'Bank Name',
        'Bank Account Number',
        'Bank IFSC Code',
        'Bank Branch',
        'Item Name',
        'Item Quantity',
        'Item Price',
        'Item Tax',
        'Item Discount',
        'Order Status',
        'Total Amount',
        'Order Date',
      ]);

      for (final order in filteredOrders) {
        final customer = _customer(order);

        final billing = _billing(order);

        final bank = _bank(order);

        final items = _items(order);

        final exportItems =
            items.isEmpty
            ? <dynamic>[<String, dynamic>{}]
            : items;

        for (final rawItem in exportItems) {
          final item = _asMap(rawItem);

          final values = [
            order['invoice'],
            order['manage_staff'],
            customer['name'],
            customer['phone'],
            customer['email'],
            customer['address'],
            billing['name'],
            billing['email'],
            billing['phone'],
            billing['address'],
            billing['city'],
            billing['state'],
            billing['zipcode'],
            bank['name'],
            bank['account_number'],
            bank['ifsc_code'],
            bank['branch'],
            item['name'],
            item['quantity'],
            item['price'],
            item['tax'],
            item['discount'],
            getDisplayStatus(
              order['status'],
            ),
            order['total_amount'],
            order['order_date'],
          ];

          // FIX:
          // Convert all values to strings before appending.
          // No TextCellValue dependency.

          final List<String> excelRow = values
              .map(
                (value) => _asString(value),
              )
              .toList();

          sheet.appendRow(excelRow);
        }
      }

      final bytes = excel.encode();

      if (bytes == null) {
        throw Exception(
          'Unable to generate Excel file.',
        );
      }

      final directory =
          await getTemporaryDirectory();

      final filename =
          'statewise_orders_'
          '${_safeFileName(widget.state)}.xlsx';

      final file = File(
        '${directory.path}/$filename',
      );

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      await OpenFilex.open(
        file.path,
      );
    } catch (error) {
      debugPrint(
        'STATEWISE EXCEL ERROR: $error',
      );

      _showMessage(
        'Excel export failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  Future<pw.Document> createPdf() async {
    final pdf = pw.Document();

    for (final order in filteredOrders) {
      final customer = _customer(order);

      final billing = _billing(order);

      final bank = _bank(order);

      final items = _items(order);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Center(
                child: pw.Text(
                  'Order Details',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight:
                        pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 18),

              pw.Text(
                'State: ${widget.state}',
              ),

              pw.Text(
                'Invoice: '
                '${_asString(order['invoice'])}',
              ),

              pw.Text(
                'Manager: '
                '${_asString(order['manage_staff'])}',
              ),

              pw.SizedBox(height: 12),

              pw.Text(
                'Customer Details',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.Text(
                'Name: '
                '${_asString(customer['name'])}',
              ),

              pw.Text(
                'Phone: '
                '${_asString(customer['phone'])}',
              ),

              pw.Text(
                'Email: '
                '${_asString(customer['email'])}',
              ),

              pw.Text(
                'Address: '
                '${_asString(customer['address'])}',
              ),

              pw.SizedBox(height: 12),

              pw.Text(
                'Billing Address',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.Text(
                'Name: '
                '${_asString(billing['name'])}',
              ),

              pw.Text(
                'Email: '
                '${_asString(billing['email'])}',
              ),

              pw.Text(
                'Phone: '
                '${_asString(billing['phone'])}',
              ),

              pw.Text(
                'Address: '
                '${_asString(billing['address'])}',
              ),

              pw.Text(
                'City: '
                '${_asString(billing['city'])}',
              ),

              pw.Text(
                'State: '
                '${_asString(billing['state'])}',
              ),

              pw.Text(
                'Zipcode: '
                '${_asString(billing['zipcode'])}',
              ),

              pw.SizedBox(height: 12),

              pw.Text(
                'Bank Details',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.Text(
                'Name: '
                '${_asString(bank['name'])}',
              ),

              pw.Text(
                'Account Number: '
                '${_asString(bank['account_number'])}',
              ),

              pw.Text(
                'IFSC Code: '
                '${_asString(bank['ifsc_code'])}',
              ),

              pw.Text(
                'Branch: '
                '${_asString(bank['branch'])}',
              ),

              pw.SizedBox(height: 12),

              pw.Text(
                'Items',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.Table.fromTextArray(
                headers: const [
                  'Name',
                  'Qty',
                  'Price',
                  'Tax',
                  'Discount',
                ],
                data: items
                    .map(
                      (rawItem) {
                        final item = _asMap(
                          rawItem,
                        );

                        return [
                          _asString(
                            item['name'],
                          ),
                          _asString(
                            item['quantity'],
                          ),
                          _asString(
                            item['price'],
                          ),
                          _asString(
                            item['tax'],
                          ),
                          _asString(
                            item['discount'],
                          ),
                        ];
                      },
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle:
                    const pw.TextStyle(
                  fontSize: 8,
                ),
                headerDecoration:
                    const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
              ),

              pw.SizedBox(height: 12),

              pw.Text(
                'Order Summary',
                style: pw.TextStyle(
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.Text(
                'Status: '
                '${getDisplayStatus(order['status'])}',
              ),

              pw.Text(
                'Total Amount: '
                '${_asString(order['total_amount'])}',
              ),

              pw.Text(
                'Order Date: '
                '${_asString(order['order_date'])}',
              ),
            ];
          },
        ),
      );
    }

    return pdf;
  }

  Future<void> downloadPdf() async {
    if (isExporting) {
      return;
    }

    if (filteredOrders.isEmpty) {
      _showMessage(
        'No orders available to export.',
      );

      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final pdf = await createPdf();

      final bytes = await pdf.save();

      final directory =
          await getTemporaryDirectory();

      final filename =
          'statewise_orders_'
          '${_safeFileName(widget.state)}.pdf';

      final file = File(
        '${directory.path}/$filename',
      );

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    } catch (error) {
      debugPrint(
        'STATEWISE PDF ERROR: $error',
      );

      _showMessage(
        'PDF export failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  // ============================================================
  // ORDER DETAILS NAVIGATION
  // ============================================================

  void _openOrderDetails(
    Map<String, dynamic> order,
  ) {
    final customer = _customer(order);

    final orderId = order['id'];

    final customerId =
        customer['id'] ??
        order['customer_id'] ??
        order['customerID'] ??
        order['customer'];

    if (orderId == null ||
        customerId == null) {
      _showMessage(
        'Order or customer ID is missing.',
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderReview(
          id: orderId,
          customer: customerId,
        ),
      ),
    );
  }

  // ============================================================
  // FILTER INFORMATION
  // ============================================================

  Widget _buildStaffFilter() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        value: _selectedStaffId != null &&
                _staffs.any((s) => _asString(s['id']) == _selectedStaffId)
            ? _selectedStaffId
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Filter by Staff',
          prefixIcon: const Icon(Icons.person_search, color: primaryBlue),
          filled: true,
          fillColor: backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        ),
        hint: Text(_loadingStaffs ? 'Loading staff...' : 'All Staff'),
        items: [
          const DropdownMenuItem<String>(value: '', child: Text('All Staff')),
          ..._staffs.map((staff) => DropdownMenuItem<String>(
                value: _asString(staff['id']),
                child: Text(
                  '${_asString(staff['name'])} '
                  '(${_asString(staff['family_name'])})',
                  overflow: TextOverflow.ellipsis,
                ),
              )),
        ],
        onChanged: isLoading
            ? null
            : (value) => setState(() {
                  _selectedStaffId = value == null || value.isEmpty ? null : value;
                }),
      ),
    );
  }

  Widget _buildOrderPagination() {
    final pageCount = (filteredOrders.length / _pageSize).ceil();
    if (pageCount <= 1) return const SizedBox.shrink();
    final from = (_currentPage - 1) * _pageSize + 1;
    final to = (_currentPage * _pageSize).clamp(0, filteredOrders.length);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Text('Showing $from–$to of ${filteredOrders.length}',
              style: const TextStyle(fontSize: 12, color: darkBlue)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _currentPage <= 1
                    ? null
                    : () => setState(() => _currentPage--),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              Text('Page $_currentPage of $pageCount',
                  style: const TextStyle(fontSize: 12, color: darkBlue)),
              TextButton.icon(
                onPressed: _currentPage >= pageCount
                    ? null
                    : () => setState(() => _currentPage++),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDateFilter() {
    String? label;

    if (selectedDate != null) {
      label = displayDateFormat.format(
        selectedDate!,
      );
    } else if (startDate != null &&
        endDate != null) {
      label =
          '${displayDateFormat.format(startDate!)}'
          ' - '
          '${displayDateFormat.format(endDate!)}';
    }

    if (label == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 10,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.date_range,
            color: primaryBlue,
            size: 17,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: darkBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          TextButton(
            onPressed: _clearFilters,
            child: const Text(
              'Clear Filters',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget _buildOrderCard(
    Map<String, dynamic> order,
  ) {
    final customer = _customer(order);

    final customerName = _asString(
      customer['name'] ??
          order['customer_name'],
    );

    final invoice = _asString(
      order['invoice'],
    );

    final manageStaff = _asString(
      order['manage_staff'],
    );

    final status = getDisplayStatus(
      order['status'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
        ),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(15),
          onTap: () {
            _openOrderDetails(order);
          },
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration:
                    const BoxDecoration(
                  color: primaryBlue,
                  borderRadius:
                      BorderRadius.only(
                    topLeft:
                        Radius.circular(15),
                    topRight:
                        Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#$invoice',
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      _displayDate(
                        order['order_date'],
                      ),
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: '
                      '${customerName.isEmpty ? 'N/A' : customerName}',
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                        color: darkBlue,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      'Staff: '
                      '${manageStaff.isEmpty ? 'N/A' : manageStaff}',
                      style:
                          const TextStyle(
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Row(
                      children: [
                        const Text(
                          'Status: ',
                          style:
                              TextStyle(
                            fontSize: 13,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            status,
                            style:
                                const TextStyle(
                              fontSize: 13,
                              color:
                                  primaryBlue,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    const Divider(
                      height: 1,
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Billing Amount:',
                            style:
                                TextStyle(
                              fontSize: 13,
                            ),
                          ),
                        ),

                        Flexible(
                          child: Text(
                            _currency(
                              order[
                                  'total_amount'],
                            ),
                            textAlign:
                                TextAlign.end,
                            style:
                                const TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(
                                0xFF079455,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        Text(
                          'View Invoice',
                          style:
                              TextStyle(
                            fontSize: 12,
                            color:
                                primaryBlue,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                        SizedBox(
                          width: 4,
                        ),

                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color:
                              primaryBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: primaryBlue,
          ),

          const SizedBox(
            height: 18,
          ),

          const Text(
            'Loading state orders...',
            style: TextStyle(
              color: darkBlue,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            loadedApiPages > 0
                ? 'Loaded $loadedApiPages API pages'
                : 'Fetching orders...',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 45,
              color: Colors.red,
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              'Unable to Load Orders',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
                color: darkBlue,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              errorMessage ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 18,
            ),

            ElevatedButton.icon(
              onPressed:
                  fetchOrderData,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: primaryBlue,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              'No orders found for '
              '${widget.state}',
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
                color: darkBlue,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'No order details were provided for this state '
              'in the selected report date range.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 15,
            ),

            TextButton.icon(
              onPressed:
                  _clearFilters,
              icon: const Icon(
                Icons.filter_alt_off,
              ),
              label: const Text(
                'Clear Filters',
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
    return Scaffold(
      backgroundColor:
          backgroundColor,

      appBar: AppBar(
        backgroundColor:
            Colors.white,

        foregroundColor:
            darkBlue,

        elevation: 0,

        title: Text(
          '${widget.state} Orders',
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Single Date',
            icon: const Icon(
              Icons.calendar_today,
              color: primaryBlue,
            ),
            onPressed: () {
              _selectSingleDate(
                context,
              );
            },
          ),

          IconButton(
            tooltip:
                'Date Range',
            icon: const Icon(
              Icons.date_range,
              color: primaryBlue,
            ),
            onPressed: () {
              _selectDateRange(
                context,
              );
            },
          ),

          PopupMenuButton<String>(
            enabled:
                !isExporting,

            icon: const Icon(
              Icons.more_vert,
            ),

            onSelected: (value) {
              switch (value) {
                case 'excel':
                  exportToExcel();
                  break;

                case 'pdf':
                  downloadPdf();
                  break;
              }
            },

            itemBuilder:
                (context) => const [
              PopupMenuItem<String>(
                value: 'excel',
                child: Text(
                  'Export Excel',
                ),
              ),

              PopupMenuItem<String>(
                value: 'pdf',
                child: Text(
                  'Download PDF',
                ),
              ),
            ],
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: fetchOrderData,
        color: primaryBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // SEARCH, STAFF FILTER, DATE FILTER AND ORDER COUNT
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.fromLTRB(
              15,
              10,
              15,
              12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                TextField(
                  controller:
                      searchController,

                  onChanged:
                      _filterOrders,

                  decoration:
                      InputDecoration(
                    hintText:
                        'Search orders...',

                    prefixIcon:
                        const Icon(
                      Icons.search,
                      color:
                          primaryBlue,
                    ),

                    suffixIcon:
                        searchQuery.isNotEmpty
                        ? IconButton(
                            icon:
                                const Icon(
                              Icons.close,
                            ),
                            onPressed:
                                () {
                              searchController
                                  .clear();

                              _filterOrders(
                                '',
                              );
                            },
                          )
                        : null,

                    filled: true,

                    fillColor:
                        backgroundColor,

                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                ),

                _buildStaffFilter(),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _applyReportFilters,
                          icon: const Icon(Icons.tune_rounded, size: 19),
                          label: const Text('Apply Filter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: primaryBlue.withOpacity(0.45),
                            disabledForegroundColor: Colors.white70,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _resetToday,
                        icon: const Icon(Icons.today_outlined, size: 18),
                        label: const Text('Today'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBlue,
                          side: const BorderSide(color: Color(0xFFD4E2F5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                _buildActiveDateFilter(),

                const SizedBox(
                  height: 12,
                ),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${filteredOrders.length} Matching Orders'
                        ' • $totalStateOrders State Total',
                        style:
                            const TextStyle(
                          color:
                              darkBlue,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    IconButton(
                      tooltip:
                          'Refresh Orders',
                      onPressed:
                          isLoading
                          ? null
                          : fetchOrderData,

                      icon:
                          const Icon(
                        Icons.refresh,
                        color:
                            primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

            // ORDER LIST: THE WHOLE PAGE SCROLLS TOGETHER.
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 90),
                child: _buildLoading(),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 65),
                child: _buildError(),
              )
            else if (filteredOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 65),
                child: _buildEmpty(),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Column(
                  children: [
                    for (var index = (_currentPage - 1) * _pageSize;
                        index < filteredOrders.length &&
                            index < _currentPage * _pageSize;
                        index++)
                      _buildOrderCard(filteredOrders[index]),
                    if (_reportNotice != null &&
                        _currentPage ==
                            (filteredOrders.length / _pageSize).ceil())
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _reportNotice!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: darkBlue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // PAGINATION ONLY AT THE END OF THE ORDER CARDS.
              _buildOrderPagination(),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
