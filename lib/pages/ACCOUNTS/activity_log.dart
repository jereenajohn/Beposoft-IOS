import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class Activity_log extends StatefulWidget {
  const Activity_log({super.key});

  @override
  State<Activity_log> createState() => _Activity_logState();
}

class _Activity_logState extends State<Activity_log> {
  static const _blue = Color(0xFF1D4ED8);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF475569);
  static const _line = Color(0xFFCBD5E1);
  static const _pageSize = 50;
  final _client = http.Client();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _logs = [];
  DateTime? _start, _end;
  String _query = '', _staffName = '', _role = '';
  int? _staffId;
  int _page = 1, _count = 0, _request = 0;
  bool _loading = false, _exporting = false, _deleting = false;
  String? _error;

  String get _base => api.toString().replaceFirst(RegExp(r'/+$'), '');
  int get _pages => math.max(1, (_count / _pageSize).ceil());
  bool get _busy => _exporting || _deleting;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _role = prefs.get('active')?.toString() ?? '');
    await _fetch();
  }

  @override
  void dispose() {
    _request++;
    _client.close();
    _search.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _text(dynamic value, [String fallback = '-']) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token')?.trim();
    if (token == null || token.isEmpty) {
      throw const _LogException('Your session is unavailable. Please log in again.');
    }
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  Future<dynamic> _get(Uri uri) async {
    final headers = await _headers();
    final response = await _client.get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<dynamic> _decode(http.Response response) async {
    if (response.statusCode == 401) {
      throw const _LogException('Your session has expired. Please log in again.');
    }
    if (response.statusCode == 403) {
      throw const _LogException('You do not have permission to perform this action.');
    }
    dynamic body;
    try {
      body = await compute(_decodeLogJson, response.bodyBytes);
    } catch (_) {
      throw const _LogException('The server returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _LogException(body is Map
          ? _text(body['message'] ?? body['error'] ?? body['detail'], 'Request failed.')
          : 'Request failed (${response.statusCode}).');
    }
    return body;
  }

  Map<String, String> _filters() => {
    'page_size': '$_pageSize',
    if (_query.isNotEmpty) 'search': _query,
    if (_start != null) 'from': DateFormat('yyyy-MM-dd').format(_start!),
    if (_end != null) 'to': DateFormat('yyyy-MM-dd').format(_end!),
    if (_staffId != null) 'user': '$_staffId',
  };

  Future<void> _fetch({int? page}) async {
    final requestedPage = page ?? _page;
    final request = ++_request;
    final filters = _filters();
    setState(() { _loading = true; _error = null; });
    try {
      final body = await _get(Uri.parse('$_base/api/datalog/').replace(
        queryParameters: {...filters, 'page': '$requestedPage'},
      ));
      final rows = await compute(_normalizeLogRows, body);
      if (!mounted || request != _request) return;
      setState(() {
        _logs = rows;
        _page = requestedPage;
        _count = body is Map
            ? int.tryParse('${body['count']}') ?? rows.length : rows.length;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() { _error = _errorText(error); _logs = []; });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  String _errorText(Object error) => error is _LogException ? error.message
      : error is TimeoutException ? 'Request timed out. Please retry.'
      : 'Unable to connect. Check your connection and try again.';

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? (start ? _end : _start) ?? now,
      firstDate: !start && _start != null ? _start! : DateTime(1900),
      lastDate: start && _end != null ? _end! : DateTime(2200),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _blue)),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() { if (start) { _start = selected; } else { _end = selected; } });
    await _fetch(page: 1);
  }

  void _clear() {
    _search.clear();
    setState(() { _query = ''; _staffId = null; _staffName = ''; _start = null; _end = null; });
    _fetch(page: 1);
  }

  Future<void> _chooseStaff() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _LogStaffPicker(
        fetch: (query) async {
          final body = await _get(Uri.parse('$_base/api/get/staffs/').replace(
            queryParameters: {'page': '1', 'page_size': '50', if (query.isNotEmpty) 'search': query},
          ));
          final rows = body is Map && body['results'] is Map ? body['results']['data'] : null;
          if (rows is! List) throw const _LogException('Unexpected staff response.');
          return rows.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
        },
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _staffId = int.tryParse('${result['id']}');
      _staffName = _staffId == null ? '' : _text(result['name']);
    });
    await _fetch(page: 1);
  }

  Future<void> _deleteOld() async {
    if (_role != 'ADMIN' || _busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete old logs?'),
        content: const Text('Are you sure you want to delete the 100 oldest DataLog entries?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true), child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final response = await _client.delete(Uri.parse('$_base/api/datalog/delete/'),
        headers: await _headers()).timeout(const Duration(seconds: 30));
      final body = response.statusCode == 204 ? null : await _decode(response);
      _message(body is Map ? _text(body['message'], 'Deleted successfully') : 'Deleted successfully');
      if (mounted) await _fetch(page: 1);
    } catch (error) {
      _message(_errorText(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    final filters = _filters();
    final start = _start, end = _end, staffId = _staffId;
    setState(() => _exporting = true);
    _message('Preparing complete Excel export...');
    try {
      final logs = <Map<String, dynamic>>[];
      var page = 1;
      final seen = <String>{};
      while (true) {
        final body = await _get(Uri.parse('$_base/api/datalog/').replace(
          queryParameters: {...filters, 'page': '$page'},
        ));
        if (!mounted) return;
        final rows = await compute(_normalizeLogRows, body);
        final fingerprint = jsonEncode(rows);
        if (rows.isNotEmpty && !seen.add(fingerprint)) {
          throw const _LogException('The server repeated a page. Export stopped to prevent duplicate logs.');
        }
        logs.addAll(rows);
        if (body is! Map || body['next'] == null || '${body['next']}'.isEmpty) break;
        if (rows.isEmpty) throw const _LogException('The server returned an empty page before export completed.');
        page++;
      }
      if (logs.isEmpty) { _message('No data available to export'); return; }
      final bytes = await compute(_AuditWorkbook.build, logs);
      final datePart = start != null || end != null
          ? '${start == null ? 'start' : DateFormat('yyyy-MM-dd').format(start)}_to_${end == null ? 'end' : DateFormat('yyyy-MM-dd').format(end)}'
          : 'All';
      final name = 'DataLog_All_$datePart${staffId == null ? '' : '_Staff_$staffId'}.xlsx';
      // Same application-documents/save/open flow as GSTReportPage.
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _message('${logs.length} logs exported successfully');
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) _message('Excel saved. ${result.message}');
    } catch (error) {
      _message(error is _LogException ? error.message : 'Excel export failed: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _badge(String label, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(24)),
    child: Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w800)),
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(.08), blurRadius: 25, offset: const Offset(0, 8))]),
    child: child,
  );

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFB8C2D6), width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFB8C2D6), width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _blue, width: 1.5)),
  );

  Widget _label(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 8), child],
  );

  Widget _button(String text, Color color, VoidCallback? onTap, {IconData? icon, bool busy = false}) => SizedBox(
    height: 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (busy) ...[const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 8)]
        else if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Text(text),
      ]),
    ),
  );

  Widget _filtersCard() => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Data Log Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
    const SizedBox(height: 5),
    const Text('Search activity and review before and after values.', style: TextStyle(color: _muted, fontSize: 14)),
    const SizedBox(height: 14),
    Wrap(spacing: 8, runSpacing: 8, children: [
      _badge('Total Logs: $_count', _blue, Colors.white),
      _badge('Showing: ${_logs.length}', const Color(0xFF0E7490), Colors.white),
    ]),
    const SizedBox(height: 22),
    LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final fieldWidth = width >= 1000 ? (width - 48) / 5 : width >= 600 ? (width - 12) / 2 : width;
      return Wrap(spacing: 12, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.end, children: [
        SizedBox(width: fieldWidth, child: _label('Search', TextField(
          controller: _search, enabled: !_busy, onSubmitted: (_) => _submitSearch(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: _input('Search staff, invoice, data...'),
        ))),
        _button('Search', _blue, _busy ? null : _submitSearch),
        SizedBox(width: fieldWidth, child: _label('Staff', InkWell(
          onTap: _busy ? null : _chooseStaff,
          child: InputDecorator(decoration: _input('Search staff...').copyWith(suffixIcon: const Icon(Icons.expand_more)),
            child: Text(_staffName.isEmpty ? 'Search staff...' : _staffName,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: _staffName.isEmpty ? _muted : _ink))),
        ))),
        for (final start in [true, false]) SizedBox(width: width >= 300 && width < 600 ? (width - 12) / 2 : fieldWidth, child: _label(start ? 'Start Date' : 'End Date', InkWell(
          onTap: _busy ? null : () => _pickDate(start),
          child: InputDecorator(decoration: _input('Select date').copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
            child: Text((start ? _start : _end) == null ? 'Select date' : DateFormat('dd/MM/yyyy').format((start ? _start : _end)!), style: const TextStyle(fontSize: 14))),
        ))),
        _button('Clear', const Color(0xFF64748B), _busy ? null : _clear),
        _button(_exporting ? 'Exporting...' : 'Export Excel', const Color(0xFF16A34A), _busy ? null : _export, icon: Icons.file_download_outlined, busy: _exporting),
        if (_role == 'ADMIN') _button(_deleting ? 'Deleting...' : 'Delete', const Color(0xFFDC2626), _busy ? null : _deleteOld, icon: Icons.delete_outline, busy: _deleting),
      ]);
    }),
  ]));

  void _submitSearch() {
    setState(() => _query = _search.text.trim());
    _fetch(page: 1);
  }

  int _fieldCount(dynamic data) => data is Map ? data.length : 0;

  // Keep the list preview bounded; full audit values remain in the bottom sheet.
  String _previewValue(dynamic value, [int depth = 0]) {
    if (value == null) return '-';
    if (depth >= 2 && (value is Map || value is List)) return '…';
    if (value is Map) {
      if (value.isEmpty) return '-';
      return value.entries.take(3).map((entry) =>
        '${entry.key}: ${_previewValue(entry.value, depth + 1)}').join(', ');
    }
    if (value is List) {
      if (value.isEmpty) return '-';
      return value.take(2).map((item) => _previewValue(item, depth + 1)).join(', ');
    }
    final text = value.toString();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  String _changePreview(dynamic data) {
    if (data is Map) {
      for (final key in ['status', 'action', 'value']) {
        final value = data[key];
        if (value == null) continue;
        final preview = _previewValue(value);
        if (preview.trim().isEmpty || preview == '-') continue;
        return key == 'action' ? 'Action: $preview' : preview;
      }
    }
    return _previewValue(data);
  }

  Widget _changePreviewBlock(String label, String value, bool before) {
    final foreground = before ? const Color(0xFF991B1B) : const Color(0xFF166534);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: before ? const Color(0xFFFFF7F7) : const Color(0xFFF0FDF4),
        border: Border.all(color: before ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, height: 1.4, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _logCard(Map<String, dynamic> log, int index) {
    final name = _text(log['user_name']);
    final invoice = _text(log['order_name']);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showLogDetails(log),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(name.characters.take(2).toString().toUpperCase(),
                  style: const TextStyle(fontSize: 13, color: _blue, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 4),
                Text('Log #${_text(log['id'])} • ${(_page - 1) * _pageSize + index + 1}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ]),
            if (invoice != '-') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Text(invoice, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _badge('Old Data • ${_fieldCount(log['before_data'])}', const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
              _badge('Changed To • ${_fieldCount(log['after_data'])}', const Color(0xFFDCFCE7), const Color(0xFF166534)),
            ]),
            const SizedBox(height: 12),
            _changePreviewBlock('Old Data', _changePreview(log['before_data']), true),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF94A3B8)),
            ),
            _changePreviewBlock('Changed To', _changePreview(log['after_data']), false),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Expanded(child: Text(_dateTime(log['created_at']),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600))),
              const Text('View details', style: TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      ),
    );
  }

  List<Widget> _detailSlivers(dynamic data, bool before) {
    final entries = data is Map && data.isNotEmpty
        ? data.entries.toList()
        : [MapEntry(data is Map ? '-' : 'Value', data is Map ? '-' : data)];
    final color = before ? const Color(0xFF991B1B) : const Color(0xFF166534);
    final background = before ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final border = before ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        sliver: SliverToBoxAdapter(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: background,
            border: Border.all(color: border),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Icon(before ? Icons.history_rounded : Icons.check_circle_outline_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(before ? 'Old Data' : 'Changed To',
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900))),
            _badge('${_fieldCount(data)} Fields', Colors.white, color),
          ]),
        )),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = entries[index];
            final last = index == entries.length - 1;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: before ? const Color(0xFFFFF7F7) : const Color(0xFFF0FDF4),
                border: Border.all(color: border),
                borderRadius: last ? const BorderRadius.vertical(bottom: Radius.circular(12)) : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${entry.key}', style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                SelectableText(_displayValue(entry.value),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.5, fontWeight: FontWeight.w600)),
              ]),
            );
          },
          childCount: entries.length,
          addAutomaticKeepAlives: false,
        )),
      ),
    ];
  }

  void _showLogDetails(Map<String, dynamic> log) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 760),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .4,
        maxChildSize: .96,
        builder: (context, controller) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
            child: Row(children: [
              Expanded(child: Text('Log #${_text(log['id'])}',
                style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Close details', onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 21)),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(child: CustomScrollView(
            controller: controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF3F6FB), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_text(log['user_name']), style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Invoice: ${_text(log['order_name'])}', style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_dateTime(log['created_at']), style: const TextStyle(color: _muted, fontSize: 12)),
                  ]),
                )),
              ),
              ..._detailSlivers(log['before_data'], true),
              ..._detailSlivers(log['after_data'], false),
              SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _pagination() => Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
    for (final entry in <String, int>{'First': 1, 'Prev': math.max(1, _page - 1)}.entries)
      OutlinedButton(onPressed: _loading || _busy || _page == 1 ? null : () => _fetch(page: entry.value), child: Text(entry.key)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$_page / $_pages', style: const TextStyle(fontWeight: FontWeight.w900))),
    for (final entry in <String, int>{'Next': math.min(_pages, _page + 1), 'Last': _pages}.entries)
      OutlinedButton(onPressed: _loading || _busy || _page >= _pages ? null : () => _fetch(page: entry.value), child: Text(entry.key)),
  ]);

  Widget _listState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Center(child: _loading
      ? const CircularProgressIndicator(color: _blue)
      : _error != null
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB91C1C))),
            TextButton.icon(onPressed: () => _fetch(), icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ])
        : const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.manage_search_rounded, size: 36, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('No logs found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Try changing the search or date filter.', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
          ])),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F6FB),
    appBar: AppBar(
      title: const Text('Data Log Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white, foregroundColor: _ink, surfaceTintColor: Colors.transparent,
      actions: [IconButton(tooltip: 'Refresh', onPressed: _loading || _busy ? null : () => _fetch(), icon: const Icon(Icons.refresh_rounded))],
    ),
    body: SafeArea(child: RefreshIndicator(
      onRefresh: () => _fetch(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        cacheExtent: 250,
        slivers: [
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), sliver: SliverToBoxAdapter(child: _filtersCard())),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 14),
            sliver: SliverToBoxAdapter(child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Activity Logs', style: TextStyle(fontSize: 18, color: _ink, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Tap a log to view all changes', style: TextStyle(fontSize: 12, color: _muted)),
              ])),
              _badge('$_page / $_pages', const Color(0xFFEAF0FB), _blue),
            ])),
          ),
          if (_loading || _error != null || _logs.isEmpty)
            SliverToBoxAdapter(child: _listState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (context, index) => index.isOdd ? const SizedBox(height: 10)
                  : _logCard(_logs[index ~/ 2], index ~/ 2),
                childCount: _logs.length * 2 - 1,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              )),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Showing ${_count == 0 || _logs.isEmpty ? 0 : (_page - 1) * _pageSize + 1} to ${math.min((_page - 1) * _pageSize + _logs.length, _count)} of $_count entries',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12), _pagination(),
            ])),
          ),
        ],
      ),
    )),
  );
}

