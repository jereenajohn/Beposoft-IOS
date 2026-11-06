import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
import 'package:intl/intl.dart' hide TextDirection;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Uses the same existing dependencies as GSTReportPage. No chart package needed.
const Color _blue = Color(0xFF2858DF);
const Color _navy = Color(0xFF14213D);
const Color _muted = Color(0xFF72819A);
const Color _background = Color(0xFFF4F7FC);
const Color _border = Color(0xFFE5EAF3);

final NumberFormat _moneyFormat =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final NumberFormat _numberFormat = NumberFormat.decimalPattern('en_IN');
final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
final DateFormat _uiDateFormat = DateFormat('dd MMM yyyy');

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
}

String _money(dynamic value) => _moneyFormat.format(_toDouble(value));
String _number(dynamic value) => _numberFormat.format(_toDouble(value));

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map<String, dynamic>((dynamic key, dynamic item) =>
        MapEntry<String, dynamic>(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _rows(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map(_map).toList(growable: false);
}

String _display(dynamic value) {
  if (value == null || value == '') return '—';
  if (value is Map || value is List) return jsonEncode(value);
  return value.toString();
}

String _label(String key) => key
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

class _ReportTab {
  const _ReportTab(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const List<_ReportTab> _tabs = <_ReportTab>[
  _ReportTab('overview', 'Overview', Icons.bar_chart_rounded),
  _ReportTab('orders', 'Orders', Icons.shopping_cart_outlined),
  _ReportTab('order_items', 'Order Items', Icons.inventory_2_outlined),
  _ReportTab('advance_receipts', 'Advances', Icons.account_balance_wallet_outlined),
  _ReportTab('payment_receipts', 'Payments', Icons.credit_card_outlined),
  _ReportTab('commission_receipts', 'Commissions', Icons.receipt_long_outlined),
  _ReportTab('refund_receipts', 'Refunds', Icons.replay_outlined),
  _ReportTab('advance_transfers', 'Transfers', Icons.trending_up_rounded),
  _ReportTab('grv', 'GRV / Returns', Icons.assignment_return_outlined),
];

const Map<String, List<String>> _tableColumns = <String, List<String>>{
  'orders': <String>[
    'invoice', 'order_date', 'status', 'payment_status', 'total_amount',
    'staff_name',
  ],
  'order_items': <String>[
    'invoice', 'product_name', 'quantity', 'rate', 'discount_total',
    'tax_amount', 'total_with_tax',
  ],
  'advance_receipts': <String>[
    'payment_receipt', 'received_at', 'amount', 'bank_name',
    'transactionID', 'remark',
  ],
  'payment_receipts': <String>[
    'invoice', 'payment_receipt', 'received_at', 'amount', 'bank_name',
    'transactionID',
  ],
  'commission_receipts': <String>[
    'invoice', 'payment_receipt', 'received_at', 'amount', 'bank_name',
  ],
  'refund_receipts': <String>[
    'refund_no', 'invoice', 'date', 'amount', 'bank_name', 'note',
  ],
  'advance_transfers': <String>[
    'send_from_name', 'send_to_name', 'direction', 'date', 'amount',
  ],
  'grv': <String>[
    'invoice', 'product_name', 'quantity', 'returnreason', 'remark',
    'status', 'total_value',
  ],
};

class _Metric {
  const _Metric(this.title, this.key, this.icon, this.color,
      {this.currency = true, this.subtitle});
  final String title;
  final String key;
  final IconData icon;
  final Color color;
  final bool currency;
  final String? subtitle;
}

const List<_Metric> _metrics = <_Metric>[
  _Metric('Total Sales', 'total_sales', Icons.currency_rupee_rounded, _blue,
      subtitle: 'Invoice sales'),
  _Metric('Total Orders', 'total_orders', Icons.shopping_cart_outlined,
      Color(0xFF8B5CF6), currency: false, subtitle: 'Customer orders'),
  _Metric('Average Order Value', 'average_order_value',
      Icons.trending_up_rounded, Color(0xFF10A977)),
  _Metric('Quantity Sold', 'total_product_quantity',
      Icons.inventory_2_outlined, Color(0xFFF3A03C), currency: false),
  _Metric('Gross Product Value', 'total_gross_value',
      Icons.account_balance_wallet_outlined, _blue),
  _Metric('Total Discount', 'total_discount', Icons.receipt_long_outlined,
      Color(0xFFF3A03C)),
  _Metric('Tax Amount', 'total_tax_amount', Icons.description_outlined,
      Color(0xFF8B5CF6)),
  _Metric('Item Value With Tax', 'total_items_with_tax',
      Icons.currency_rupee_rounded, Color(0xFF10A977)),
  _Metric('Payment Receipts', 'total_payment_receipts',
      Icons.credit_card_outlined, Color(0xFF10A977)),
  _Metric('Advance Receipts', 'total_advance_receipts',
      Icons.account_balance_wallet_outlined, _blue),
  _Metric('Refund Amount', 'total_refunds', Icons.replay_outlined,
      Color(0xFFED6179)),
  _Metric('GRV Value', 'total_grv_value', Icons.inventory_2_outlined,
      Color(0xFFED6179)),
];

/// Port of the React CustomerCompleteReport page.
///
/// Open the page and select a customer in Report Filters:
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const CustomerCompleteReportPage(),
/// ));
class CustomerCompleteReportPage extends StatefulWidget {
  const CustomerCompleteReportPage({super.key, this.customerId});

  final Object? customerId;

  @override
  State<CustomerCompleteReportPage> createState() =>
      _CustomerCompleteReportPageState();
}

class _CustomerCompleteReportPageState extends State<CustomerCompleteReportPage> {
  static const String _endpoint =
      'https://bepocart.in/api/customer/complete/report/';

  Map<String, dynamic>? _report;
  bool _loading = true;
  String _error = '';
  String _activeTab = 'overview';
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _appliedStartDate;
  DateTime? _appliedEndDate;
  int _requestSequence = 0;
  String? _selectedCustomerId;
  String? _appliedCustomerId;
  String _selectedCustomerName = '';
  bool _customerDropdownOpen = false;
  String _appliedCustomerName = '';

  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  int _pageSize = 10;
  bool _exportingCsv = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = _initialCustomerId(widget.customerId);
    _appliedCustomerId = _selectedCustomerId;
    Future<void>.microtask(_fetchReport);
  }

  @override
  void didUpdateWidget(covariant CustomerCompleteReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId.toString() != widget.customerId.toString()) {
      _selectedCustomerId = _initialCustomerId(widget.customerId);
      _appliedCustomerId = _selectedCustomerId;
      _selectedCustomerName = '';
      _appliedCustomerName = '';
      _report = null;
      _resetTable();
      _fetchReport();
    }
  }

  @override
  void dispose() {
    _requestSequence++;
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> _getDepartment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  Future<void> _navigateBack() async {
    if (!mounted) return;
    final department = await _getDepartment();
    if (!mounted) return;

    Widget destination;
    switch (department) {
      case 'BDO':
        destination = bdo_dashbord();
        break;
      case 'BDM':
        destination = bdm_dashbord();
        break;
      case 'HR':
        destination = HrDashboard();
        break;
      case 'warehouse':
        destination = WarehouseDashboard();
        break;
      case 'COO':
      case 'CEO':
        destination = ceo_dashboard();
        break;
      case 'CSO':
        destination = cso_dashboard();
        break;
      case 'Marketing':
        destination = marketing_dashboard();
        break;
      case 'OPERATIONS':
        destination = OperationsExecutiveDashboard();
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
  }

  String? _initialCustomerId(Object? value) {
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  void _chooseCustomer() {
    setState(() => _customerDropdownOpen = !_customerDropdownOpen);
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomerId = customer['id'].toString();
      _selectedCustomerName = _display(customer['name']) == '—'
          ? 'Customer #${customer['id']}' : customer['name'].toString();
      _customerDropdownOpen = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchReport() async {
    final int request = ++_requestSequence;
    final customerId = _appliedCustomerId;
    if (customerId == null || customerId.isEmpty) {
      if (mounted) {
        setState(() {
          _report = null;
          _loading = false;
          _error = '';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw const FormatException('Login token missing. Please log in again.');
      }

      final query = <String, String>{'customer_id': customerId};
      if (_appliedStartDate != null) {
        query['start_date'] = _apiDateFormat.format(_appliedStartDate!);
      }
      if (_appliedEndDate != null) {
        query['end_date'] = _apiDateFormat.format(_appliedEndDate!);
      }

      final uri = Uri.parse(_endpoint).replace(queryParameters: query);
      final response = await http.get(uri, headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 30));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const FormatException('Server returned an invalid JSON response.');
      }

      if (response.statusCode != 200) {
        final errorBody = _map(decoded);
        final detail = errorBody['message'] ?? errorBody['detail'] ??
            'Unable to load customer report (HTTP ${response.statusCode}).';
        throw FormatException(detail.toString());
      }

      if (decoded is! Map) {
        throw const FormatException('Unexpected customer report response.');
      }

      if (!mounted || request != _requestSequence) return;
      setState(() {
        _report = _map(decoded);
        final customerName =
            _map(_report!['customer'])['name']?.toString().trim() ?? '';
        if (customerName.isNotEmpty) {
          _appliedCustomerName = customerName;
          if (_selectedCustomerId == customerId) {
            _selectedCustomerName = customerName;
          }
        }
        _loading = false;
        _error = '';
      });
    } catch (error) {
      if (!mounted || request != _requestSequence) return;
      final message = error is FormatException
          ? error.message
          : error is SocketException
              ? 'Network unavailable. Please check your connection.'
              : error.toString().contains('TimeoutException')
                  ? 'The report request timed out. Please try again.'
                  : 'Unable to load customer report. Please try again.';
      setState(() {
        _report = null;
        _loading = false;
        _error = message;
      });
    }
  }

  void _applyFilters() {
    if (_selectedCustomerId == null) {
      _message('Please select a customer.', error: true);
      return;
    }
    if (_startDate != null && _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      setState(() => _error = 'Start date cannot be after end date.');
      return;
    }
    setState(() {
      _error = '';
      _appliedCustomerId = _selectedCustomerId;
      _appliedCustomerName = _selectedCustomerName;
      _report = null;
      _appliedStartDate = _startDate;
      _appliedEndDate = _endDate;
    });
    _resetTable();
    _fetchReport();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _appliedStartDate = null;
      _appliedEndDate = null;
      _error = '';
    });
    _resetTable();
    _fetchReport();
  }

  void _resetTable() {
    _searchController.clear();
    if (mounted) setState(() => _page = 1);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _blue),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = date;
      } else {
        _endDate = date;
      }
    });
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFC24148) : _navy,
    ));
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> rows, String section) async {
    if (rows.isEmpty || _exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      // Match React's CSV export: include every field in the filtered rows.
      final keys = <String>[];
      final seen = <String>{};
      for (final row in rows) {
        for (final key in row.keys) {
          if (seen.add(key)) keys.add(key);
        }
      }

      String csvCell(dynamic value) {
        String raw;
        if (value == null) {
          raw = '';
        } else if (value is List || value is Map) {
          raw = jsonEncode(value);
        } else {
          raw = value.toString();
        }
        // Prevent spreadsheet formula execution when CSV is opened in Excel.
        if (raw.isNotEmpty && RegExp(r'^[=+\-@\t\r]').hasMatch(raw)) {
          raw = "'$raw";
        }
        return '"${raw.replaceAll('"', '""')}"';
      }

      final buffer = StringBuffer('\uFEFF');
      buffer.writeln(keys.map(csvCell).join(','));
      for (final row in rows) {
        buffer.writeln(keys.map((key) => csvCell(row[key])).join(','));
      }

      final directory = await getApplicationDocumentsDirectory();
      final safeId = (_appliedCustomerId ?? '').replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${directory.path}/customer_${safeId}_$section.csv');
      await file.writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      _message('CSV exported successfully');
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        _message('Saved to ${file.path}');
      }
    } catch (error) {
      _message('Could not export CSV: $error', error: true);
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report ?? <String, dynamic>{};
    final customer = _map(report['customer']);
    final overall = _map(report['overall_summary']);
    final sections = _map(report['sections']);
    final graphs = _map(report['graphs']);

    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();
        return false;
      },
      child: Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: _navy,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _navigateBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Customer Complete Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _fetchReport,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _fetchReport,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1550),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _customerHeader(customer),
                    const SizedBox(height: 16),
                    _filterPanel(),
                    if (_error.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _alert(_error),
                    ],
                    const SizedBox(height: 20),
                    if (_loading)
                      _loadingPanel()
                    else if (_appliedCustomerId == null)
                      _emptyPanel('Select a customer in Report Filters and tap Apply.')
                    else if (_report == null)
                      _emptyPanel('No customer report available.',
                          action: TextButton.icon(
                            onPressed: _fetchReport,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ))
                    else ...<Widget>[
                      _heading('Financial overview',
                          'Key performance indicators for the selected period'),
                      const SizedBox(height: 12),
                      _summaryGrid(overall),
                      const SizedBox(height: 24),
                      _heading('Detailed analytics',
                          'Explore transactions, trends and customer activity'),
                      const SizedBox(height: 12),
                      _tabsBar(),
                      const SizedBox(height: 16),
                      if (_activeTab == 'overview')
                        _overview(customer, graphs)
                      else
                        _transactionTable(_activeTab, _map(sections[_activeTab])),
                      const SizedBox(height: 18),
                      const Text(
                        'Financial data reflects the selected API filters. '
                        'Product-filtered invoice totals and receipts may '
                        'represent full invoices containing the selected product. '
                        'This report is not a reconciled outstanding-balance statement.',
                        style: TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12, height: 1.6),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _customerHeader(Map<String, dynamic> customer) {
    final name = _display(customer['name']) == '—'
        ? (_appliedCustomerName.isNotEmpty ? _appliedCustomerName
            : _appliedCustomerId == null ? 'Select a customer'
                : 'Customer #$_appliedCustomerId')
        : _display(customer['name']);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF101F3E), Color(0xFF173A77), Color(0xFF2459A9)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0xFF122B60).withOpacity(.15),
              blurRadius: 26, offset: const Offset(0, 9)),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: <Widget>[
          Container(
            height: 63,
            width: 63,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withOpacity(.16)),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: Colors.white, size: 32),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 23,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 7, children: <Widget>[
                  _profileTag(customer['phone'], fallback: 'No phone'),
                  _profileTag(customer['city'], fallback: 'City unavailable'),
                  _profileTag(customer['customer_type_name'], fallback: 'Customer'),
                ]),
              ],
            ),
          ),
          // _profileTag(customer['customer_status'], fallback: 'Customer',
          //     emphasis: true),
        ],
      ),
    );
  }

  Widget _profileTag(dynamic value,
      {required String fallback, bool emphasis = false}) {
    final text = value == null || value.toString().trim().isEmpty
        ? fallback : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(emphasis ? 20 : 8),
        color: Colors.white.withOpacity(emphasis ? .17 : .10),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Text(text, style: const TextStyle(
          fontSize: 12, color: Color(0xFFE5EFFF),
          fontWeight: FontWeight.w600)),
    );
  }

  Widget _filterPanel() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(children: <Widget>[
            Icon(Icons.tune_rounded, color: _blue, size: 20),
            SizedBox(width: 9),
            Text('Report Filters', style: TextStyle(
                color: _navy, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 17),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final customer = _customerFilterField();
            final start = _dateField('Start Date', _startDate,
                onTap: () => _pickDate(isStart: true));
            final end = _dateField('End Date', _endDate,
                onTap: () => _pickDate(isStart: false));
            final buttons = Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _applyFilters,
                icon: const Icon(Icons.filter_alt_outlined, size: 17),
                label: const Text('Apply'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _loading ? null : _clearFilters,
                child: const Text('Clear'),
              ),
            ]);
            if (narrow) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    start, const SizedBox(height: 12), end,
                    const SizedBox(height: 12), customer,
                    const SizedBox(height: 14), buttons,
                  ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(child: start), const SizedBox(width: 14),
                  Expanded(child: end), const SizedBox(width: 14),
                  Expanded(child: customer), const SizedBox(width: 14),
                  buttons,
                ]);
          }),
        ],
      ),
    );
  }

  Widget _customerFilterField() {
    final label = _selectedCustomerName.isNotEmpty ? _selectedCustomerName
        : _selectedCustomerId == null ? 'Select customer'
            : 'Customer #$_selectedCustomerId';
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Customer', style: TextStyle(color: _muted,
            fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        InkWell(
          onTap: _loading ? null : _chooseCustomer,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFCFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F2)),
            ),
            child: Row(children: <Widget>[
              const Icon(Icons.person_outline_rounded, color: _muted, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(label, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      color: _selectedCustomerId == null ? _muted : _navy))),
              Icon(_customerDropdownOpen ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: _muted, size: 19),
            ]),
          ),
        ),
        if (_customerDropdownOpen) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.all(10),
            child: _ReportCustomerPicker(
              selectedId: _selectedCustomerId,
              onSelected: _selectCustomer,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateField(String label, DateTime? date, {required VoidCallback onTap}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: _muted,
              fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFBFCFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F2))),
              child: Row(children: <Widget>[
                const Icon(Icons.calendar_month_outlined,
                    color: _muted, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(date == null ? 'Select date' :
                    _uiDateFormat.format(date),
                    style: TextStyle(fontSize: 13,
                        color: date == null ? _muted : _navy))),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _muted, size: 19),
              ]),
            ),
          ),
        ]);
  }

  Widget _alert(String message) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFF0),
      border: Border.all(color: const Color(0xFFFFD1D5)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: <Widget>[
      const Icon(Icons.error_outline_rounded, color: Color(0xFFCB3344)),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(
          color: Color(0xFFAE2937), fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _loadingPanel() => const _Panel(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(width: 23, height: 23,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _blue)),
            SizedBox(width: 15),
            Flexible(child: Text('Loading customer analytics...',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w600))),
          ]),
    ),
  );

  Widget _emptyPanel(String message, {Widget? action}) => _Panel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(children: <Widget>[
        const Icon(Icons.inbox_outlined, size: 35, color: _muted),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 14)),
        if (action != null) action,
      ]),
    ),
  );

  Widget _heading(String title, String subtitle) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 4,
    children: <Widget>[
      Text(title, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
    ],
  );

  Widget _summaryGrid(Map<String, dynamic> summary) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1130 ? 4 :
          constraints.maxWidth >= 790 ? 3 : 2;
      const spacing = 12.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(spacing: spacing, runSpacing: spacing,
          children: _metrics.map((metric) => SizedBox(
            width: width,
            child: _metricCard(metric, summary[metric.key]),
          )).toList());
    });
  }

  Widget _metricCard(_Metric metric, dynamic value) => Container(
    constraints: const BoxConstraints(minHeight: 152),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: <BoxShadow>[
        BoxShadow(color: const Color(0xFF152F59).withOpacity(.04),
            blurRadius: 17, offset: const Offset(0, 5)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 41, height: 41,
            decoration: BoxDecoration(
              color: metric.color.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(metric.icon, color: metric.color, size: 22),
          ),
          const SizedBox(height: 13),
          Text(metric.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(metric.currency ? _money(value) : _number(value),
                maxLines: 1, style: const TextStyle(
                    color: _navy, fontSize: 23, fontWeight: FontWeight.w800)),
          ),
          if (metric.subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(metric.subtitle!, style: const TextStyle(
                color: Color(0xFF96A2B6), fontSize: 11)),
          ],
        ]),
  );

  Widget _tabsBar() => Container(
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border)),
    padding: const EdgeInsets.all(6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: _tabs.map((tab) {
        final active = tab.key == _activeTab;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: InkWell(
            onTap: () {
              setState(() => _activeTab = tab.key);
              _resetTable();
            },
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: active ? _blue : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(tab.icon, size: 17, color: active ? Colors.white : _muted),
                const SizedBox(width: 7),
                Text(tab.label, style: TextStyle(
                  color: active ? Colors.white : _muted,
                  fontSize: 13, fontWeight: FontWeight.w700,
                )),
              ]),
            ),
          ),
        );
      }).toList()),
    ),
  );

  Widget _overview(Map<String, dynamic> customer,
      Map<String, dynamic> graphs) {
    final comparison = _map(graphs['sales_comparison']);
    final comparisonRows = _rows(comparison['data']);
    final comparisonSummary = _map(comparison['summary']);
    final salesRows = _rows(_map(graphs['sales_over_time'])['data']);
    final products = _rows(_map(graphs['product_performance'])['data']);
    final statuses = _rows(_map(graphs['order_status_distribution'])['data']);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _adaptivePair(
            _ReportLineChart(
              title: 'Sales Performance', data: comparisonRows,
              primaryKey: 'current_cumulative_sales',
              secondaryKey: 'previous_cumulative_sales',
              primaryLabel: 'Selected Period',
              secondaryLabel: 'Previous Period',
            ),
            _comparisonPanel(comparisonSummary),
            leftFlex: 2, rightFlex: 1,
          ),
          const SizedBox(height: 16),
          _adaptivePair(
            _ReportLineChart(title: 'Daily Sales', data: salesRows,
                primaryKey: 'sales', primaryLabel: 'Sales'),
            _ReportLineChart(title: 'Order Trends', data: salesRows,
                primaryKey: 'orders', primaryLabel: 'Orders', currency: false),
          ),
          const SizedBox(height: 16),
          _adaptivePair(
            _HorizontalBarChart(title: 'Top Selling Products', data: products,
                labelKey: 'product_name', valueKey: 'total_with_tax'),
            _HorizontalBarChart(title: 'Order Status', data: statuses,
                labelKey: 'status', valueKey: 'count', currency: false),
          ),
          const SizedBox(height: 16),
          _adaptivePair(
            _ReportLineChart(title: 'Payment Trends', data: salesRows,
                primaryKey: 'payments', primaryLabel: 'Payments'),
            _ReportLineChart(title: 'Quantity Trends', data: salesRows,
                primaryKey: 'quantity', primaryLabel: 'Quantity', currency: false),
          ),
          const SizedBox(height: 16),
          _customerInfoPanel(customer),
        ]);
  }

  Widget _adaptivePair(Widget left, Widget right,
      {int leftFlex = 1, int rightFlex = 1}) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 850) {
        return Column(children: <Widget>[
          left, const SizedBox(height: 16), right,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
          ]);
    });
  }

  Widget _comparisonPanel(Map<String, dynamic> summary) => _Panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PanelTitle(title: 'Period Comparison',
              subtitle: 'Selected vs previous period',
              trailing: Icon(Icons.trending_up_rounded, color: _blue)),
          const SizedBox(height: 12),
          _comparisonStat('Selected Period Sales',
              _money(summary['current_period_sales'])),
          const Divider(color: _border, height: 22),
          _comparisonStat('Previous Period Sales',
              _money(summary['previous_period_sales'])),
          const Divider(color: _border, height: 22),
          _comparisonStat('Growth', summary['growth_percentage'] == null
              ? 'N/A' : '${summary['growth_percentage']}%'),
        ]),
  );

  Widget _comparisonStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 7),
      Text(value, style: const TextStyle(
          color: _navy, fontSize: 20, fontWeight: FontWeight.w800)),
    ]);

  Widget _customerInfoPanel(Map<String, dynamic> customer) {
    const fields = <MapEntry<String, String>>[
      MapEntry('Customer Name', 'name'),
      MapEntry('Phone', 'phone'),
      MapEntry('Alternative Phone', 'alt_phone'),
      MapEntry('Email', 'email'),
      MapEntry('GST Number', 'gst'),
      MapEntry('GST Confirmation', 'gst_confirm'),
      MapEntry('Customer Type', 'customer_type_name'),
      MapEntry('Manager', 'manager_name'),
      MapEntry('Family', 'family_name'),
      MapEntry('State', 'state_name'),
      MapEntry('City', 'city'),
      MapEntry('ZIP Code', 'zip_code'),
      MapEntry('Created At', 'created_at'),
      MapEntry('Address', 'address'),
      MapEntry('Comment', 'comment'),
    ];
    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PanelTitle(title: 'Customer Information',
              subtitle: 'Registered customer details',
              trailing: Icon(Icons.person_outline_rounded, color: _blue)),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth >= 940 ? 3 :
                constraints.maxWidth >= 580 ? 2 : 1;
            const spacing = 12.0;
            final width = (constraints.maxWidth - spacing * (count - 1)) / count;
            return Wrap(spacing: spacing, runSpacing: spacing,
                children: fields.map((field) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFEDF1F8)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(field.key, style: const TextStyle(
                              color: _muted, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          SelectableText(_display(customer[field.value]),
                              style: const TextStyle(color: _navy,
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                  ),
                )).toList());
          }),
        ]));
  }

  Widget _transactionTable(String sectionKey, Map<String, dynamic> section) {
    final allRows = _rows(section['data']);
    final summary = _map(section['summary']);
    final columns = _tableColumns[sectionKey] ?? <String>[];
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty ? allRows : allRows.where((row) =>
      columns.any((column) => _display(row[column]).toLowerCase().contains(query))
    ).toList(growable: false);
    final totalPages = math.max(1, (filtered.length / _pageSize).ceil());
    final page = math.max(1, math.min(_page, totalPages));
    final start = (page - 1) * _pageSize;
    final end = math.min(start + _pageSize, filtered.length);
    final visible = filtered.sublist(start, end);
    final sectionName = _tabs.firstWhere((t) => t.key == sectionKey).label;

    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(builder: (context, constraints) {
            final title = _PanelTitle(title: sectionName,
                subtitle: '${_number(allRows.length)} total records');
            final exportButton = OutlinedButton.icon(
              onPressed: filtered.isEmpty || _exportingCsv
                  ? null : () => _exportCsv(filtered, sectionKey),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _exportingCsv
                  ? const SizedBox(width: 16, height: 16, child:
                      CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export CSV'),
            );
            if (constraints.maxWidth < 460) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    title, const SizedBox(height: 14), exportButton,
                  ]);
            }
            return Row(children: <Widget>[
              Expanded(child: title), exportButton,
            ]);
          }),
          if (summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10,
                children: summary.entries.where((entry) =>
                    entry.value != null &&
                    entry.value is! List && entry.value is! Map)
                    .map((entry) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, children: <Widget>[
                            Text(_label(entry.key), style: const TextStyle(
                                fontSize: 11, color: _muted)),
                            const SizedBox(height: 4),
                            Text(_display(entry.value), style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: _navy)),
                          ]),
                    )).toList()),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final search = TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _page = 1),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search ${sectionName.toLowerCase()}...',
                hintStyle: const TextStyle(color: _muted),
                prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
                suffixIcon: _searchController.text.isEmpty ? null : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _page = 1);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFFBFCFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _blue),
                ),
              ),
            );
            final sizeSelector = DropdownButtonFormField<int>(
              value: _pageSize,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              items: const <int>[10, 25, 50, 100]
                  .map((size) => DropdownMenuItem<int>(
                      value: size, child: Text('$size rows',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (size) {
                if (size == null) return;
                setState(() {
                  _pageSize = size;
                  _page = 1;
                });
              },
            );
            if (constraints.maxWidth < 510) {
              return Column(children: <Widget>[
                search, const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: sizeSelector),
              ]);
            }
            return Row(children: <Widget>[
              Expanded(child: search), const SizedBox(width: 12),
              SizedBox(width: 138, child: sizeSelector),
            ]);
          }),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFF4F7FC)),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 72,
                columnSpacing: 22,
                horizontalMargin: 16,
                headingTextStyle: const TextStyle(
                    color: Color(0xFF62718A), fontSize: 11,
                    fontWeight: FontWeight.w800),
                dataTextStyle: const TextStyle(
                    color: _navy, fontSize: 12),
                columns: <DataColumn>[
                  const DataColumn(label: Text('#')),
                  ...columns.map((column) => DataColumn(
                    label: Text(_label(column).toUpperCase()),
                  )),
                ],
                rows: visible.asMap().entries.map((entry) {
                  final row = entry.value;
                  return DataRow(cells: <DataCell>[
                    DataCell(Text('${start + entry.key + 1}')),
                    ...columns.map((column) => DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: <String>{'status', 'payment_status', 'direction'}
                                .contains(column)
                            ? _statusChip(_display(row[column]))
                            : Text(_display(row[column]),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No matching records found',
                  style: TextStyle(color: _muted, fontSize: 13))),
            ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final showing = Text(
              'Showing ${filtered.isEmpty ? 0 : start + 1}–$end of ${filtered.length}',
              style: const TextStyle(color: _muted, fontSize: 12),
            );
            final controls = Row(mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: page <= 1 ? null : () =>
                        setState(() => _page = page - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text('Page $page of $totalPages', style: const TextStyle(
                      fontSize: 12, color: _navy, fontWeight: FontWeight.w700)),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: page >= totalPages ? null : () =>
                        setState(() => _page = page + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ]);
            if (constraints.maxWidth < 450) {
              return Column(children: <Widget>[showing, controls]);
            }
            return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[showing, controls]);
          }),
        ]));
  }

  Widget _statusChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _blue,
            fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _border),
      boxShadow: <BoxShadow>[
        BoxShadow(color: const Color(0xFF152F59).withOpacity(.035),
            blurRadius: 22, offset: const Offset(0, 5)),
      ],
    ),
    child: child,
  );
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: <Widget>[
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: _navy,
              fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
        ])),
    if (trailing != null) trailing!,
  ]);
}

