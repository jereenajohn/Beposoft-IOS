import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

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
import 'package:dio/dio.dart';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

// apiBaseUrl must include your API prefix, for example https://host/api.
// tokenProvider can reuse your application's existing authentication service.
class StaffCompleteReportPage extends StatefulWidget {
  const StaffCompleteReportPage({
    super.key,
    this.staffId,
    this.apiBaseUrl,
    this.tokenProvider,
  });

  final String? staffId;
  final String? apiBaseUrl;
  final Future<String?> Function()? tokenProvider;

  @override
  State<StaffCompleteReportPage> createState() => _StaffCompleteReportPageState();
}

typedef Json = Map<String, dynamic>;

const _blue = Color(0xFF2858DF);
const _ink = Color(0xFF17233B);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE5EAF3);
const _tabs = ['Overview', 'Orders', 'Order Items', 'GRV / Returns', 'States', 'Customers', 'Products', 'Staff Details'];
const _ordersColumns = ['invoice', 'order_date', 'status', 'payment_status', 'payment_method', 'total_amount', 'customer_name', 'state_name', 'managed_by_name'];
const _itemsColumns = ['invoice', 'product_name', 'quantity', 'rate', 'discount', 'tax_percent', 'estimated_line_total', 'description', 'size_id', 'variant_id'];
const _grvColumns = ['invoice', 'product', 'quantity', 'price', 'gross_grv_value', 'status', 'return_reason', 'remark', 'date', 'note'];
const _stateColumns = ['state_name', 'total_bills', 'gross_order_amount', 'sales_order_amount', 'excluded_status_amount', 'unique_customers', 'average_bill_amount', 'previous_sales_amount', 'sales_difference', 'sales_change_percent'];
const _customerColumns = ['name', 'bills', 'amount'];
const _productColumns = ['product_name', 'quantity', 'bill_count', 'estimated_line_total'];
const _moneyColumns = {'total_amount', 'amount', 'rate', 'discount', 'estimated_line_total', 'gross_grv_value', 'gross_order_amount', 'sales_order_amount', 'excluded_status_amount', 'average_bill_amount', 'previous_sales_amount', 'sales_difference', 'price'};

Json _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Json> _rows(dynamic value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Json>[];
double _num(dynamic value) {
  final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return n.isFinite ? n : 0;
}
String _money(dynamic value) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(_num(value));
String _number(dynamic value) => NumberFormat.decimalPattern('en_IN').format(_num(value));
String _show(dynamic value) => value == null || value == '' ? '—' : value is Map || value is List ? jsonEncode(value) : '$value';
String _label(String value) => value.replaceAll('_', ' ').replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());
String _percent(dynamic value) => value == null ? 'N/A' : '${_num(value).toStringAsFixed(2)}%';
String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String _cell(String key, dynamic value) => _moneyColumns.contains(key) ? _money(value) : key.endsWith('_percent') ? _percent(value) : _show(value);

