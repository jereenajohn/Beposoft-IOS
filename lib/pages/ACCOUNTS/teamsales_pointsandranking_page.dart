import 'dart:async';
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
import 'package:beposoft/pages/api.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Uses the excel 2.x API. Every cell is written explicitly by (column, row)
// with updateCell so that empty cells can never shift values to the left.
class TeamSalesPointRankingPage extends StatefulWidget {
  const TeamSalesPointRankingPage({super.key});

  @override
  State<TeamSalesPointRankingPage> createState() =>
      _TeamSalesPointRankingPageState();
}

typedef _Json = Map<String, dynamic>;

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

List<_Json> _objects(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <_Json>[];

class _TeamSalesPointRankingPageState extends State<TeamSalesPointRankingPage> {
  static const _blue = Color(0xFF287BE4);
  final _client = http.Client();
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  late DateTime _start;
  late DateTime _end;
  String? _teamId;
  final Map<String, String> _teamOptions = {};
  _PointsReport? _report;
  String? _error;
  bool _loading = true;
  bool _exporting = false;
  int _request = 0;

  String _date(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  void initState() {
    super.initState();
    _currentMonth();
    _load();
  }

  void _currentMonth() {
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
    _teamId = null;
  }

  @override
  void dispose() {
    _request++;
    _client.close();
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  Future<_Json> _fetch(DateTime start, DateTime end, String? team) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.trim().isEmpty) {
      throw Exception('Session expired. Please sign in again.');
    }
    final base = api.toString().replaceFirst(RegExp(r'/+$'), '');
    final root = base.endsWith('/api') ? base : '$base/api';
    final uri = Uri.parse('$root/sales/point/team/ranking/').replace(
      queryParameters: {
        'start_date': _date(start),
        'end_date': _date(end),
        if (team != null) 'team_id': team,
      },
    );
    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 45));
    if (response.statusCode == 401) {
      throw Exception('Session expired. Please sign in again.');
    }
    if (response.statusCode == 403) {
      throw Exception('You do not have permission to view this report.');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw Exception('The server returned an invalid response.');
    }
    if (decoded is! Map) throw Exception('Invalid report response.');
    var body = Map<String, dynamic>.from(decoded);
    if (body['results'] is Map) {
      body = Map<String, dynamic>.from(body['results']);
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] != 'success') {
      throw Exception(body['message'] ??
          body['detail'] ??
          'Unable to load report (${response.statusCode}).');
    }
    if (body['data'] is! List) {
      throw Exception('The response is missing the team data list.');
    }
    return body;
  }

  Future<void> _load() async {
    final id = ++_request;
    final start = _start;
    final end = _end;
    final team = _teamId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // The unfiltered response supplies the team picker; no invented
      // team-list endpoint is required. Keep all options after filtering.
      final body = await _fetch(start, end, team);
      if (!mounted || id != _request) return;
      final teams = _objects(body['data']);
      final report = _PointsReport.build(body, start, end,
          team == null ? 'All teams' : (_teamOptions[team] ?? 'Selected team'));
      setState(() {
        for (final item in teams) {
          if (item['team_id'] != null) {
            _teamOptions['${item['team_id']}'] =
                '${item['team_name'] ?? 'Team'}';
          }
        }
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _loading = false;
        _error = e is TimeoutException
            ? 'The request timed out. Please retry.'
            : e is SocketException
                ? 'Unable to connect. Check your internet connection.'
                : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _filters() async {
    var start = _start;
    var end = _end;
    var team = _teamId ?? '';
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, update) {
        Future<void> pick(bool first) async {
          final selected = await showDatePicker(
            context: context,
            initialDate: first ? start : end,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100, 12, 31),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                    seedColor: _blue, brightness: Brightness.light),
              ),
              child: child!,
            ),
          );
          if (selected != null && sheetContext.mounted) {
            update(() {
              if (first) {
                start = selected;
              } else {
                end = selected;
              }
            });
          }
        }

        Widget dateField(String label, DateTime date, bool first) => Material(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => pick(first),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5EAF2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 18, color: _blue),
                        const SizedBox(width: 7),
                        Flexible(
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF718096)))),
                      ]),
                      const SizedBox(height: 10),
                      Text(DateFormat('dd MMM yyyy').format(date),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF152C4B))),
                    ],
                  ),
                ),
              ),
            );

        final invalid = end.isBefore(start);
        return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  22, 12, 22, 22 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                              color: const Color(0xFFDCE3ED),
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 22),
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEDF4FF),
                            borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.tune_rounded,
                            color: _blue, size: 23)),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filter team points',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF152C4B),
                                letterSpacing: -.4)),
                        SizedBox(height: 4),
                        Text('Choose your team and reporting period',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF718096))),
                      ],
                    )),
                    IconButton(
                        tooltip: 'Close filters',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded,
                            size: 21, color: Color(0xFF718096))),
                  ]),
                  const SizedBox(height: 24),
                  const Text('TEAM',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF718096))),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    value: team,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _blue),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF152C4B)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF6F8FC),
                      prefixIcon: const Icon(Icons.groups_2_outlined,
                          color: _blue, size: 22),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 17),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5EAF2))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All teams')),
                      ..._teamOptions.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child:
                              Text(e.value, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (value) => update(() => team = value ?? ''),
                  ),
                  const SizedBox(height: 22),
                  const Text('REPORTING PERIOD',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF718096))),
                  const SizedBox(height: 9),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 310 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20) {
                      return Column(children: [
                        dateField('Start date', start, true),
                        const SizedBox(height: 10),
                        dateField('End date', end, false),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: dateField('Start date', start, true)),
                      const SizedBox(width: 12),
                      Expanded(child: dateField('End date', end, false)),
                    ]);
                  }),
                  if (invalid)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F0),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.error_outline,
                              color: Color(0xFFD92D20), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'End date must be on or after start date.',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFFD92D20)))),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 22),
                  const Divider(height: 1, color: Color(0xFFEDF0F5)),
                  const SizedBox(height: 18),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFDCE3ED),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        onPressed: invalid
                            ? null
                            : () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('Apply filters'),
                      )),
                  const SizedBox(height: 5),
                  Center(
                      child: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => update(() {
                      final now = DateTime.now();
                      start = DateTime(now.year, now.month, 1);
                      end = DateTime(now.year, now.month + 1, 0);
                      team = '';
                    }),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset to current month'),
                  )),
                ],
              ),
            ));
      }),
    );
    if (applied == true && mounted) {
      _start = start;
      _end = end;
      _teamId = team.isEmpty ? null : team;
      await _load();
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _export() async {
    final report = _report;
    if (report == null || _loading || _exporting || _error != null) return;
    setState(() => _exporting = true);
    try {
      // Export the immutable loaded report, never un-applied filter values.
      final book = xl.Excel.createExcel();
      // Write straight into the default sheet. rename/delete mutate the
      // workbook's sheet list and throw "unmodifiable list" on some versions.
      final sheet = book[book.getDefaultSheet() ?? 'Sheet1'];

      // Column widths (UI pixels -> Excel character units).
      for (var c = 0; c < report.widths.length; c++) {
        sheet.setColWidth(c, report.widths[c] / 7);
      }
      // Row heights are not set: older excel versions have no setRowHeight.
      // Rows without a fixed height auto-fit their wrapped text in Excel.

      xl.Border thin() => xl.Border(borderStyle: xl.BorderStyle.Thin);
      xl.Border noBorder() => xl.Border(borderStyle: xl.BorderStyle.None);

      // Real Excel merges (sheet.merge) shift the cells of the merged rows
      // two columns to the right in this excel version, which is what put
      // BDO names under BILL. So no merge is used: the TEAM and TEAM POINTS
      // blocks are drawn as one box instead.
      final mergeAt = <String, _Merge>{};
      for (final merge in report.merges) {
        for (var r = merge.first; r <= merge.last; r++) {
          mergeAt['$r:${merge.column}'] = merge;
        }
      }

      // IMPORTANT: write every cell explicitly by (column, row) instead of
      // appendRow. appendRow drops empty values and shifts the rest of the
      // row to the left, which is what pushed BDO names into the BILL column.
      for (var r = 0; r < report.rows.length; r++) {
        final row = report.rows[r];
        for (var c = 0; c < row.cells.length; c++) {
          final item = row.cells[c];
          final block = mergeAt['$r:$c'];
          final index =
              xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r);
          final style = xl.CellStyle(
            bold: true,
            textWrapping: xl.TextWrapping.WrapText,
            backgroundColorHex: item.background,
            fontColorHex: item.foreground,
            horizontalAlign: c == 0 || c == 2
                ? xl.HorizontalAlign.Left
                : xl.HorizontalAlign.Center,
            verticalAlign: xl.VerticalAlign.Center,
            leftBorder: thin(),
            rightBorder: thin(),
            topBorder: block == null || r == block.first ? thin() : noBorder(),
            bottomBorder:
                block == null || r == block.last ? thin() : noBorder(),
          );
          dynamic value = item.value;
          if (block != null) {
            // Looks like a merged cell: the text sits in the middle row of
            // the block and the inner horizontal borders are removed.
            final mid = block.first + (block.last - block.first) ~/ 2;
            value = r == mid ? report.rows[block.first].cells[c].value : '';
          }
          final isEmpty = value == null || (value is String && value.isEmpty);
          if (isEmpty) {
            // Create the cell in its exact position and only style it.
            sheet.cell(index).cellStyle = style;
          } else {
            sheet.updateCell(index, value, cellStyle: style);
          }
        }
      }

      final bytes = book.encode();
      if (bytes == null) throw Exception('Unable to encode Excel file.');
      final directory = await getApplicationDocumentsDirectory();
      final name = 'Team_Points_${_date(report.start)}_${_date(report.end)}_'
          '${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _message('Excel saved to ${file.path}. ${result.message}');
      } else {
        _message('POINTS Excel exported successfully.');
      }
    } catch (e, stack) {
      debugPrint('Team POINTS export: $e');
      debugPrintStack(stackTrace: stack);
      _message(
          'Export failed: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _metric(String label, String value, IconData icon,
      {bool primary = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: primary
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF287BE4), Color(0xFF1555B7)],
              )
            : null,
        color: primary ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: primary ? null : Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163D70).withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primary
                ? Colors.white.withValues(alpha: .16)
                : const Color(0xFFEDF4FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: primary ? Colors.white : _blue),
        ),
        const SizedBox(height: 16),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: primary ? 30 : 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7,
                    color: primary ? Colors.white : const Color(0xFF152C4B)))),
        const SizedBox(height: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: primary
                    ? Colors.white.withValues(alpha: .8)
                    : const Color(0xFF718096))),
      ]),
    );
  }

  Widget _reportHeader(_PointsReport? report) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SALES PERFORMANCE',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF718096))),
                const SizedBox(height: 6),
                Text(report?.teamLabel ?? 'All teams',
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF152C4B),
                        letterSpacing: -.5)),
              ],
            )),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))),
              onPressed: _loading ||
                      _exporting ||
                      report == null ||
                      _error != null ||
                      report.memberCount == 0
                  ? null
                  : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined, size: 19),
              label: Text(_exporting ? 'Exporting' : 'Excel'),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5EAF2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_month_outlined, size: 16, color: _blue),
              const SizedBox(width: 7),
              Flexible(
                  child: Text(
                      '${DateFormat('dd MMM yyyy').format(report?.start ?? _start)}'
                      ' – ${DateFormat('dd MMM yyyy').format(report?.end ?? _end)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF516078)))),
            ]),
          ),
          if (report != null && !_loading && _error == null) ...[
            const SizedBox(height: 18),
            _metric('Total points', report.totalPoints.toStringAsFixed(2),
                Icons.emoji_events_outlined,
                primary: true),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _metric(
                      'Teams', '${report.teamCount}', Icons.groups_2_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: _metric('Displayed members', '${report.memberCount}',
                      Icons.badge_outlined)),
            ]),
            const SizedBox(height: 22),
            const Row(children: [
              Icon(Icons.table_chart_outlined, size: 19, color: _blue),
              SizedBox(width: 8),
              Text('POINTS worksheet',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF152C4B))),
            ]),
            const SizedBox(height: 5),
            const Text('Swipe sideways to view all columns',
                style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
          ],
        ]),
      );

  Widget _status(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 70),
      child: Center(child: child));

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
      debugPrint('Team Sales Points back navigation failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        _message('Unable to return to dashboard. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        body: SafeArea(
            top: false,
            child: CustomScrollView(
              controller: _vertical,
              slivers: [
                SliverAppBar(
                  leading: IconButton(
                    tooltip: 'Back',
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
                    onPressed: _navigateBack,
                  ),
                  pinned: false,
                  floating: false,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF152C4B),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 72,
                  titleSpacing: 0,
                  title: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Team Sales Points',
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.4)),
                        SizedBox(height: 3),
                        Text('Team performance report',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF718096),
                                fontWeight: FontWeight.w400)),
                      ]),
                  actions: [
                    IconButton(
                        tooltip: 'Filters',
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEDF4FF),
                            foregroundColor: _blue),
                        onPressed: _loading ? null : _filters,
                        icon: const Icon(Icons.tune_rounded, size: 21)),
                    IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded, size: 23)),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(child: _reportHeader(report)),
                if (_loading)
                  SliverToBoxAdapter(
                      child: _status(const CircularProgressIndicator()))
                else if (_error != null)
                  SliverToBoxAdapter(
                      child: _status(
                          Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ])))
                else if (report == null || report.memberCount == 0)
                  SliverToBoxAdapter(
                      child: _status(
                          Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.table_chart_outlined,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No eligible member data for this period.',
                        textAlign: TextAlign.center),
                    TextButton(
                        onPressed: _filters,
                        child: const Text('Change filters')),
                  ])))
                else
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          child: _ReportGrid(
                              report: report, horizontal: _horizontal))),
              ],
            )),
      ),
    );
  }
}