/// Sales/quantity chart drawn directly in Flutter. It corresponds to the
/// React SVG line chart and supports All / Current / Previous series.
class _ReportLineChart extends StatefulWidget {
  const _ReportLineChart({
    required this.title,
    required this.data,
    required this.primaryKey,
    required this.primaryLabel,
    this.secondaryKey,
    this.secondaryLabel = 'Previous',
    this.currency = true,
  });

  final String title;
  final List<Map<String, dynamic>> data;
  final String primaryKey;
  final String primaryLabel;
  final String? secondaryKey;
  final String secondaryLabel;
  final bool currency;

  @override
  State<_ReportLineChart> createState() => _ReportLineChartState();
}

class _ReportLineChartState extends State<_ReportLineChart> {
  String _selection = 'all';

  @override
  Widget build(BuildContext context) {
    return _Panel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelTitle(title: widget.title,
            subtitle: 'Performance over the selected period'),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
          _seriesToggle('All', 'all'),
          _seriesToggle('Current', 'current'),
          if (widget.secondaryKey != null)
            _seriesToggle('Previous', 'previous'),
        ]),
        const SizedBox(height: 16),
        if (widget.data.isEmpty)
          const SizedBox(
            height: 225,
            child: Center(child: Text('No chart data available',
                style: TextStyle(color: _muted))),
          )
        else
          SizedBox(
            height: 245,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineGraphPainter(
                points: widget.data,
                primaryKey: widget.primaryKey,
                secondaryKey: widget.secondaryKey,
                showPrimary: _selection == 'all' || _selection == 'current',
                showSecondary: widget.secondaryKey != null &&
                    (_selection == 'all' || _selection == 'previous'),
                currency: widget.currency,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, children: <Widget>[
          _legend(widget.primaryLabel, _blue),
          if (widget.secondaryKey != null)
            _legend(widget.secondaryLabel, const Color(0xFF94A3B8)),
        ]),
      ],
    ));
  }

  Widget _seriesToggle(String title, String value) {
    final active = _selection == value;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selection = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF1FF) : const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFFBCD0FF) : _border),
        ),
        child: Text(title, style: TextStyle(
          color: active ? _blue : _muted,
          fontSize: 11,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        )),
      ),
    );
  }

  Widget _legend(String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min, children: <Widget>[
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: _muted, fontSize: 11)),
    ]);
}