dynamic _decodeLogJson(Uint8List bytes) => jsonDecode(utf8.decode(bytes));

List<Map<String, dynamic>> _normalizeLogRows(dynamic body) {
  final rows = body is List ? body : body is Map ? body['results'] : null;
  if (rows is! List) {
    throw const _LogException('Unexpected log response: expected a list of logs.');
  }
  return rows.whereType<Map>().map((row) => {
    ...Map<String, dynamic>.from(row),
    'before_data': _normal(row['before_data']),
    'after_data': _normal(row['after_data']),
  }).toList();
}

class _LogException implements Exception {
  final String message;
  const _LogException(this.message);
  @override
  String toString() => message;
}

String _dateTime(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null ? (value?.toString() ?? '') : DateFormat('dd/MM/yyyy HH:mm:ss').format(date.toLocal());
}

dynamic _parseLoose(String input) {
  try { return jsonDecode(input); } catch (_) {}
  try { return _LooseValueParser(input).parse(); } catch (_) { return null; }
}

dynamic _normal(dynamic value) {
  dynamic result;
  if (value == null) { result = <String, dynamic>{}; }
  else if (value is Map || value is List) { result = value; }
  else if (value is String) { result = _parseLoose(value) ?? {'value': value}; }
  else { result = {'value': '$value'}; }
  if (result is Map) {
    for (final key in ['Data', 'data']) {
      if (result[key] is String) {
        final parsed = _parseLoose(result[key] as String);
        if (parsed is Map || parsed is List) return parsed;
      }
    }
  }
  return result;
}