class _Cell {
  final dynamic value;
  final String background;
  final String foreground;
  const _Cell(this.value,
      [this.background = 'FFFFFF', this.foreground = '000000']);
}

class _GridRow {
  final List<_Cell> cells;
  final double height;
  const _GridRow(this.cells, [this.height = 34]);
}

class _Merge {
  final int column;
  final int first;
  final int last;
  const _Merge(this.column, this.first, this.last);
}

class _Category {
  final String label;
  final List<_Json> products = [];
  final bool boxes;
  _Category(this.label, {this.boxes = false});
}

class _PointsReport {
  final DateTime start;
  final DateTime end;
  final String teamLabel;
  final List<double> widths;
  final List<_GridRow> rows;
  final List<_Merge> merges;
  final double totalPoints;
  final int teamCount;
  final int memberCount;
  _PointsReport(this.start, this.end, this.teamLabel, this.widths, this.rows,
      this.merges, this.totalPoints, this.teamCount, this.memberCount);

  static _PointsReport build(
      _Json body, DateTime start, DateTime end, String teamLabel) {
    final teams = _objects(body['data']);
    final allMembers = teams.expand((t) => _objects(t['members'])).toList();
    final categories = [
      _Category('HELMETS', boxes: true),
      _Category('CH', boxes: true),
      _Category('BAG'),
      _Category('NEBULA CL'),
      _Category('NEBULA PRO'),
    ];
    final catalogue = <String, _Json>{};
    for (final source in [...teams, ...allMembers]) {
      for (final p in _objects(source['products'])) {
        catalogue['${p['product_id']}'] = p;
      }
    }
    for (final p in catalogue.values) {
      final name = '${p['product_name']}'.toUpperCase();
      final id = '${p['product_id']}';
      // IDs below are verified from the supplied response. New unmatched
      // products get their own columns so points are never silently lost.
      final int index;
      if (name.contains('HELMET')) {
        index = 0;
      } else if (id == '667' || RegExp(r'\bCH\s*1\b').hasMatch(name)) {
        index = 1;
      } else if (name.contains('BAG')) {
        index = 2;
      } else if (id == '902' || name.contains('NEBULA CL')) {
        index = 3;
      } else if (id == '940' || name.contains('NEBULA PRO')) {
        index = 4;
      } else {
        categories.add(_Category('${p['product_name']}')..products.add(p));
        continue;
      }
      categories[index].products.add(p);
    }
    final headers = <String>[
      'TEAM',
      'TEAM POINTS',
      'BDO NAME',
      'BDO POINTS',
      'BILL',
      '1 BILL 1 POINT',
    ];
    final widths = <double>[185, 120, 210, 120, 85, 125];
    final pointColumns = <int>{3, 5};
    final quantityColumns = <int>{4};
    for (final category in categories) {
      headers
          .add(category.label == 'CH' ? 'CH PAIRS' : '${category.label} PCS');
      quantityColumns.add(headers.length - 1);
      widths.add(130);
      if (category.boxes) {
        headers.add(category.label == 'CH' ? 'CH1 BOX' : 'BOX');
        widths.add(95);
      }
      final rules = category.products
          .map((p) =>
              '${_number(p['required_quantity']).toStringAsFixed(0)} PC '
              '(${_number(p['point_per_block']).toStringAsFixed(2)} POINTS)')
          .toSet();
      headers.add(rules.isEmpty
          ? '${category.label} POINTS'
          : rules.length == 1
              ? rules.first
              : '${category.label} POINTS');
      widths.add(145);
      pointColumns.add(headers.length - 1);
    }
    for (final label in [
      'M DEALER',
      'MD POINTS',
      'S DEALER',
      'SD POINTS',
      'NEW LEADS',
      'LEAD POINTS',
      'NEW CUSTOMERS',
      'CUSTOMER POINTS',
      'CONVERSIONS',
      'CONVERSION POINTS'
    ]) {
      headers.add(label);
      widths.add(130);
      if (label.endsWith('POINTS')) pointColumns.add(headers.length - 1);
    }
    List<dynamic> values(_Json member) {
      final result = <dynamic>[
        '',
        '',
        '${member['staff_name'] ?? 'Unnamed staff'}',
        _number(member['total_points']),
        _number(member['invoice_count']),
        _number(member['invoice_points'])
      ];
      final products = _objects(member['products']);
      for (final category in categories) {
        final ids = category.products.map((p) => '${p['product_id']}').toSet();
        final matches =
            products.where((p) => ids.contains('${p['product_id']}'));
        var quantity = 0.0;
        var boxes = 0.0;
        var points = 0.0;
        for (final product in matches) {
          final sold = _number(product['sold_quantity']);
          final required = _number(product['required_quantity']);
          quantity += sold;
          if (required > 0) boxes += sold / required;
          // Includes partial-block points already calculated by the backend.
          points += _number(product['earned_points']);
        }
        result.add(quantity);
        if (category.boxes) result.add(boxes);
        result.add(points);
      }
      for (final key in [
        'md_count',
        'md_points',
        'sd_count',
        'sd_points',
        'new_leads',
        'new_lead_points',
        'new_customers',
        'new_customer_points',
        'new_conversions',
        'new_conversion_points'
      ]) {
        result.add(_number(member[key]));
      }
      return result;
    }

    _GridRow header(List<String> labels) =>
        _GridRow(labels.map((s) => _Cell(s, 'FF0000', 'FFFFFF')).toList(), 64);
    final rows = <_GridRow>[header(headers)];
    final merges = <_Merge>[];
    final totals = List<double>.filled(headers.length, 0);
    for (final team in teams) {
      final members = _objects(team['members']);
      final first = rows.length;
      if (members.isEmpty) {
        final cells =
            List<_Cell>.generate(headers.length, (_) => const _Cell(''));
        cells[0] = _Cell('${team['team_name']}', 'FCE4D6');
        cells[1] = _Cell(_number(team['total_points']), 'FFFF00');
        cells[2] = const _Cell('No eligible members', 'FCE4D6');
        rows.add(_GridRow(cells));
      }
      for (var m = 0; m < members.length; m++) {
        final data = values(members[m]);
        data[0] = m == 0 ? '${team['team_name']}' : '';
        data[1] = m == 0 ? _number(team['total_points']) : '';
        final cells = <_Cell>[];
        for (var c = 0; c < data.length; c++) {
          if (c >= 3) totals[c] += _number(data[c]);
          final bg = c == 1 || c == 3
              ? 'FFFF00'
              : c == 0 || c == 2 || pointColumns.contains(c)
                  ? 'FCE4D6'
                  : quantityColumns.contains(c) ||
                          (c >= headers.length - 10 &&
                              !pointColumns.contains(c))
                      ? 'C6E0B4'
                      : 'FFFFFF';
          cells.add(_Cell(data[c], bg,
              pointColumns.contains(c) && c != 5 ? 'FF0000' : '000000'));
        }
        rows.add(_GridRow(cells));
      }
      if (members.length > 1) {
        merges.add(_Merge(0, first, rows.length - 1));
        merges.add(_Merge(1, first, rows.length - 1));
      }
    }
    final teamPoints =
        teams.fold<double>(0, (sum, t) => sum + _number(t['total_points']));
    rows.add(_GridRow(List.generate(
        headers.length,
        (c) => _Cell(
              c == 0
                  ? 'TOTAL'
                  : c == 1
                      ? teamPoints
                      : c == 2
                          ? ''
                          : totals[c],
              c < 3 ? 'E2EFDA' : 'FF0000',
              c < 3 ? '000000' : 'FFFFFF',
            ))));
    rows.add(
        _GridRow(List.generate(headers.length, (_) => const _Cell('')), 24));
    final summaryLabels = List<String>.filled(headers.length, '');
    summaryLabels[2] = 'TOTAL';
    summaryLabels[3] = 'POINTS';
    for (final c in quantityColumns) {
      summaryLabels[c] = headers[c];
    }
    rows.add(header(summaryLabels));
    rows.add(_GridRow(List.generate(
        headers.length,
        (c) => _Cell(
            c == 3
                ? teamPoints
                : quantityColumns.contains(c)
                    ? totals[c]
                    : '',
            c == 3 || quantityColumns.contains(c) ? 'FFFF00' : 'FFFFFF'))));
    rows.add(
        _GridRow(List.generate(headers.length, (_) => const _Cell('')), 24));
    final rankHeader = List<String>.filled(headers.length, '');
    rankHeader[2] = 'BDO NAME';
    rankHeader[3] = 'BDO POINTS';
    rows.add(header(rankHeader));
    // Sort within the loaded scope; do not invent a backend global rank.
    final ranked = List<_Json>.from(allMembers)
      ..sort((a, b) {
        final compare =
            _number(b['total_points']).compareTo(_number(a['total_points']));
        return compare != 0
            ? compare
            : '${a['staff_name']}'.compareTo('${b['staff_name']}');
      });
    for (final member in ranked) {
      rows.add(_GridRow(List.generate(
          headers.length,
          (c) => c == 2
              ? _Cell('${member['staff_name']}', 'FCE4D6')
              : c == 3
                  ? _Cell(_number(member['total_points']), 'FFFF00', 'FF0000')
                  : const _Cell(''))));
    }
    rows.add(_GridRow(List.generate(
        headers.length,
        (c) => c == 2
            ? const _Cell('TOTAL', 'E2EFDA')
            : c == 3
                ? _Cell(totals[3], 'FF0000', 'FFFFFF')
                : const _Cell(''))));
    return _PointsReport(start, end, teamLabel, widths, rows, merges,
        teamPoints, teams.length, allMembers.length);
  }
}