class _StaffCompleteReportPageState extends State<StaffCompleteReportPage> {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 60)));
  CancelToken? _cancel;
  DateTime? _draftStart;
  DateTime? _draftEnd;
  DateTime? _start;
  DateTime? _end;
  Json? _report;
  bool _loading = false;
  String? _selectedStaffId;
  String? _appliedStaffId;
  String? _selectedStaffName;
  bool _staffDropdownOpen = false;

  String get _base => (widget.apiBaseUrl ?? '$api/api').trim().replaceFirst(RegExp(r'/+$'), '');
  Future<String?> _getToken() async => widget.tokenProvider != null ? await widget.tokenProvider!() : (await SharedPreferences.getInstance()).getString('token');
  bool _exporting = false;
  String? _error;
  String _tab = 'Overview';
  int _request = 0;
  List<Json> _orders = [];
  List<Json> _items = [];
  List<Json> _grvs = [];
  List<Json> _states = [];

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.staffId;
    _appliedStaffId = widget.staffId;
    if (widget.staffId?.trim().isNotEmpty == true) _fetch();
  }

  @override
  void didUpdateWidget(covariant StaffCompleteReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.staffId != widget.staffId || oldWidget.apiBaseUrl != widget.apiBaseUrl) {
      _selectedStaffId = widget.staffId;
      _appliedStaffId = widget.staffId;
      _selectedStaffName = null;
      _report = null;
      _fetch();
    }
  }

  void _resetDates() {
    _start = _draftStart = null;
    _end = _draftEnd = null;
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _fetch() async {
    final request = ++_request;
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final staffId = _appliedStaffId;
    final startDate = _start;
    final endDate = _end;
    if (staffId == null || staffId.trim().isEmpty) {
      setState(() { _loading = false; _report = null; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final base = _base;
      final uri = Uri.tryParse(base);
      if (uri == null || !uri.hasAuthority || !['https', 'http'].contains(uri.scheme)) throw Exception('Provide a valid API base URL');
      final token = await _getToken();
      if (!mounted || request != _request) return;
      if (token == null || token.trim().isEmpty) throw Exception('Your session has expired. Please sign in again.');
      final response = await _dio.get<dynamic>(
        '$base/staff/complete/report/',
        queryParameters: {'user_id': staffId, if (startDate != null) 'start_date': _date(startDate), if (endDate != null) 'end_date': _date(endDate)},
        options: Options(headers: {'Authorization': 'Bearer ${token.trim()}', 'Accept': 'application/json'}),
        cancelToken: cancel,
      );
      if (!mounted || request != _request) return;
      final dynamic payload = response.data is String ? jsonDecode(response.data as String) : response.data;
      if (payload is! Map) throw Exception('The server returned an invalid report');
      final report = _map(payload);
      if (report['status'] == 'error' || report['success'] == false) throw Exception(_show(report['message']));
      final source = _rows(report['orders']);
      setState(() {
        _report = report;
        _orders = source.map((o) => <String, dynamic>{...o, 'customer_name': _map(o['customer'])['name'], 'state_name': _map(o['state'])['name'], 'managed_by_name': _map(o['managed_by'])['name']}).toList();
        _items = source.expand((o) => _rows(o['order_items']).map((i) => <String, dynamic>{...i, 'invoice': o['invoice'], 'order_id': o['id']})).toList();
        _grvs = source.expand((o) => _rows(o['grv_details']).map((g) => <String, dynamic>{...g, 'invoice': o['invoice']})).toList();
        _states = _rows(report['state_wise_report']).map((s) => <String, dynamic>{...s, ..._map(s['comparison'])}).toList();
      });
    } catch (e) {
      if (!mounted || request != _request || (e is DioException && CancelToken.isCancel(e))) return;
      String message;
      if (e is DioException) {
        final body = _map(e.response?.data);
        message = e.response?.statusCode == 401 ? 'Your session has expired. Please sign in again.' : (body['message'] ?? body['detail'] ?? 'Unable to load staff report. Check your connection and retry.').toString();
      } else {
        message = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() { _error = message; _report = null; });
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
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

  void _chooseStaff() {
    setState(() => _staffDropdownOpen = !_staffDropdownOpen);
  }

  void _selectStaff(Json staff) {
    setState(() {
      _selectedStaffId = staff['id'].toString();
      _selectedStaffName = _show(staff['name']);
      _staffDropdownOpen = false;
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _staffFilterField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Staff', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      InkWell(
        onTap: _chooseStaff,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F2)),
          ),
          child: Row(children: [
            const Icon(Icons.person_outline_rounded, color: _muted, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _selectedStaffName ?? (_selectedStaffId != null ? 'Staff ID: $_selectedStaffId' : 'Select staff'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: _selectedStaffId == null ? _muted : _ink),
            )),
            Icon(_staffDropdownOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: _muted, size: 19),
          ]),
        ),
      ),
      if (_staffDropdownOpen) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
          child: _StaffPicker(
            key: ValueKey(_base),
            baseUrl: _base,
            getToken: _getToken,
            selectedId: _selectedStaffId,
            onSelected: _selectStaff,
          ),
        ),
      ],
    ]);
  }

  DateTime? _parseReportDate(dynamic value) {
    if (value == null) return null;
    // Keep the API's calendar date; do not shift it across time zones.
    final text = value.toString().trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|[T ])').firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day ? date : null;
  }

  _ReportPeriod _resolveReportPeriod() {
    if (_report == null || _loading) return const _ReportPeriod();
    final report = _report!;
    final candidates = <Json>[
      _map(report['filters']),
      _map(report['applied_filters']),
      _map(report['date_range']),
      _map(report['report_period']),
      _map(report['period']),
      _map(_map(report['comparison'])['current_period']),
      report,
    ];
    for (final candidate in candidates) {
      final start = _parseReportDate(candidate['start_date']);
      final end = _parseReportDate(candidate['end_date']);
      if (start != null && end != null && !start.isAfter(end)) {
        return _ReportPeriod(start: start, end: end, source: 'api');
      }
    }
    // Explicit request dates are authoritative even when the response omits them.
    if (_start != null && _end != null) {
      return _ReportPeriod(start: _start, end: _end, source: 'filter');
    }
    DateTime? first;
    DateTime? last;
    for (final order in _orders) {
      final date = _parseReportDate(order['order_date']);
      if (date == null) continue;
      if (first == null || date.isBefore(first)) first = date;
      if (last == null || date.isAfter(last)) last = date;
    }
    if (first != null && last != null) {
      return _ReportPeriod(start: first, end: last, source: 'orders');
    }
    return const _ReportPeriod();
  }

  Widget _reportDateField(bool start, _ReportPeriod period) {
    final draft = start ? _draftStart : _draftEnd;
    final sameStaff = _selectedStaffId == _appliedStaffId;
    final displayed = draft ?? (sameStaff ? (start ? period.start : period.end) : null);
    final automatic = draft == null && displayed != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(start ? 'Start Date (Optional)' : 'End Date (Optional)',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pickDate(start),
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            suffixIcon: draft == null
              ? const Icon(Icons.calendar_today_outlined, size: 17)
              : IconButton(tooltip: 'Clear date', icon: const Icon(Icons.close, size: 17),
                  onPressed: () => setState(() {
                    if (start) { _draftStart = null; } else { _draftEnd = null; }
                  })),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border)),
          ),
          child: Text(displayed == null ? 'Select date' : _date(displayed),
            style: const TextStyle(fontSize: 13)),
        ),
      ),
      if (automatic) ...[
        const SizedBox(height: 5),
        Text(period.source == 'orders'
          ? (start ? 'First returned order' : 'Last returned order')
          : 'Loaded report range',
          style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    ]);
  }

  Widget _reportPeriodNotice(_ReportPeriod period) {
    final hasRange = period.start != null && period.end != null;
    final title = period.source == 'orders' ? 'Available order dates' : 'Showing report period';
    final range = hasRange
      ? '${DateFormat('dd MMM yyyy').format(period.start!)} – ${DateFormat('dd MMM yyyy').format(period.end!)}'
      : 'The API did not return a date range.';
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD5E2FC))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.date_range_rounded, color: _blue, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hasRange ? title : 'Report period unavailable',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(range, style: const TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w600)),
          if (period.source == 'orders') ...[
            const SizedBox(height: 5),
            const Text('Dates of the returned orders. The API did not specify the full reporting period.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
          ],
          if (!hasRange && (_start != null || _end != null)) ...[
            const SizedBox(height: 5),
            Text('Applied filter: ${_start == null ? 'No start limit' : _date(_start!)} – ${_end == null ? 'No end limit' : _date(_end!)}',
              style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ])),
      ]),
    );
  }

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(context: context, initialDate: (start ? _draftStart : _draftEnd) ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2200));
    if (selected == null || !mounted) return;
    setState(() { if (start) { _draftStart = selected; } else { _draftEnd = selected; } });
  }

  void _apply() {
    if (_selectedStaffId == null || _selectedStaffId!.trim().isEmpty) {
      setState(() => _error = 'Please select a staff');
      return;
    }
    if (_draftStart != null && _draftEnd != null && _draftStart!.isAfter(_draftEnd!)) {
      setState(() => _error = 'Start date cannot be after end date');
      return;
    }
    _staffDropdownOpen = false;
    _appliedStaffId = _selectedStaffId;
    _start = _draftStart;
    _end = _draftEnd;
    _fetch();
  }

  Future<void> _export(List<_ExportSheet> sheets, String filename, Rect origin) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    xls.Workbook? workbook;
    try {
      workbook = xls.Workbook(sheets.length);
      for (var index = 0; index < sheets.length; index++) {
        final data = sheets[index];
        final sheet = workbook.worksheets[index];
        final name = data.name.replaceAll(RegExp(r'[\\/?*\[\]:]'), '');
        sheet.name = name.substring(0, math.min(31, name.length));
        final columns = data.columns ?? data.rows.expand((r) => r.keys).toSet().toList();
        if (columns.isEmpty) continue;
        for (var c = 0; c < columns.length; c++) {
          sheet.getRangeByIndex(1, c + 1).setText(_label(columns[c]));
          sheet.getRangeByIndex(1, c + 1).columnWidth = math.min(42, math.max(17, columns[c].length + 8)).toDouble();
        }
        final header = sheet.getRangeByIndex(1, 1, 1, columns.length);
        header.cellStyle.backColor = '#2858DF';
        header.cellStyle.fontColor = '#FFFFFF';
        header.cellStyle.bold = true;
        header.cellStyle.wrapText = true;
        header.rowHeight = 30;
        for (var r = 0; r < data.rows.length; r++) {
          for (var c = 0; c < columns.length; c++) {
            final value = data.rows[r][columns[c]];
            final cell = sheet.getRangeByIndex(r + 2, c + 1);
            if (value is num && value.isFinite) {
              cell.setNumber(value.toDouble());
            } else {
              var text = value == null ? '' : value is Map || value is List ? jsonEncode(value) : '$value';
              if (RegExp(r'^[=+\-@\t\r]').hasMatch(text)) text = "'$text";
              cell.setText(text);
            }
          }
        }
        sheet.autoFilters.filterRange = sheet.getRangeByIndex(1, 1, math.max(1, data.rows.length + 1), columns.length);
        sheet.getRangeByIndex(2, 1).freezePanes();
      }
      final bytes = Uint8List.fromList(workbook.saveAsStream());
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: filename)],
        fileNameOverrides: [filename],
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to export Excel. Please try again.')));
    } finally {
      workbook?.dispose();
      if (mounted) setState(() => _exporting = false);
    }
  }

  Json get _staff => _map(_report?['staff']);
  Json get _summary => _map(_report?['summary']);
  Json get _graphs => _map(_report?['graphs']);
  List<Json> get _customers => _rows(_report?['customers']);
  List<Json> get _products => _rows(_map(_report?['order_items_summary'])['products']);

  void _exportAll(Rect origin) {
    _export([
      _ExportSheet('Staff Details', _staff.entries.map((e) => <String, dynamic>{'field': e.key, 'value': _show(e.value)}).toList(), ['field', 'value']),
      _ExportSheet('Summary', _summary.entries.map((e) => <String, dynamic>{'metric': e.key, 'value': _show(e.value)}).toList(), ['metric', 'value']),
      _ExportSheet('Comparison', _map(_report?['comparison']).entries.map((e) => <String, dynamic>{'metric': e.key, ..._map(e.value)}).toList()),
      _ExportSheet('Orders', _orders, _ordersColumns),
      _ExportSheet('Order Items', _items, _itemsColumns),
      _ExportSheet('GRV', _grvs, _grvColumns),
      _ExportSheet('States', _states, _stateColumns),
      _ExportSheet('Customers', _customers, _customerColumns),
      _ExportSheet('Products', _products, _productColumns),
    ], 'Staff_Complete_Report_${(_appliedStaffId ?? 'staff').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.xlsx', origin);
  }

  Widget _button(String title, VoidCallback? onPressed, {IconData? icon, bool primary = false}) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
    final child = Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 8)], Text(title)]);
    return primary ? FilledButton(onPressed: onPressed, style: style.copyWith(backgroundColor: const WidgetStatePropertyAll(_blue)), child: child) : OutlinedButton(onPressed: onPressed, style: style.copyWith(foregroundColor: const WidgetStatePropertyAll(_ink), backgroundColor: const WidgetStatePropertyAll(Colors.white), side: const WidgetStatePropertyAll(BorderSide(color: _border))), child: child);
  }

  Widget _exportButton({required bool enabled, required void Function(Rect) action, bool primary = false}) => Builder(builder: (buttonContext) => _button(
    _exporting ? 'Exporting...' : 'Export Excel',
    enabled && !_exporting ? () {
      final box = buttonContext.findRenderObject() as RenderBox;
      action(box.localToGlobal(Offset.zero) & box.size);
    } : null,
    icon: Icons.file_download_outlined, primary: primary,
  ));

  Widget _reportHeader() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08152747),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_blue, Color(0xFF7EABFF)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final scaledText = MediaQuery.textScalerOf(context).scale(14);
              final stacked = compact || scaledText > 18;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STAFF ANALYTICS',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Staff Complete Report',
                    style: TextStyle(
                      color: _ink,
                      fontSize: compact ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Staff sales, orders, returns, state-wise performance and comparisons',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ],
              );
              final badge = Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.insert_chart_outlined_rounded,
                  color: _blue,
                  size: 24,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stacked) ...[
                    badge,
                    const SizedBox(height: 15),
                    heading,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        badge,
                        const SizedBox(width: 16),
                        Expanded(child: heading),
                      ],
                    ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _button('Refresh', _loading ? null : _fetch,
                        icon: Icons.refresh_rounded),
                      _headerExportButton(),
                    ],
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _headerExportButton() {
    return Builder(builder: (buttonContext) {
      final enabled = _report != null && !_loading && !_exporting;
      return FilledButton.icon(
        onPressed: enabled ? () {
          final box = buttonContext.findRenderObject() as RenderBox;
          _exportAll(box.localToGlobal(Offset.zero) & box.size);
        } : null,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFEAF0FC),
          disabledForegroundColor: const Color(0xFF8192B5),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        icon: _exporting
          ? const SizedBox(width: 17, height: 17,
              child: CircularProgressIndicator(strokeWidth: 2,
                color: Color(0xFF8192B5)))
          : const Icon(Icons.file_download_outlined, size: 17),
        label: Text(_exporting ? 'Exporting...' : 'Export Excel'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final period = _resolveReportPeriod();
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _blue), textTheme: Theme.of(context).textTheme.apply(bodyColor: _ink, displayColor: _ink)),
      child: WillPopScope(
        onWillPop: () async {
          await _navigateBack();
          return false;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7FC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            foregroundColor: const Color(0xFF14213D),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: _navigateBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Staff Complete Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            actions: [
              IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _fetch,
                icon: const Icon(Icons.refresh_rounded)),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final mobile = constraints.maxWidth <= 600;
        return SingleChildScrollView(padding: EdgeInsets.all(mobile ? 12 : 24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1600), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _reportHeader(),
          const SizedBox(height: 18),
          _Panel(child: LayoutBuilder(builder: (context, bounds) => Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(width: mobile ? bounds.maxWidth : 280, child: _staffFilterField()),
            for (final start in [true, false])
              SizedBox(width: mobile ? bounds.maxWidth : 190,
                child: _reportDateField(start, period)),
            _button('Apply Filters', _apply, primary: true), _button('Clear Filters', () { _resetDates(); _staffDropdownOpen = false; _selectedStaffId = null; _selectedStaffName = null; _appliedStaffId = null; _tab = 'Overview'; _fetch(); }),
          ]))),
          if (_report != null && !_loading) _reportPeriodNotice(period),
          if (_error != null) Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFF0F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFD4DB))), child: Text(_error!, style: const TextStyle(color: Color(0xFFAA2743)))),
          if (_loading) const _Panel(child: Padding(padding: EdgeInsets.all(40), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading staff complete report...', style: TextStyle(color: _muted))]))))
          else if (_report != null) ..._reportContent(constraints.maxWidth)
          else if (_error == null) const _Panel(child: Padding(padding: EdgeInsets.all(32), child: Text('Select a staff and apply filters to view the complete report. Dates are optional.', textAlign: TextAlign.center, style: TextStyle(color: _muted)))),
        ]))));
      })))),
    );
  }

  List<Widget> _reportContent(double width) {
    final summary = _summary;
    final staff = _staff;
    final grv = _map(_report?['grv_summary']);
    final itemSummary = _map(_report?['order_items_summary']);
    return [
      _Panel(child: Row(children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFEAF1FF), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.person_outline, color: _blue, size: 28)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [TextSpan(text: '${staff['name'] ?? 'Staff'} ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), TextSpan(text: '(${_show(staff['department'])})', style: const TextStyle(fontSize: 13, color: _blue))])),
        const SizedBox(height: 5), Text('${_show(staff['designation'])} · Staff ID: ${_show(staff['staff_id'] ?? staff['id'])} · ${staff['email'] ?? 'No email'}', style: const TextStyle(color: _muted, fontSize: 13)),
      ]))])),
      _metricGrid([
        _Metric('Total Sales', _money(summary['sales_order_amount']), Icons.trending_up, _blue),
        _Metric('Total Bills', _number(summary['total_bills']), Icons.shopping_cart_outlined, const Color(0xFF8B5CF6)),
        _Metric('Gross Order Amount', _money(summary['gross_order_amount']), Icons.bar_chart, const Color(0xFF10A977)),
        _Metric('Average Bill Amount', _money(summary['average_bill_amount']), null, const Color(0xFFF3A03C)),
        _Metric('Unique Customers', _number(summary['unique_customers']), Icons.person_outline, _blue),
        _Metric('Product Quantity', _number(itemSummary['total_quantity']), Icons.inventory_2_outlined, const Color(0xFF8B5CF6)),
        _Metric('GRV Value', _money(grv['gross_grv_value']), Icons.restart_alt, const Color(0xFFED6179)),
        _Metric('States Served', _number(_states.isNotEmpty ? _states.length : _rows(_report?['states']).length), Icons.location_on_outlined, const Color(0xFF10A977)),
      ], width),
      Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final tab in _tabs) Padding(padding: const EdgeInsets.only(right: 5), child: _button(tab, () => setState(() => _tab = tab), primary: _tab == tab))]))),
      ..._tabContent(width),
      const Padding(padding: EdgeInsets.only(bottom: 25), child: Text("Sales amounts exclude the API's excluded order statuses. GRV amounts are reported separately, not deducted from sales. Product line totals are estimates according to the backend calculation.", style: TextStyle(fontSize: 12, color: _muted))),
    ];
  }

  Widget _metricGrid(List<_Metric> values, double width) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = width <= 600 ? 1 : width <= 1100 ? 2 : 4;
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * 15) / columns;

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              for (final metric in values)
                SizedBox(
                  width: cardWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 23, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      metric.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: _muted,
                                      ),
                                    ),
                                  ),
                                  if (metric.icon != null)
                                    Icon(metric.icon, size: 19, color: _muted),
                                ],
                              ),
                              const SizedBox(height: 13),
                              Text(
                                metric.value,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Paint the accent separately from the uniform border.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 4,
                          child: ColoredBox(color: metric.color),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      });

  Widget _details(String title, Json data, double width, {bool counts = false}) => _Panel(title: title, child: LayoutBuilder(builder: (context, c) {
    final columns = width <= 600 ? 1 : width <= 1100 ? 2 : 3;
    return Wrap(spacing: 13, runSpacing: 13, children: [for (final e in data.entries) SizedBox(width: (c.maxWidth - (columns - 1) * 13) / columns, child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEDF0F5)), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(counts ? e.key : _label(e.key), style: const TextStyle(fontSize: 12, color: _muted)), const SizedBox(height: 8), SelectableText(counts ? '${_number(e.value)} bills' : _show(e.value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))])))]);
  }));

  Widget _table(String title, List<Json> rows, List<String> columns, String suffix) => _ReportTable(
    key: ValueKey('$title-$_appliedStaffId'), title: title, rows: rows, columns: columns, exporting: _exporting,
    onExport: (filtered, origin) => _export([_ExportSheet(title, filtered, columns)], 'staff_${(_appliedStaffId ?? 'staff').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}_$suffix.xlsx', origin),
  );

  List<Widget> _tabContent(double width) {
    final graphs = _graphs;
    final fallbackStates = _rows(_report?['states']);
    switch (_tab) {
      case 'Overview':
        final charts = <Widget>[
          _Trend(title: 'Daily Sales Trend', rows: _rows(graphs['daily_orders'])),
          _Trend(title: 'Monthly Sales Trend', rows: _rows(graphs['monthly_orders']).map((r) => <String, dynamic>{...r, 'sales_amount': r['amount']}).toList()),
          _Bars(title: 'Sales by State', rows: graphs['state_wise_sales'] != null ? _rows(graphs['state_wise_sales']) : fallbackStates, nameKey: graphs['state_wise_sales'] != null ? 'state_name' : 'name', valueKey: graphs['state_wise_sales'] != null ? 'sales_amount' : 'amount', currency: true),
          _Bars(title: 'Top Selling Products', rows: _rows(graphs['top_products']), nameKey: 'product_name', valueKey: 'quantity'),
          _Bars(title: 'Order Status Distribution', rows: _rows(graphs['order_status']), nameKey: 'status', valueKey: 'count'),
          _Bars(title: 'Payment Status Distribution', rows: _rows(graphs['payment_status']), nameKey: 'status', valueKey: 'count'),
          _Bars(title: 'GRV Status', rows: _rows(graphs['grv_status']), nameKey: 'status', valueKey: 'count'),
        ];
        return [
          _Panel(title: 'Previous Period Comparison', child: _SimpleTable(columns: const ['Metric', 'Current', 'Previous', 'Difference', 'Change'], rows: _map(_report?['comparison']).entries.map((e) {
            final v = _map(e.value);
            final format = e.key == 'bills' ? _number : _money;
            return [_label(e.key), format(v['current']), format(v['previous']), format(v['difference']), _percent(v['change_percent'])];
          }).toList())),
          LayoutBuilder(builder: (context, c) {
            final columns = width <= 1100 ? 1 : 2;
            return Wrap(spacing: 18, children: [for (final chart in charts) SizedBox(width: (c.maxWidth - (columns - 1) * 18) / columns, child: chart)]);
          }),
        ];
      case 'Orders': return [_details('Order Status Summary', _map(_summary['order_status_counts']), width, counts: true), _table('Orders', _orders, _ordersColumns, 'orders')];
      case 'Order Items': return [_table('Order Items', _items, _itemsColumns, 'items')];
      case 'GRV / Returns':
        final grv = _map(_report?['grv_summary']);
        return [_metricGrid([_Metric('GRV Records', _number(grv['total_grv_records']), null, const Color(0xFFED6179)), _Metric('Gross GRV Value', _money(grv['gross_grv_value']), null, const Color(0xFFED6179))], width), const SizedBox(height: 18), _table('GRV / Returns', _grvs, _grvColumns, 'grv')];
      case 'States':
        final rows = _states.isNotEmpty ? _states : fallbackStates;
        return [_Bars(title: 'State-wise Sales', rows: rows, nameKey: _states.isNotEmpty ? 'state_name' : 'name', valueKey: _states.isNotEmpty ? 'sales_order_amount' : 'amount', currency: true), _table('State-wise Report', rows, _states.isNotEmpty ? _stateColumns : _customerColumns, 'states')];
      case 'Customers': return [_table('Customer-wise Sales', _customers, _customerColumns, 'customers')];
      case 'Products': return [_table('Product Performance', _products, _productColumns, 'products')];
      case 'Staff Details': return [_details('Staff Personal Details', _staff, width)];
      default: return [];
    }
  }
}