String _displayValue(dynamic value) {
  if (value == null) return '-';
  if (value is Map) return value.entries.map((e) => '${e.key}: ${_displayValue(e.value)}').join(', ');
  if (value is List) return value.map(_displayValue).join(', ');
  return '$value';
}

String _excelValue(dynamic value) {
  if (value == null) return '-';
  if (value is String) {
    final parsed = _parseLoose(value);
    if (parsed is Map || parsed is List) return _excelValue(parsed);
    return value;
  }
  if (value is Map) return value.isEmpty ? '-' : value.entries.map((e) => '${e.key}: ${_excelValue(e.value)}').join('\n');
  if (value is List) return value.isEmpty ? '-' : value.asMap().entries.map((e) =>
    e.value is Map || e.value is List ? 'Item ${e.key + 1}\n${_excelValue(e.value)}' : _excelValue(e.value)).join('\n\n');
  return '$value';
}

// Parses legacy audit dictionaries without evaluating executable expressions.
class _LooseValueParser {
  final String source;
  int offset = 0;
  _LooseValueParser(this.source);
  void _space() { while (offset < source.length && source[offset].trim().isEmpty) { offset++; } }
  dynamic parse() { final value = _value(); _space(); if (offset != source.length) throw const FormatException(); return value; }
  dynamic _value() {
    _space();
    if (offset >= source.length) throw const FormatException();
    final c = source[offset];
    if (c == '"' || c == "'") return _string();
    if (c == '{') {
      offset++; final map = <String, dynamic>{}; _space();
      if (offset < source.length && source[offset] == '}') { offset++; return map; }
      while (true) {
        _space();
        final key = source[offset] == '"' || source[offset] == "'" ? _string() : _token();
        _space(); if (offset >= source.length || source[offset++] != ':') throw const FormatException();
        map[key] = _value(); _space();
        if (offset >= source.length) throw const FormatException();
        if (source[offset] == '}') { offset++; return map; }
        if (source[offset++] != ',') throw const FormatException();
      }
    }
    if (c == '[') {
      offset++; final list = <dynamic>[]; _space();
      if (offset < source.length && source[offset] == ']') { offset++; return list; }
      while (true) {
        list.add(_value()); _space();
        if (offset >= source.length) throw const FormatException();
        if (source[offset] == ']') { offset++; return list; }
        if (source[offset++] != ',') throw const FormatException();
      }
    }
    final token = _token();
    if (token == 'true' || token == 'True') return true;
    if (token == 'false' || token == 'False') return false;
    if (token == 'null' || token == 'None') return null;
    final number = num.tryParse(token);
    if (number != null) return number;
    throw const FormatException();
  }
  String _token() {
    _space(); final start = offset;
    while (offset < source.length && !':,}]'.contains(source[offset])) { offset++; }
    final token = source.substring(start, offset).trim();
    if (token.isEmpty) throw const FormatException();
    return token;
  }
  String _string() {
    final quote = source[offset++]; final result = StringBuffer();
    while (offset < source.length) {
      final c = source[offset++]; if (c == quote) return result.toString();
      if (c != '\\') { result.write(c); continue; }
      if (offset >= source.length) throw const FormatException();
      final escape = source[offset++];
      if (escape == 'u') {
        if (offset + 4 > source.length) throw const FormatException();
        result.writeCharCode(int.parse(source.substring(offset, offset + 4), radix: 16)); offset += 4;
      } else {
        result.write({'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f'}[escape] ?? escape);
      }
    }
    throw const FormatException();
  }
}