class _ReportGrid extends StatelessWidget {
  final _PointsReport report;
  final ScrollController horizontal;
  const _ReportGrid({required this.report, required this.horizontal});

  Color _color(String hex) => Color(int.parse('FF$hex', radix: 16));

  String _display(dynamic value) {
    if (value is num) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final xs = <double>[0];
    final ys = <double>[0];
    for (final w in report.widths) {
      xs.add(xs.last + w);
    }
    for (final row in report.rows) {
      ys.add(ys.last + row.height);
    }
    final merged = <String, _Merge>{};
    final covered = <String>{};
    for (final merge in report.merges) {
      merged['${merge.first}:${merge.column}'] = merge;
      for (var r = merge.first + 1; r <= merge.last; r++) {
        covered.add('$r:${merge.column}');
      }
    }
    return Scrollbar(
      controller: horizontal,
      thumbVisibility: true,
      notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: xs.last,
          child: SizedBox(
            height: ys.last,
            width: xs.last,
            child: Stack(children: [
              for (var r = 0; r < report.rows.length; r++)
                for (var c = 0; c < report.widths.length; c++)
                  if (!covered.contains('$r:$c'))
                    Positioned(
                        left: xs[c],
                        top: ys[r],
                        width: report.widths[c],
                        height: merged.containsKey('$r:$c')
                            ? ys[merged['$r:$c']!.last + 1] - ys[r]
                            : report.rows[r].height,
                        child: Container(
                          alignment: c == 0 || c == 2
                              ? Alignment.centerLeft
                              : Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                              color: _color(report.rows[r].cells[c].background),
                              border: Border.all(
                                  color: const Color(0xFF333333), width: .5)),
                          child: Text(_display(report.rows[r].cells[c].value),
                              textAlign: c == 0 || c == 2
                                  ? TextAlign.left
                                  : TextAlign.center,
                              maxLines: r == 0 ? 4 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _color(
                                      report.rows[r].cells[c].foreground))),
                        )),
            ]),
          ),
        ),
      ),
    );
  }
}