class _Metric {
  const _Metric(this.title, this.value, this.icon, this.color);
  final String title, value;
  final IconData? icon;
  final Color color;
}
class _ExportSheet {
  const _ExportSheet(this.name, this.rows, [this.columns]);
  final String name;
  final List<Json> rows;
  final List<String>? columns;
}
class _Panel extends StatelessWidget {
  const _Panel({this.title, required this.child});
  final String? title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 18), padding: const EdgeInsets.all(21), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x08152747), blurRadius: 12, offset: Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (title != null) ...[Text(title!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 18)], child]));
}
class _SimpleTable extends StatelessWidget {
  const _SimpleTable({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: BoxConstraints(minWidth: bounds.maxWidth), child: DataTable(
    headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F4FB)), headingRowHeight: 44,
    dataRowMinHeight: 44, dataRowMaxHeight: 60, horizontalMargin: 13, columnSpacing: 26, dividerThickness: 1,
    headingTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF42526B), fontWeight: FontWeight.w600), dataTextStyle: const TextStyle(fontSize: 13, color: _ink),
    columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
    rows: rows.map((r) => DataRow(cells: r.map((v) => DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Tooltip(message: v, child: Text(v, maxLines: 2, overflow: TextOverflow.ellipsis))))).toList())).toList(),
  ))));
}