class _LogStaffPicker extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String) fetch;
  const _LogStaffPicker({required this.fetch});
  @override
  State<_LogStaffPicker> createState() => _LogStaffPickerState();
}

class _LogStaffPickerState extends State<_LogStaffPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  @override
  void initState() { super.initState(); _load(''); }
  @override
  void dispose() { _request++; _debounce?.cancel(); _controller.dispose(); super.dispose(); }
  void _changed(String query) {
    _debounce?.cancel();
    _request++;
    setState(() { _loading = true; _error = null; _rows = []; });
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(query.trim()));
  }
  Future<void> _load(String query) async {
    final request = ++_request;
    try {
      final rows = await widget.fetch(query);
      if (mounted && request == _request) setState(() => _rows = rows);
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error is _LogException ? error.message : 'Unable to search staff. Please retry.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: SizedBox(width: 440, height: MediaQuery.sizeOf(context).height * .6,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [const Expanded(child: Text('Staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Close', icon: const Icon(Icons.close))]),
        TextField(controller: _controller, onChanged: _changed,
          decoration: InputDecoration(hintText: 'Search staff...', prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        ListTile(title: const Text('All staff'), onTap: () => Navigator.pop(context, <String, dynamic>{'id': null})),
        const Divider(height: 1),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: () => _changed(_controller.text), child: const Text('Retry')),
            ]))
          : _rows.isEmpty ? const Center(child: Text('No staff found'))
          : ListView.separated(itemCount: _rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final staff = _rows[index];
                final description = [staff['eid'], staff['designation']]
                    .where((v) => v != null && '$v'.trim().isNotEmpty).join(' • ');
                return ListTile(title: Text('${staff['name'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  subtitle: Text(description, style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(context, staff));
              })),
      ])),
    ),
  );
}

