import 'dart:convert';
import 'dart:io';

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

import 'package:excel/excel.dart' hide Border;
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StateWiseSalesReportPage extends StatefulWidget {
  const StateWiseSalesReportPage({super.key});

  @override
  State<StateWiseSalesReportPage> createState() =>
      _StateWiseSalesReportPageState();
}

class _StateWiseSalesReportPageState extends State<StateWiseSalesReportPage> {
  static const String _apiBase = 'https://bepocart.in/api/';
  static const Color _cyan = Color(0xFFB5F4F7);
  static const Color _green = Color(0xFFD2E5C5);
  static const Color _blue = Color(0xFFDCE7F5);
  static const Color _yellow = Color(0xFFFFFF00);
  static const Color _red = Color(0xFFC00000);
  static const Color _ink = Color(0xFF17233B);

  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedFamilyId;
  List<Map<String, dynamic>> _families = [];
  List<_StateSalesRow> _rows = [];
  int _totalOrders = 0;
  double _totalVolume = 0;
  bool _loadingFamilies = false;
  bool _loadingReport = false;
  bool _exporting = false;
  bool _hasReport = false;
  String? _reportError;
  String? _familyError;
  int _requestSequence = 0;

  // Matches the order and state naming used by the supplied spreadsheet.
  // Any additional states returned by the API are appended rather than lost.
  static const List<String> _stateOrder = [
    'Maharashtra', 'Tamil Nadu', 'Uttar Pradesh', 'Karnataka',
    'Gujarat', 'West Bengal', 'Rajasthan', 'Telangana',
    'Andhra Pradesh', 'Madhya Pradesh', 'Delhi', 'Kerala',
    'Haryana', 'Bihar', 'Odisha', 'Punjab', 'Assam',
    'Chhattisgarh', 'Jharkhand', 'Uttarakhand', 'Arunachal Pradesh',
    'Tripura', 'Meghalaya', 'Chandigarh', 'Jammu and Kashmir',
    'Ladakh', 'Goa', 'Himachal Pradesh', 'Manipur', 'Mizoram',
    'Nagaland', 'Sikkim', 'Andaman and Nicobar Islands',
    'Dadra and Nagar Haveli and Daman and Diu', 'Puducherry',
  ];

  static String _canonical(String value) {
    final s = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    const aliases = {
      'andhrapradesh': 'andhrapradesh',
      'andrapradesh': 'andhrapradesh',
      'odisha': 'odisha', 'orissa': 'odisha',
      'chattisgarh': 'chhattisgarh',
      'chhattisgarh': 'chhattisgarh',
      'jammukashmir': 'jammuandkashmir',
      'jammuandkashmir': 'jammuandkashmir',
      'pondicherry': 'puducherry', 'puducherry': 'puducherry',
      'andaman': 'andamanandnicobarislands',
      'andamanandnicobarislands': 'andamanandnicobarislands',
      'damananddiu': 'dadraandnagarhavelianddamananddiu',
      'dadraandnagarhaveli': 'dadraandnagarhavelianddamananddiu',
      'dadraandnagarhavelianddamananddiu':
          'dadraandnagarhavelianddamananddiu',
    };
    return aliases[s] ?? s;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _fetchFamilies();
  }