class _ReportTable extends StatefulWidget {
  const _ReportTable({super.key, required this.title, required this.rows, required this.columns, required this.exporting, required this.onExport});
  final String title;
  final List<Json> rows;
  final List<String> columns;
  final bool exporting;
  final void Function(List<Json>, Rect) onExport;
  @override
  State<_ReportTable> createState() => _ReportTableState();
}
class _ReportTableState extends State<_ReportTable> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 1;
  int _limit = 10;
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final filtered = widget.rows.where((r) => widget.columns.any((c) => _show(r[c]).toLowerCase().contains(_query))).toList();
    final pages = math.max(1, (filtered.length / _limit).ceil());
    final page = math.min(_page, pages);
    final offset = (page - 1) * _limit;
    final visible = filtered.skip(offset).take(_limit).toList();
    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text('${_number(widget.rows.length)} records', style: const TextStyle(color: _muted, fontSize: 13))]),
        Builder(builder: (buttonContext) => OutlinedButton.icon(onPressed: filtered.isEmpty || widget.exporting ? null : () {
          final box = buttonContext.findRenderObject() as RenderBox;
          widget.onExport(filtered, box.localToGlobal(Offset.zero) & box.size);
        }, icon: const Icon(Icons.file_download_outlined, size: 17), label: Text(widget.exporting ? 'Exporting...' : 'Export Excel'))),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, bounds) => Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        SizedBox(width: math.min(340.0, bounds.maxWidth), child: TextField(controller: _search, onChanged: (value) => setState(() { _query = value.toLowerCase(); _page = 1; }), decoration: InputDecoration(hintText: 'Search ${widget.title.toLowerCase()}...', hintStyle: const TextStyle(fontSize: 13), prefixIcon: const Icon(Icons.search, size: 19), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _border))))),
        DropdownButton<int>(value: _limit, items: [10, 25, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n rows', style: const TextStyle(fontSize: 13)))).toList(), onChanged: (n) { if (n != null) setState(() { _limit = n; _page = 1; }); }),
      ])),
      const SizedBox(height: 15),
      _SimpleTable(columns: ['#', ...widget.columns.map(_label)], rows: [for (var i = 0; i < visible.length; i++) ['${offset + i + 1}', ...widget.columns.map((c) => _cell(c, visible[i][c]))]]),
      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Text('No matching records found', textAlign: TextAlign.center, style: TextStyle(color: _muted))),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        Text('Showing ${filtered.isEmpty ? 0 : offset + 1}–${math.min(page * _limit, filtered.length)} of ${filtered.length}', style: const TextStyle(fontSize: 13, color: _muted)),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [OutlinedButton(onPressed: page == 1 ? null : () => setState(() => _page = page - 1), child: const Text('Previous')), Text('Page $page of $pages', style: const TextStyle(fontSize: 13, color: _muted)), OutlinedButton(onPressed: page == pages ? null : () => setState(() => _page = page + 1), child: const Text('Next'))]),
      ]),
    ]));
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.title, required this.rows, required this.nameKey, required this.valueKey, this.currency = false});
  final String title, nameKey, valueKey;
  final List<Json> rows;
  final bool currency;
  @override
  Widget build(BuildContext context) {
    final top = rows.take(10).toList();
    final maxValue = top.fold<double>(1, (m, r) => math.max(m, _num(r[valueKey])));
    return _Panel(title: title, child: top.isEmpty ? const Padding(padding: EdgeInsets.all(32), child: Text('No chart data available', textAlign: TextAlign.center, style: TextStyle(color: _muted))) : Column(children: [for (final r in top) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Row(children: [Expanded(child: Text(_show(r[nameKey]), style: const TextStyle(fontSize: 13))), const SizedBox(width: 12), Text(currency ? _money(r[valueKey]) : _number(r[valueKey]), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))]), const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(minHeight: 10, value: (_num(r[valueKey]) / maxValue).clamp(0.0, 1.0), backgroundColor: const Color(0xFFEDF2FA), color: _blue))]))]));
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.title, required this.rows});
  final String title;
  final List<Json> rows;
  @override
  Widget build(BuildContext context) => _Panel(title: title, child: rows.isEmpty
      ? const Padding(padding: EdgeInsets.all(32), child: Text('No chart data available', textAlign: TextAlign.center, style: TextStyle(color: _muted)))
      : LayoutBuilder(builder: (context, bounds) {
          final width = math.max(560.0, bounds.maxWidth);
          return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: width, height: 240, child: Stack(children: [
            Positioned.fill(child: Semantics(label: '$title. ${rows.map((r) => '${_show(r['date'] ?? r['month'])}: ${_money(r['sales_amount'])}').join('; ')}', child: CustomPaint(painter: _TrendPainter(rows)))),
            ...List.generate(rows.length, (i) {
              final maxValue = rows.fold<double>(1, (m, r) => math.max(m, _num(r['sales_amount'])));
              final x = 105 + (rows.length < 2 ? (width - 125) / 2 : i * (width - 125) / (rows.length - 1));
              final y = 200 - _num(rows[i]['sales_amount']) / maxValue * 180;
              return Positioned(left: x - 10, top: y - 10, child: Tooltip(message: '${_show(rows[i]['date'] ?? rows[i]['month'])}: ${_money(rows[i]['sales_amount'])}', triggerMode: TooltipTriggerMode.tap, child: const SizedBox(width: 20, height: 20)));
            }),
          ])));
        }));
}
class _TrendPainter extends CustomPainter {
  _TrendPainter(this.rows);
  final List<Json> rows;
  void _text(Canvas canvas, String text, Offset offset, {bool right = false}) {
    final painter = TextPainter(text: TextSpan(text: text, style: const TextStyle(fontSize: 11, color: _muted)), textDirection: TextDirection.ltr)..layout();
    painter.paint(canvas, Offset(offset.dx - (right ? painter.width : 0), offset.dy));
  }
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = rows.fold<double>(1, (m, r) => math.max(m, _num(r['sales_amount'])));
    const left = 105.0, top = 20.0, bottom = 200.0;
    final right = size.width - 20;
    final grid = Paint()..color = const Color(0xFFE6EAF2)..strokeWidth = 1;
    for (final f in [0.0, .25, .5, .75, 1.0]) {
      final y = bottom - f * (bottom - top);
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
      _text(canvas, _money(maxValue * f), Offset(left - 10, y - 6), right: true);
    }
    final line = Paint()..color = const Color(0xFF2563EB)..strokeWidth = 3.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final points = <Offset>[];
    final path = Path();
    for (var i = 0; i < rows.length; i++) {
      final point = Offset(left + (rows.length < 2 ? (right - left) / 2 : i * (right - left) / (rows.length - 1)), bottom - _num(rows[i]['sales_amount']) / maxValue * (bottom - top));
      points.add(point);
      if (i == 0) { path.moveTo(point.dx, point.dy); } else { path.lineTo(point.dx, point.dy); }
    }
    canvas.drawPath(path, line);
    for (final point in points) { canvas.drawCircle(point, 4, Paint()..color = const Color(0xFF2563EB)); }
    _text(canvas, _show(rows.first['date'] ?? rows.first['month']), const Offset(left, 220));
    if (rows.length > 1) _text(canvas, _show(rows.last['date'] ?? rows.last['month']), Offset(right, 220), right: true);
  }
  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.rows != rows;
}