// OOXML is emitted explicitly so the React workbook's merges, exact colors,
// widths, row heights, filters and freeze panes do not depend on excel package
// version-specific styling APIs. The result is a standard .xlsx ZIP workbook.
class _AuditWorkbook {
  static String _xml(String value) => value
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&apos;');

  static String _column(int index) {
    var value = index + 1;
    var result = '';
    while (value > 0) {
      value--;
      result = String.fromCharCode(65 + value % 26) + result;
      value ~/= 26;
    }
    return result;
  }

  static String _cell(int row, int col, dynamic value, int style) {
    final ref = '${_column(col)}${row + 1}';
    if (value is num) return '<c r="$ref" s="$style"><v>$value</v></c>';
    final text = value?.toString() ?? '';
    if (text.length > 32767) {
      throw const _LogException('An audit field exceeds Excel\'s 32,767-character cell limit. Narrow the export or shorten that field before exporting.');
    }
    return '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_xml(text)}</t></is></c>';
  }

  static double _height(dynamic value, int width) {
    if (value == null || '$value'.trim().isEmpty) return 28;
    final lines = '$value'.split('\n').fold<int>(0,
      (sum, line) => sum + math.max(1, (math.max(line.length, 1) / width).ceil()));
    return math.min(409, math.max(30, lines * 15)).toDouble();
  }