class _LineGraphPainter extends CustomPainter {
  const _LineGraphPainter({
    required this.points,
    required this.primaryKey,
    required this.secondaryKey,
    required this.showPrimary,
    required this.showSecondary,
    required this.currency,
  });

  final List<Map<String, dynamic>> points;
  final String primaryKey;
  final String? secondaryKey;
  final bool showPrimary;
  final bool showSecondary;
  final bool currency;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;

    final maxValue = math.max(1.0, points.fold<double>(0, (max, row) {
      final current = _toDouble(row[primaryKey]);
      final double previous = secondaryKey == null ? 0.0 : _toDouble(row[secondaryKey]);
      return math.max(max, math.max(current, previous));
    }));

    // Allow sufficient room for rupee-formatted Y-axis tick labels.
    final left = math.min(83.0, math.max(59.0, size.width * .25));
    const right = 10.0;
    const top = 12.0;
    const bottom = 34.0;
    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);

    double x(int index) => left + (points.length == 1
        ? chartWidth / 2 : (index / (points.length - 1)) * chartWidth);
    double y(double value) => top + chartHeight *
        (1 - (value / maxValue).clamp(0.0, 1.0).toDouble());

    final gridPaint = Paint()
      ..color = const Color(0xFFE9EEF5)
      ..strokeWidth = 1;

    for (final fraction in const <double>[0, .25, .5, .75, 1]) {
      final gridY = y(maxValue * fraction);
      canvas.drawLine(Offset(left, gridY),
          Offset(size.width - right, gridY), gridPaint);
      _paintText(canvas, _axis(maxValue * fraction),
          Offset(left - 9, gridY),
          align: TextAlign.right, anchorRight: true);
    }

    Path seriesPath(String key) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final px = x(i);
        final py = y(_toDouble(points[i][key]));
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      return path;
    }

    if (showSecondary && secondaryKey != null) {
      final paint = Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = seriesPath(secondaryKey!);
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = math.min(distance + 8.0, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), paint);
          distance += 15;
        }
      }
    }

    if (showPrimary) {
      canvas.drawPath(seriesPath(primaryKey), Paint()
        ..color = _blue
        ..strokeWidth = 3.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round);
    }

    final firstDate = _display(points.first['date']);
    final lastDate = _display(points.last['date']);
    _paintText(canvas, firstDate, Offset(left, size.height - 13));
    if (points.length > 1) {
      _paintText(canvas, lastDate,
          Offset(size.width - right, size.height - 13),
          align: TextAlign.right, anchorRight: true);
    }
  }

  String _axis(double value) {
    if (!currency) return _number(value.round());
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.round()}';
  }

  void _paintText(Canvas canvas, String value, Offset origin,
      {TextAlign align = TextAlign.left, bool anchorRight = false}) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: const TextStyle(
          color: Color(0xFF94A3B8), fontSize: 10.5)),
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 110);
    painter.paint(canvas, Offset(
      anchorRight ? origin.dx - painter.width : origin.dx,
      origin.dy - painter.height / 2,
    ));
  }

  @override
  bool shouldRepaint(covariant _LineGraphPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.primaryKey != primaryKey ||
      oldDelegate.secondaryKey != secondaryKey ||
      oldDelegate.showPrimary != showPrimary ||
      oldDelegate.showSecondary != showSecondary ||
      oldDelegate.currency != currency;
}