// Uses the same /api/get/staffs/ endpoint, Bearer token, results.data
// envelope and next-page URL as the supplied Staff List page.
class _StaffPicker extends StatefulWidget {
  const _StaffPicker({super.key, required this.baseUrl, required this.getToken, required this.onSelected, this.selectedId});
  final String baseUrl;
  final ValueChanged<Json> onSelected;
  final Future<String?> Function() getToken;
  final String? selectedId;
  @override
  State<_StaffPicker> createState() => _StaffPickerState();
}

class _StaffPickerState extends State<_StaffPicker> {
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 30)));
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final List<Json> _staffs = [];
  Timer? _debounce;
  CancelToken? _cancel;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  Uri? _next;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    getstaff();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 240 && _next != null && !_loading && !_loadingMore && _error == null) getstaff(loadMore: true);
  }

  Uri _buildStaffUri() => Uri.parse('${widget.baseUrl}/get/staffs/').replace(queryParameters: {
    'page': '1',
    if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
  });

  Future<void> getstaff({bool loadMore = false}) async {
    if (loadMore && (_loading || _loadingMore || _next == null)) return;
    final generation = loadMore ? _generation : ++_generation;
    if (!loadMore) _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final requestUri = loadMore ? _next! : _buildStaffUri();
    setState(() {
      _error = null;
      if (loadMore) { _loadingMore = true; } else { _loading = true; _loadingMore = false; _staffs.clear(); _next = null; }
    });
    try {
      final origin = Uri.parse(widget.baseUrl);
      if (requestUri.origin != origin.origin) throw Exception('Invalid staff pagination URL');
      final token = await widget.getToken();
      if (!mounted || generation != _generation) return;
      if (token == null || token.trim().isEmpty) throw Exception('Your session has expired. Please sign in again.');
      final response = await _dio.getUri<dynamic>(requestUri, options: Options(headers: {'Authorization': 'Bearer ${token.trim()}', 'Accept': 'application/json'}), cancelToken: cancel);
      if (!mounted || generation != _generation) return;
      final dynamic body = response.data is String ? jsonDecode(response.data as String) : response.data;
      List<Json> data;
      String? next;
      if (body is List) {
        data = _rows(body);
      } else if (body is Map) {
        final parsed = _map(body);
        final dynamic results = parsed['results'];
        final dynamic list = results is Map ? results['data'] : results ?? parsed['data'];
        if (list is! List) throw Exception('Invalid staff list response');
        data = _rows(list);
        next = parsed['next']?.toString();
      } else {
        throw Exception('Invalid staff list response');
      }
      setState(() {
        final ids = _staffs.map((s) => s['id'].toString()).toSet();
        _staffs.addAll(data.where((s) => s['id'] != null && ids.add(s['id'].toString())));
        _next = next == null || next.isEmpty ? null : requestUri.resolve(next);
        if (_next == requestUri) _next = null;
      });
    } catch (e) {
      if (!mounted || generation != _generation || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() => _error = e is DioException ? 'Failed to fetch staff list. Please retry.' : e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && generation == _generation) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    ++_generation;
    _cancel?.cancel();
    setState(() { _staffs.clear(); _next = null; _loading = true; _loadingMore = false; _error = null; });
    _debounce = Timer(const Duration(milliseconds: 350), () => getstaff());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancel?.cancel();
    _dio.close(force: true);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: math.min(360.0, MediaQuery.sizeOf(context).height * .5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _search, onChanged: _searchChanged, decoration: InputDecoration(hintText: 'Search staff...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 12),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _staffs.isEmpty ? Center(child: Text(_error == null ? 'No staff found' : _error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted))) : ListView.separated(
          controller: _scroll,
          itemCount: _staffs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final staff = _staffs[index];
            final selected = staff['id'].toString() == widget.selectedId;
            final details = [staff['designation'], staff['department_name'], staff['eid']].where((v) => v != null && v.toString().isNotEmpty).join(' · ');
            return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 4), selected: selected, selectedColor: _blue, leading: const CircleAvatar(backgroundColor: Color(0xFFEAF1FF), child: Icon(Icons.person_outline, color: _blue)), title: Text(_show(staff['name'])), subtitle: details.isEmpty ? null : Text(details), trailing: selected ? const Icon(Icons.check_circle, color: _blue) : null, onTap: () => widget.onSelected(staff));
          },
        )),
        if (_loadingMore) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        if (_error != null && _staffs.isNotEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (!_loading && !_loadingMore && (_next != null || _error != null)) TextButton.icon(onPressed: () => getstaff(loadMore: _staffs.isNotEmpty && _next != null), icon: Icon(_error != null ? Icons.refresh : Icons.expand_more), label: Text(_error != null ? 'Retry' : 'Load more staff')),
      ]),
  );
}

class _ReportPeriod {
  const _ReportPeriod({this.start, this.end, this.source = ''});
  final DateTime? start;
  final DateTime? end;
  final String source;
}