  static Future<Uint8List> build(List<Map<String, dynamic>> logs) async {
    final details = <List<dynamic>>[];
    final staffCounts = <String, int>{};
    final dateCounts = <String, int>{};
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final before = _normal(log['before_data']);
      final after = _normal(log['after_data']);
      final beforeMap = before is Map ? before : <String, dynamic>{};
      final afterMap = after is Map ? after : <String, dynamic>{};
      final keys = {...beforeMap.keys, ...afterMap.keys}.toList();
      final staff = (log['user_name']?.toString().isNotEmpty ?? false) ? '${log['user_name']}' : '-';
      final invoice = (log['order_name']?.toString().isNotEmpty ?? false) ? '${log['order_name']}' : '-';
      final date = _dateTime(log['created_at']);
      if (keys.isEmpty) {
        details.add([i + 1, staff, invoice, 'Value', _excelValue(before), _excelValue(after), date]);
      } else {
        for (var j = 0; j < keys.length; j++) {
          final key = keys[j];
          details.add([
            j == 0 ? i + 1 : '', j == 0 ? staff : '', j == 0 ? invoice : '', '$key',
            _excelValue(beforeMap.containsKey(key) ? beforeMap[key] : '-'),
            _excelValue(afterMap.containsKey(key) ? afterMap[key] : '-'), j == 0 ? date : '',
          ]);
        }
      }
      final staffKey = staff == '-' ? 'Unknown' : staff;
      staffCounts.update(staffKey, (n) => n + 1, ifAbsent: () => 1);
      final parsedDate = DateTime.tryParse('${log['created_at']}')?.toLocal();
      final dateKey = parsedDate == null ? 'Invalid' : DateFormat('yyyy-MM-dd').format(parsedDate);
      dateCounts.update(dateKey, (n) => n + 1, ifAbsent: () => 1);
      if (i % 100 == 0) await Future<void>.delayed(Duration.zero);
    }
    if (details.length + 5 > 1048576) {
      throw const _LogException('The export exceeds Excel\'s row limit. Select a smaller date range.');
    }
    final rows = <List<dynamic>>[
      ['Data Log Details', '', '', '', '', '', ''],
      ['Complete audit table with all before and after fields', '', '', '', '', '', ''],
      ['Total Logs: ${logs.length}', '', 'Total Detail Rows: ${details.length}', '', 'Exported: ${_dateTime(DateTime.now().toIso8601String())}', '', ''],
      [],
      ['#', 'Staff', 'Invoice', 'Field', 'Old Data', 'Changed To', 'Date & Time'],
      ...details,
    ];
    final mainSheet = _sheet(rows, [8, 24, 18, 28, 65, 65, 24],
      merges: ['A1:G1', 'A2:G2', 'A3:B3', 'C3:D3', 'E3:G3'], freeze: 5, filterRow: 4,
      style: (r, c) {
        if (r == 0) return 1;
        if (r == 1) return 2;
        if (r == 2) return 3;
        if (r == 3) return 0;
        if (r == 4) return c == 3 ? 5 : c == 4 ? 6 : c == 5 ? 7 : 4;
        return [8, 9, 10, 11, 12, 13, 14][c];
      },
      height: (r) {
        if (r < 5) return [30.0, 24.0, 26.0, 8.0, 30.0][r];
        final values = rows[r];
        return [_height(values[3], 28), _height(values[4], 65), _height(values[5], 65), 30.0]
            .reduce((a, b) => math.max(a, b));
      });
    final dates = dateCounts.keys.toList()..sort();
    final staffSheet = _summary('Summary by Staff', 'Log count grouped by staff for complete filtered data',
      ['Staff', 'Log Count'], staffCounts.entries.map((e) => <dynamic>[e.key, e.value]).toList());
    final dateSheet = _summary('Summary by Date', 'Log count grouped by date for complete filtered data',
      ['Date', 'Log Count'], dates.map((date) => <dynamic>[date, dateCounts[date]]).toList());
    final files = <String, String>{
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
          '${List.generate(3, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}'
          '</Types>',
      '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '</Relationships>',
      'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<bookViews><workbookView activeTab="0"/></bookViews><sheets>'
          '<sheet name="Data Log Details" sheetId="1" r:id="rId1"/>'
          '<sheet name="Summary by Staff" sheetId="2" r:id="rId2"/>'
          '<sheet name="Summary by Date" sheetId="3" r:id="rId3"/>'
          '</sheets></workbook>',
      'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '${List.generate(3, (i) => '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join()}'
          '<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
          '</Relationships>',
      'xl/styles.xml': _styles(),
      'xl/worksheets/sheet1.xml': mainSheet,
      'xl/worksheets/sheet2.xml': staffSheet,
      'xl/worksheets/sheet3.xml': dateSheet,
    };
    return _zip(files);
  }

  static String _summary(String title, String subtitle, List<String> headers, List<List<dynamic>> data) {
    final rows = <List<dynamic>>[[title, ''], [subtitle, ''], [], headers, ...data];
    return _sheet(rows, [28, 28], merges: ['A1:B1', 'A2:B2'], freeze: 4, filterRow: 3,
      style: (r, c) => r == 0 ? 1 : r == 1 ? 2 : r == 2 ? 0 : r == 3 ? 4 : 15,
      height: (r) => r == 0 || r == 3 ? 30 : r == 2 ? 8 : 24);
  }

  static String _sheet(List<List<dynamic>> rows, List<int> widths, {
    required List<String> merges, required int freeze, required int filterRow,
    required int Function(int, int) style, required double Function(int) height,
  }) {
    final last = '${_column(widths.length - 1)}${rows.length}';
    final xml = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<dimension ref="A1:$last"/><sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="$freeze" topLeftCell="A${freeze + 1}" activePane="bottomLeft" state="frozen"/>'
      '<selection pane="bottomLeft" activeCell="A${freeze + 1}" sqref="A${freeze + 1}"/>'
      '</sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols>');
    for (var c = 0; c < widths.length; c++) {
      xml.write('<col min="${c + 1}" max="${c + 1}" width="${widths[c]}" customWidth="1"/>');
    }
    xml.write('</cols><sheetData>');
    for (var r = 0; r < rows.length; r++) {
      xml.write('<row r="${r + 1}" ht="${height(r)}" customHeight="1">');
      for (var c = 0; c < widths.length; c++) {
        xml.write(_cell(r, c, c < rows[r].length ? rows[r][c] : '', style(r, c)));
      }
      xml.write('</row>');
    }
    xml.write('</sheetData><autoFilter ref="A${filterRow + 1}:$last"/>'
      '<mergeCells count="${merges.length}">');
    for (final merge in merges) { xml.write('<mergeCell ref="$merge"/>'); }
    xml.write('</mergeCells><pageMargins left="0.25" right="0.25" top="0.5" bottom="0.5" header="0.3" footer="0.3"/></worksheet>');
    return xml.toString();
  }