class _HorizontalBarChart extends StatelessWidget {
  const _HorizontalBarChart({
    required this.title,
    required this.data,
    required this.labelKey,
    required this.valueKey,
    this.currency = true,
  });

  final String title;
  final List<Map<String, dynamic>> data;
  final String labelKey;
  final String valueKey;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    final rows = data.take(8).toList(growable: false);
    final maxValue = math.max(1.0, rows.fold<double>(0,
        (maximum, row) => math.max(maximum, _toDouble(row[valueKey]))));

    return _Panel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelTitle(title: title, subtitle: 'Top performance breakdown'),
        const SizedBox(height: 20),
        if (rows.isEmpty)
          const SizedBox(height: 220,
              child: Center(child: Text('No data available',
                  style: TextStyle(color: _muted))))
        else
          ...rows.map((row) {
            final value = _toDouble(row[valueKey]);
            final percentage = (value / maxValue).clamp(0.0, 1.0).toDouble();
            final name = row[labelKey] == null ||
                    row[labelKey].toString().trim().isEmpty
                ? 'Unspecified' : row[labelKey].toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      Expanded(child: Text(name, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _navy,
                              fontSize: 12, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Text(currency ? _money(value) : _number(value),
                          style: const TextStyle(color: _navy, fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 9),
                    LayoutBuilder(builder: (context, constraints) =>
                      Stack(children: <Widget>[
                        Container(height: 10, width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF2FA),
                              borderRadius: BorderRadius.circular(10),
                            )),
                        Container(height: 10,
                            width: constraints.maxWidth * percentage,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: <Color>[
                                Color(0xFF4F7DFF), Color(0xFF2454D7),
                              ]),
                              borderRadius: BorderRadius.circular(10),
                            )),
                      ])),
                  ]),
            );
          }),
      ],
    ));
  }
}