  String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  String _money(num value) => NumberFormat('#,##0.##').format(value);
  String _familyName() {
    for (final family in _families) {
      if (family['id'].toString() == _selectedFamilyId) {
        return (family['name'] ?? '').toString();
      }
    }
    return 'Select family';
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token')?.trim() ?? '';
    if (token.isEmpty) throw const _ReportException('Authentication token not found. Please log in again.');
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _fetchFamilies() async {
    if (_loadingFamilies) return;
    setState(() { _loadingFamilies = true; _familyError = null; });
    try {
      final token = await _token();
      final response = await http.get(
        Uri.parse('${_apiBase}familys/'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw _ReportException('Unable to load families (HTTP ${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      final dynamic data = decoded is Map ? decoded['data'] : null;
      if (data is! List) throw const _ReportException('Unexpected family API response.');
      final families = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['id'] != null && e['name'] != null).toList();
      if (!mounted) return;
      setState(() {
        _families = families;
        if (!_families.any((e) => e['id'].toString() == _selectedFamilyId)) {
          _selectedFamilyId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _familyError = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loadingFamilies = false; });
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) { _startDate = picked; } else { _endDate = picked; }
    });
  }

  Future<void> _fetchReport() async {
    if (_loadingReport) return;
    if (_selectedFamilyId == null) {
      _message('Please select a family.', error: true);
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _message('End date cannot be before start date.', error: true);
      return;
    }
    final requestId = ++_requestSequence;
    setState(() {
      _loadingReport = true;
      _reportError = null;
      _hasReport = false;
      _rows = [];
      _totalOrders = 0;
      _totalVolume = 0;
    });
    try {
      final token = await _token();
      final uri = Uri.parse('${_apiBase}reports/state/wise/sales/').replace(
        queryParameters: {
          'start_date': _date(_startDate),
          'end_date': _date(_endDate),
          'family_id': _selectedFamilyId!,
        },
      );
      debugPrint('STATE WISE SALES GET: $uri');
      final response = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        String detail = 'Failed to load report (HTTP ${response.statusCode}).';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) detail = (body['message'] ?? body['detail'] ?? detail).toString();
        } catch (_) {}
        throw _ReportException(detail);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List || decoded['summary'] is! Map) {
        throw const _ReportException('Unexpected report API response.');
      }
      final items = (decoded['data'] as List).whereType<Map>().map((e) =>
          _StateSalesRow.fromJson(Map<String, dynamic>.from(e))).toList();
      final summary = decoded['summary'] as Map;
      final sorted = _orderedRows(items);
      if (!mounted || requestId != _requestSequence) return;
      setState(() {
        _rows = sorted;
        _totalOrders = _asInt(summary['total_orders']);
        _totalVolume = _asDouble(summary['total_volume']);
        _hasReport = true;
      });
    } catch (e) {
      if (!mounted || requestId != _requestSequence) return;
      setState(() { _reportError = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted && requestId == _requestSequence) {
        setState(() { _loadingReport = false; });
      }
    }
  }

  static int _asInt(dynamic value) => value is num
      ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  static double _asDouble(dynamic value) => value is num
      ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  List<_StateSalesRow> _orderedRows(List<_StateSalesRow> source) {
    final byName = <String, _StateSalesRow>{};
    for (final row in source) {
      final key = _canonical(row.name);
      final previous = byName[key];
      if (previous == null) {
        byName[key] = row;
      } else {
        // The reference merges duplicate spellings/union-territory aliases.
        byName[key] = _StateSalesRow(
          name: previous.name,
          orders: previous.orders + row.orders,
          volume: previous.volume + row.volume,
        );
      }
    }
    final result = <_StateSalesRow>[];
    for (final name in _stateOrder) {
      result.add(byName.remove(_canonical(name)) ??
          _StateSalesRow(name: name, orders: 0, volume: 0));
    }
    final remaining = byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    result.addAll(remaining);
    return result;
  }

  Future<void> _exportExcel() async {
    if (_exporting || _loadingReport || !_hasReport) return;
    setState(() { _exporting = true; });
    try {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) excel.delete(defaultSheet);
      final sheet = excel['STATE WISE SALES'];
      sheet.setColWidth(0, 43);
      sheet.setColWidth(1, 18);
      sheet.setColWidth(2, 22);

      void write(int row, int col, dynamic value, Color color,
          {bool bold = false, int fontSize = 11}) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        // This uses the same Excel package API as the supplied GSTReportPage.
        if (value is int) {
          cell.value = value;
        } else if (value is double) {
          cell.value = value;
        } else {
          cell.value = value.toString();
        }
        cell.cellStyle = CellStyle(
          backgroundColorHex: '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
          bold: bold,
          fontSize: fontSize,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
          rightBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
          topBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
          bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
        );
      }