  static String _styles() {
    const fonts = <List<dynamic>>[
      [10, '0F172A', false], [18, '111827', true], [11, '475569', true],
      [12, 'FFFFFF', true], [11, '1E293B', true], [11, '1D4ED8', true],
      [11, '991B1B', true], [11, '166534', true], [10, '334155', true],
      [10, '1D4ED8', true], [10, '0F172A', true], [10, '991B1B', true],
      [10, '166534', true],
    ];
    const fills = ['EAF0FB', 'F3F6FB', '1D4ED8', 'DBEAFE', 'FEE2E2', 'DCFCE7', 'F1F5F9', 'EFF6FF', 'FFF7F7', 'F0FDF4', 'F8FAFC'];
    // font, fill index (0 means no fill), alignment, border flag
    const styles = <List<dynamic>>[
      [0, 0, '', false], [1, 2, 'center', true], [2, 3, 'center', true],
      [3, 4, 'center', true], [4, 2, 'center', true], [5, 5, 'center', true],
      [6, 6, 'center', true], [7, 7, 'center', true], [8, 0, 'topCenter', true],
      [9, 5, 'top', true], [10, 8, 'topCenter', true], [9, 9, 'top', true],
      [11, 10, 'top', true], [12, 11, 'top', true], [8, 12, 'topCenter', true],
      [10, 0, 'top', true],
    ];
    final xml = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="${fonts.length}">');
    for (final font in fonts) {
      xml.write('<font>${font[2] == true ? '<b/>' : ''}<sz val="${font[0]}"/><color rgb="FF${font[1]}"/><name val="Calibri"/><family val="2"/></font>');
    }
    xml.write('</fonts><fills count="${fills.length + 2}"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>');
    for (final color in fills) { xml.write('<fill><patternFill patternType="solid"><fgColor rgb="FF$color"/><bgColor indexed="64"/></patternFill></fill>'); }
    xml.write('</fills><borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border>');
    for (final side in ['left', 'right', 'top', 'bottom']) { xml.write('<$side style="thin"><color rgb="FFCBD5E1"/></$side>'); }
    xml.write('<diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="${styles.length}">');
    for (final style in styles) {
      final align = style[2] as String;
      xml.write('<xf numFmtId="0" fontId="${style[0]}" fillId="${style[1]}" borderId="${style[3] == true ? 1 : 0}" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
        '<alignment vertical="${align == 'center' ? 'center' : 'top'}"${align == 'center' || align == 'topCenter' ? ' horizontal="center"' : ''} wrapText="1"/>'
        '</xf>');
    }
    xml.write('</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>');
    return xml.toString();
  }

