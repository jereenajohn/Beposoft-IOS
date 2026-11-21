import 'dart:async';
import 'dart:convert';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyGstReportPage extends StatefulWidget {
  final String companyId;
  final String companyName;
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const CompanyGstReportPage({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.initialStartDate,
    required this.initialEndDate,
  });

  @override
  State<CompanyGstReportPage> createState() => _CompanyGstReportPageState();
}

class _CompanyGstReportPageState extends State<CompanyGstReportPage> {
  static const _blue = Color(0xFF2563EB);
  static const _ink = Color(0xFF172554);
  final _client = http.Client();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _date = DateFormat('dd MMM yyyy');
  late DateTimeRange _range;
  late String _selectedCompanyId;
  late String _selectedCompanyName;
  List<Map<String, String>> _companies = [];
  bool _companiesLoading = true;
  String? _companiesError;
  bool _loading = true;
  String? _error;
  int _request = 0;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _range = DateTimeRange(start: widget.initialStartDate, end: widget.initialEndDate);
    _selectedCompanyId = widget.companyId;
    _selectedCompanyName = widget.companyName;
    _companies = [{'id': widget.companyId, 'name': widget.companyName}];
    getcompany();
    _fetch();
  }

  @override
  void dispose() {
    _request++;
    _client.close();
    super.dispose();
  }

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  String _text(dynamic value) => value == null || value.toString().trim().isEmpty
      ? '—' : value.toString();
  double _total(String key) => _rows.fold<double>(0, (sum, row) => sum + _number(row[key]));

  Future<void> getcompany() async {
    if (!mounted) return;
    setState(() { _companiesLoading = true; _companiesError = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.trim().isEmpty) {
        throw Exception('Please log in again to load companies.');
      }
      final response = await _client.get(
        Uri.parse('$api/api/company/data/'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Unable to load companies (${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException('Invalid company response.');
      }
      final byId = <String, Map<String, String>>{};
      for (final item in decoded['data'] as List) {
        if (item is! Map || item['id'] == null) continue;
        final id = item['id'].toString();
        final name = item['name']?.toString().trim() ?? '';
        byId[id] = {'id': id, 'name': name.isEmpty ? 'Unnamed company' : name};
      }
      if (!mounted) return;
      // Retain the currently selected company if omitted from the response.
      byId.putIfAbsent(_selectedCompanyId, () => {
        'id': _selectedCompanyId, 'name': _selectedCompanyName,
      });
      final companies = byId.values.toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));
      setState(() {
        _companies = companies;
        _selectedCompanyName = byId[_selectedCompanyId]!['name']!;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _companiesError = error is TimeoutException
            ? 'Loading companies timed out. Please retry.'
            : error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _companiesLoading = false);
    }
  }

  Widget _companyFilter() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
        // Recreate the field only when the selected company changes.
        key: ValueKey(_selectedCompanyId),
        value: _selectedCompanyId,
        isExpanded: true,
        menuMaxHeight: 360,
        decoration: InputDecoration(
          labelText: 'Company',
          prefixIcon: const Icon(Icons.business_rounded, color: _blue),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
        ),
        items: _companies.map((company) => DropdownMenuItem<String>(
          value: company['id'],
          child: Text(company['name']!, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
        )).toList(),
        onChanged: _companiesLoading ? null : (value) {
          if (value == null || value == _selectedCompanyId) return;
          final selected = _companies.firstWhere((company) => company['id'] == value);
          setState(() {
            _selectedCompanyId = value;
            _selectedCompanyName = selected['name']!;
          });
          _fetch();
        },
      ),
      if (_companiesLoading) const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      if (_companiesError != null) Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(_companiesError!,
            style: const TextStyle(color: Color(0xFFB45309), fontSize: 12))),
          TextButton(onPressed: getcompany, child: const Text('Retry')),
        ]),
      ),
    ]);
  }

  Future<void> _fetch() async {
    final version = ++_request;
    final range = _range;
    final companyId = _selectedCompanyId;
    setState(() { _loading = true; _error = null; _rows = []; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.trim().isEmpty) {
        throw Exception('Your session has expired. Please log in again.');
      }
      final uri = Uri.parse('$api/api/orders/tax/report/').replace(queryParameters: {
        'company': companyId,
        'start_date': DateFormat('yyyy-MM-dd').format(range.start),
        'end_date': DateFormat('yyyy-MM-dd').format(range.end),
      });
      final response = await _client.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 30));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Your session has expired or access is restricted.');
      }
      if (response.statusCode != 200) {
        throw Exception('Unable to load the report (${response.statusCode}). Please retry.');
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['status'] != 'success' || body['data'] is! List) {
        throw const FormatException('The server returned an invalid GST report.');
      }
      if (body['next'] != null && body['next'].toString().isNotEmpty) {
        throw const FormatException('The report is paginated. Complete totals require all pages.');
      }
      final rows = <Map<String, dynamic>>[];
      for (final item in body['data'] as List) {
        if (item is! Map) throw const FormatException('Invalid report row.');
        // Restrict results to the company captured for this request.
        if (item['company_id']?.toString() == companyId) {
          rows.add(Map<String, dynamic>.from(item));
        }
      }
      rows.sort((a, b) => _text(b['order_date']).compareTo(_text(a['order_date'])));
      if (!mounted || version != _request) return;
      setState(() { _rows = rows; _loading = false; });
    } on TimeoutException {
      _fail(version, 'The request timed out. Check your connection and retry.');
    } on FormatException catch (e) {
      _fail(version, e.message);
    } catch (e) {
      _fail(version, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _fail(int version, String message) {
    if (!mounted || version != _request) return;
    setState(() { _error = message; _loading = false; });
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _range,
      helpText: 'SELECT REPORT PERIOD',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: _blue),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    await _fetch();
  }

  void _quickPeriod(bool month) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    setState(() => _range = DateTimeRange(
      start: month ? DateTime(now.year, now.month, 1) : end, end: end,
    ));
    _fetch();
  }

  Widget _surface(Widget child, {Color color = Colors.white}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0))),
    child: child,
  );

  Widget _metric(String label, String value, IconData icon, {bool highlight = false}) {
    final foreground = highlight ? Colors.white : _ink;
    return _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: highlight ? Colors.white70 : _blue, size: 22),
      const SizedBox(height: 12),
      Text(label, style: TextStyle(color: highlight ? Colors.white70 : Colors.blueGrey, fontSize: 12)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: foreground, fontSize: 18, height: 1.25, fontWeight: FontWeight.w800)),
    ]), color: highlight ? _blue : Colors.white);
  }

  Widget _amount(String label, dynamic value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
      const SizedBox(height: 4),
      Text(_money.format(_number(value)), style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
    ],
  );

  String _getDisplayStatus(dynamic status) {
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
      case 'Return From Delivery':
        return 'Return From Delivery (RFD)';
      default:
        return _text(status);
    }
  }

  Color _statusColor(dynamic status) {
    switch (status) {
      case 'Invoice Created':
        return const Color(0xFFB45309);
      case 'To Print':
      case 'Packing under progress':
        return _blue;
      case 'Packed':
        return const Color(0xFF7C3AED);
      case 'Ready to ship':
        return const Color(0xFF047857);
      case 'Return From Delivery':
        return const Color(0xFFBE123C);
      default:
        return const Color(0xFF475569);
    }
  }

  Widget _order(Map<String, dynamic> row) {
    final parsed = DateTime.tryParse(row['order_date']?.toString() ?? '');
    return _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.receipt_long_rounded, color: _blue)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_text(row['invoice']), style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(_text(row['customer_name']), style: const TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 4),
          Text('Order #${_text(row['order_id'])} • ${parsed == null ? _text(row['order_date']) : _date.format(parsed)}',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
        ])),
      ]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor(row['status']).withOpacity(.08),
          border: Border.all(color: _statusColor(row['status']).withOpacity(.18)),
          borderRadius: BorderRadius.circular(8)),
        child: Text(_getDisplayStatus(row['status']), style: TextStyle(
          color: _statusColor(row['status']), fontSize: 11, fontWeight: FontWeight.w700))),
      const Divider(height: 28),
      Wrap(spacing: 24, runSpacing: 14, children: [
        _amount('Order amount', row['net_amount']),
        _amount('Without tax', row['amount_before_tax']),
        _amount('GST amount', row['tax_amount']),
        _amount('Discount', row['total_discount']),
        _amount('Gross amount', row['total_amount']),
      ]),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        title: const Text('Company GST Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white, foregroundColor: _ink, elevation: 0,
        actions: [IconButton(tooltip: 'Refresh report', onPressed: _loading ? null : _fetch,
          icon: const Icon(Icons.refresh_rounded))],
      ),
      body: SafeArea(child: RefreshIndicator(onRefresh: _fetch,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('GST OVERVIEW', style: TextStyle(color: _blue, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(_selectedCompanyName, style: const TextStyle(color: _ink, fontSize: 18, height: 1.35, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  _companyFilter(),
                  const SizedBox(height: 14),
                  const Text('REPORT PERIOD', style: TextStyle(
                    color: Colors.blueGrey, fontSize: 10, letterSpacing: 1.2,
                    fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      backgroundColor: const Color(0xFFEFF6FF),
                      side: const BorderSide(color: Color(0xFFDBEAFE)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _pickDates,
                    icon: const Icon(Icons.date_range_rounded, size: 19),
                    label: Text('${_date.format(_range.start)} — ${_date.format(_range.end)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  )),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    ActionChip(backgroundColor: const Color(0xFFEFF6FF), labelStyle: const TextStyle(color: _blue, fontWeight: FontWeight.w600), side: const BorderSide(color: Color(0xFFDBEAFE)), label: const Text('Today'), onPressed: () => _quickPeriod(false)),
                    ActionChip(backgroundColor: const Color(0xFFEFF6FF), labelStyle: const TextStyle(color: _blue, fontWeight: FontWeight.w600), side: const BorderSide(color: Color(0xFFDBEAFE)), label: const Text('This month'), onPressed: () => _quickPeriod(true)),
                  ]),
                ])),
                const SizedBox(height: 18),
                if (_loading) const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
                else if (_error != null) _surface(Column(children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.blueGrey, size: 36),
                  const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12), FilledButton.icon(onPressed: _fetch,
                    icon: const Icon(Icons.refresh), label: const Text('Try again')),
                ]))
                else ...[
                  LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 800 ? 4 : constraints.maxWidth >= 340 ? 2 : 1;
                    final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      SizedBox(width: width, child: _metric('Total GST', _money.format(_total('tax_amount')), Icons.account_balance_rounded, highlight: true)),
                      SizedBox(width: width, child: _metric('Order amount', _money.format(_total('net_amount')), Icons.payments_outlined)),
                      SizedBox(width: width, child: _metric('Without tax', _money.format(_total('amount_before_tax')), Icons.receipt_outlined)),
                      SizedBox(width: width, child: _metric('Total orders', '${_rows.length}', Icons.shopping_bag_outlined)),
                    ]);
                  }),
                  const SizedBox(height: 22),
                  Row(children: [const Expanded(child: Text('Invoice breakdown', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800))),
                    Text('${_rows.length} records', style: const TextStyle(color: Colors.blueGrey, fontSize: 12))]),
                  const SizedBox(height: 6),
                  const Text('Sales GST from the order tax report.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                  const SizedBox(height: 14),
                  if (_rows.isEmpty) _surface(const Center(child: Padding(
                    padding: EdgeInsets.all(24), child: Text('No orders for this company in the selected period.')))),
                ],
              ],
            )),
          ))),
          if (!_loading && _error == null) SliverList(delegate: SliverChildBuilderDelegate(
            (context, index) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _order(_rows[index])))),
            childCount: _rows.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      )),
    );
  }
}