      // A1:C1 title, A2:C2 column headers, rows 3+ data.
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('C1'));
      write(0, 0, _familyName(), _cyan, bold: true, fontSize: 20);

      write(1, 0, 'STATE', _cyan, bold: true);
      write(1, 1, 'NO.OF BILLS', _cyan, bold: true);
      write(1, 2, 'VOLUME', _cyan, bold: true);


      for (var i = 0; i < _rows.length; i++) {
        final item = _rows[i];
        final row = i + 2;
        final stateColor = i.isEven ? _green : _blue;
        write(row, 0, item.name, stateColor);
        final hasOrders = item.orders != 0;
        final hasVolume = item.volume != 0;
        write(row, 1, hasOrders ? item.orders : '', hasOrders ? _yellow : _red);
        write(row, 2, hasVolume ? item.volume : '', hasVolume ? _yellow : _red);

      }
      final totalRow = _rows.length + 2;
      write(totalRow, 0, '', _cyan, bold: true);
      write(totalRow, 1, _totalOrders, _cyan, bold: true);
      write(totalRow, 2, _totalVolume, _cyan, bold: true);


      final bytes = excel.encode();
      if (bytes == null) throw const _ReportException('Could not encode Excel workbook.');
      final directory = await getApplicationDocumentsDirectory();
      final family = _familyName().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filename = 'STATE_WISE_SALES_${family}_${_date(_startDate)}_TO_${_date(_endDate)}.xlsx';
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _message('Excel exported successfully.');
      final result = await OpenFilex.open(file.path);
      debugPrint('Excel open result: ${result.type} ${result.message}');
    } catch (e, st) {
      debugPrint('State wise sales export failed: $e\n$st');
      _message('Excel export failed: $e', error: true);
    } finally {
      if (mounted) setState(() { _exporting = false; });
    }
  }

  Widget _dateField(String title, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9E1EC)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_month_outlined, size: 19, color: Color(0xFF2865E8)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            Text(DateFormat('dd MMM yyyy').format(value),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E7F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Report Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dateField('Start Date', _startDate, () => _pickDate(start: true))),
          const SizedBox(width: 10),
          Expanded(child: _dateField('End Date', _endDate, () => _pickDate(start: false))),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedFamilyId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Product Family',
            prefixIcon: const Icon(Icons.category_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          hint: Text(_loadingFamilies ? 'Loading families...' : 'Select family'),
          items: _families.map((f) => DropdownMenuItem<String>(
            value: f['id'].toString(),
            child: Text(f['name'].toString(), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: _loadingFamilies || _loadingReport ? null : (value) {
            setState(() { _selectedFamilyId = value; });
          },
        ),
        if (_familyError != null) ...[
          const SizedBox(height: 8),
          Text(_familyError!, style: const TextStyle(color: Colors.red)),
          TextButton.icon(onPressed: _fetchFamilies,
            icon: const Icon(Icons.refresh), label: const Text('Retry families')),
        ],
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 46,
          child: FilledButton.icon(
            onPressed: _loadingReport ? null : _fetchReport,
            icon: _loadingReport
                ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.filter_alt_outlined),
            label: Text(_loadingReport ? 'Loading Report...' : 'Generate Report'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2865E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF2865E8), size: 22),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink))),
      ]),
    ));
  }

  Widget _tableCell(String text, {required double width, required Color color,
      bool bold = false, bool isHeader = false}) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 33),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(color: color, border: Border.all(color: Colors.black87, width: .65)),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(fontSize: isHeader ? 11 : 12,
          fontFamily: 'serif', fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color == _red ? Colors.white : Colors.black)),
    );
  }

  Widget _reportTable() {
    const stateWidth = 285.0;
    const billsWidth = 112.0;
    const volumeWidth = 132.0;
    Widget row(String state, String bills, String volume, int index, {bool header = false, bool total = false}) {
      final stripe = total || header ? _cyan : (index.isEven ? _green : _blue);
      final hasBills = bills.isNotEmpty;
      final hasVolume = volume.isNotEmpty;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _tableCell(state, width: stateWidth, color: stripe, bold: header || total, isHeader: header),
        _tableCell(bills, width: billsWidth,
          color: header || total ? _cyan : (hasBills ? _yellow : _red), bold: header || total, isHeader: header),
        _tableCell(volume, width: volumeWidth,
          color: header || total ? _cyan : (hasVolume ? _yellow : _red), bold: header || total, isHeader: header),
      ]);
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0))),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          const Expanded(child: Text('State-wise Sales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink))),
          Text('${_rows.length} rows', style: const TextStyle(color: Colors.blueGrey)),
        ])),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: stateWidth + billsWidth + volumeWidth,
              alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: _cyan, border: Border.all(color: Colors.black87, width: .65)),
              child: Text(_familyName(), style: const TextStyle(fontFamily: 'serif', fontSize: 24, color: Colors.black))),
            row('STATE', 'NO.OF BILLS', 'VOLUME', 0, header: true),
            for (var i = 0; i < _rows.length; i++)
              row(_rows[i].name,
                _rows[i].orders == 0 ? '' : _rows[i].orders.toString(),
                _rows[i].volume == 0 ? '' : _money(_rows[i].volume), i),
            row('', _totalOrders.toString(), _money(_totalVolume), 0, total: true),
          ],
        )),
      ]),
    );
  }

  Future<void> _navigateBack() async {
    final prefs = await SharedPreferences.getInstance();
    final dep = prefs.getString('department');
    if (!mounted) return;

    final Widget destination;
    if (dep == 'BDO') {
      destination = bdo_dashbord();
    } else if (dep == 'COO' || dep == 'CEO') {
      destination = ceo_dashboard();
    } else if (dep == 'OPERATIONS') {
      destination = OperationsExecutiveDashboard();
    } else if (dep == 'HR') {
      destination = HrDashboard();
    } else if (dep == 'CSO') {
      destination = cso_dashboard();
    } else if (dep == 'BDM') {
      destination = bdm_dashbord();
    } else if (dep == 'warehouse') {
      destination = WarehouseDashboard();
    } else if (dep == 'Marketing') {
      destination = marketing_dashboard();
    } else if (dep == 'Warehouse Admin') {
      destination = WarehouseAdmin();
    } else {
      destination = dashboard();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();
        return false;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        title: const Text('State-wise Sales Report', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _navigateBack),
        actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh),
          onPressed: _loadingReport ? null : () async {
            await _fetchFamilies();
            if (_hasReport) await _fetchReport();
          })],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchFamilies();
          if (_selectedFamilyId != null) await _fetchReport();
        },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2865E8), Color(0xFF143D98)]),
              borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.bar_chart_rounded, color: Colors.white, size: 35),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Division Sales Analytics',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('State-wise bills and sales volume',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          _filters(),
          const SizedBox(height: 16),
          if (_reportError != null) ...[
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_reportError!, style: TextStyle(color: Colors.red.shade800))),
            const SizedBox(height: 16),
          ],
          if (_hasReport) ...[
            Row(children: [
              _summaryCard('Total Bills', NumberFormat('#,##0').format(_totalOrders), Icons.receipt_long_outlined),
              const SizedBox(width: 12),
              _summaryCard('Total Volume', '₹${_money(_totalVolume)}', Icons.currency_rupee_rounded),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(
              onPressed: _exporting ? null : _exportExcel,
              icon: _exporting
                ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download_outlined),
              label: Text(_exporting ? 'Exporting Excel...' : 'Export Excel'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF11835A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(height: 16),
            _reportTable(),
            const SizedBox(height: 24),
          ] else if (_loadingReport) ...[
            const SizedBox(height: 80),
            const Center(child: CircularProgressIndicator()),
          ] else if (_reportError == null) ...[
            const SizedBox(height: 70),
            const Center(child: Column(children: [
              Icon(Icons.analytics_outlined, size: 55, color: Colors.blueGrey),
              SizedBox(height: 12),
              Text('Choose a family and generate the report',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey)),
            ])),
          ],
        ]),
      ),
      ),
    );
  }
}

class _StateSalesRow {
  final String name;
  final int orders;
  final double volume;
  const _StateSalesRow({required this.name, required this.orders, required this.volume});
  factory _StateSalesRow.fromJson(Map<String, dynamic> json) {
    final rawName = json['state_name']?.toString().trim() ?? '';
    return _StateSalesRow(
      name: rawName.isEmpty || rawName.toLowerCase() == 'none' ? 'Unspecified' : rawName,
      orders: _StateWiseSalesReportPageState._asInt(json['order_count']),
      volume: _StateWiseSalesReportPageState._asDouble(json['volume']),
    );
  }
}

class _ReportException implements Exception {
  final String message;
  const _ReportException(this.message);
  @override
  String toString() => message;
}