  // Minimal ZIP writer using native raw DEFLATE. No additional dependency needed.
  static Uint8List _zip(Map<String, String> files) {
    final output = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    var offset = 0;
    final now = DateTime.now();
    final time = (now.hour << 11) | (now.minute << 5) | (now.second ~/ 2);
    final date = ((now.year - 1980) << 9) | (now.month << 5) | now.day;
    void word(BytesBuilder builder, int value) {
      final data = ByteData(2)..setUint16(0, value, Endian.little); builder.add(data.buffer.asUint8List());
    }
    void dword(BytesBuilder builder, int value) {
      final data = ByteData(4)..setUint32(0, value, Endian.little); builder.add(data.buffer.asUint8List());
    }
    for (final file in files.entries) {
      final name = utf8.encode(file.key), bytes = utf8.encode(file.value);
      final compressed = ZLibEncoder(raw: true).convert(bytes);
      final crc = _crc(bytes);
      final local = BytesBuilder(copy: false);
      dword(local, 0x04034b50); word(local, 20); word(local, 0x800); word(local, 8);
      word(local, time); word(local, date); dword(local, crc);
      dword(local, compressed.length); dword(local, bytes.length); word(local, name.length); word(local, 0);
      local.add(name); local.add(compressed);
      final localBytes = local.takeBytes(); output.add(localBytes);
      dword(central, 0x02014b50); word(central, 20); word(central, 20); word(central, 0x800); word(central, 8);
      word(central, time); word(central, date); dword(central, crc);
      dword(central, compressed.length); dword(central, bytes.length); word(central, name.length);
      word(central, 0); word(central, 0); word(central, 0); word(central, 0); dword(central, 0); dword(central, offset);
      central.add(name); offset += localBytes.length;
      if (offset > 0xFFFFFFFF) throw const _LogException('Workbook is too large. Select a smaller date range.');
    }
    final directory = central.takeBytes(); output.add(directory);
    dword(output, 0x06054b50); word(output, 0); word(output, 0); word(output, files.length); word(output, files.length);
    dword(output, directory.length); dword(output, offset); word(output, 0);
    return output.takeBytes();
  }

  static int _crc(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >>> 1) ^ 0xEDB88320 : crc >>> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