class _ReportCustomerPicker extends StatefulWidget {
  const _ReportCustomerPicker({this.selectedId, required this.onSelected});
  final String? selectedId;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  State<_ReportCustomerPicker> createState() => _ReportCustomerPickerState();
}

class _ReportCustomerPickerState extends State<_ReportCustomerPicker> {
  final TextEditingController _search = TextEditingController();
  final List<Map<String, dynamic>> _customers = <Map<String, dynamic>>[];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  int _generation = 0;
  String _query = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    getcustomer();
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  // Same customer endpoint, token, search parameter and paginated results
  // used by the existing customer page.
  Future<void> getcustomer({int page = 1}) async {
    if (!mounted || (_loading && page != 1)) return;
    final generation = page == 1 ? ++_generation : _generation;
    if (page == 1) _query = _search.text.trim();
    setState(() {
      _loading = true;
      _error = '';
      if (page == 1) {
        _customers.clear();
        _page = 0;
        _hasMore = true;
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        throw const FormatException('Login token missing. Please log in again.');
      }
      final uri = Uri.parse('$api/api/customers/').replace(
        queryParameters: <String, String>{
          'page': page.toString(),
          if (_query.isNotEmpty) 'search': _query,
        },
      );
      final response = await http.get(uri, headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('Unable to load customers (${response.statusCode})');
      }
      final parsed = jsonDecode(response.body);
      if (parsed is! Map || parsed['results'] is! List) {
        throw const FormatException('Unexpected customer API response');
      }
      final data = _rows(parsed['results']);
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = _customers.map((row) => row['id'].toString()).toSet();
        for (final customer in data) {
          if (customer['id'] != null && seen.add(customer['id'].toString())) {
            _customers.add(customer);
          }
        }
        _page = page;
        final count = (parsed['count'] as num?)?.toInt();
        _hasMore = data.isNotEmpty && (count != null
            ? _customers.length < count : parsed['next'] != null);
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error is FormatException
          ? error.message : 'Unable to load customers. Please try again.');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 320,
        child: Column(children: <Widget>[
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => getcustomer(),
            decoration: InputDecoration(
              hintText: 'Search customer name or phone',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: () => getcustomer(),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(child: _loading && _customers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _customers.isEmpty
                  ? Center(child: Text(_error.isEmpty
                      ? 'No customers found.' : 'Search again or tap Retry.'))
                  : ListView.separated(
                      itemCount: _customers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = _customers[index];
                        final selected = customer['id'].toString() == widget.selectedId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_display(customer['name'])),
                          subtitle: Text(_display(customer['phone'])),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: _blue) : null,
                          onTap: () => widget.onSelected(customer),
                        );
                      },
                    )),
          if (_loading && _customers.isNotEmpty)
            const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_error.isNotEmpty)
            TextButton(onPressed: () => getcustomer(page: _page + 1),
                child: const Text('Retry'))
          else if (_hasMore && _customers.isNotEmpty)
            TextButton(onPressed: () => getcustomer(page: _page + 1),
                child: const Text('Load more customers')),
        ]),
    );
  }
}
