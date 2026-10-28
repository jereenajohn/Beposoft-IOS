import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beposoft/pages/ACCOUNTS/add_self_attendance.dart';
import 'package:beposoft/pages/ACCOUNTS/daily_goods_movement.dart';
import 'package:beposoft/pages/ACCOUNTS/mailboxpage..dart';
import 'package:beposoft/pages/ACCOUNTS/order_list.dart';
import 'package:beposoft/pages/ACCOUNTS/product_list.dart';
import 'package:beposoft/pages/ACCOUNTS/profilepage.dart';
import 'package:beposoft/pages/ADMIN/dgm_page.dart';
import 'package:beposoft/pages/ADMIN/family_date_summary_page.dart';
import 'package:beposoft/pages/api.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/auth_status_checker.dart';
import 'package:beposoft/pages/logout_hekper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OperationsExecutiveDashboard extends StatefulWidget {
  const OperationsExecutiveDashboard({Key? key}) : super(key: key);

  @override
  State<OperationsExecutiveDashboard> createState() =>
      _OperationsExecutiveDashboardState();
}

class _OperationsExecutiveDashboardState
    extends State<OperationsExecutiveDashboard> with WidgetsBindingObserver {
  static const _blue = Color(0xFF2C74FF);
  static const _gradient = LinearGradient(
    colors: [Color(0xFF56AFFF), _blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  final _client = http.Client();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _mailTimer;
  String _username = 'Guest';
  String _profileImage = '';
  String _query = '';
  bool _searchOpen = false;
  bool _summaryLoading = true;
  bool _summaryBusy = false;
  bool _mailBusy = false;
  String? _summaryError;
  int _totalBills = 0;
  double _totalAmount = 0;
  int _waitingApproval = 0;
  int _todayBills = 0;
  double _todayAmount = 0;
  int _unreadMail = 0;
  Map<String, String> myAttendanceByDate = {};
  bool isMyAttendanceLoading = true;
  bool myAttendanceFailed = false;
  bool _attendanceRequestBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchMyAttendanceDetails();
    _loadProfile();
    _fetchSummary();
    _fetchMailCount();
    _mailTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _fetchMailCount();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AuthStatusChecker.start(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mailTimer?.cancel();
    _client.close();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  int _integer(dynamic value) =>
      num.tryParse(value?.toString() ?? '')?.toInt() ?? 0;
  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.trim().isEmpty) {
      throw StateError('Please log in again.');
    }
    final uri = Uri.parse('$api$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    }).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Unable to load dashboard (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map)
      throw const FormatException('Invalid dashboard response.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _username = prefs.getString('username') ?? 'Guest');
      final response = await _get('/api/profile/');
      final data = _map(response['data']);
      if (!mounted) return;
      setState(() => _profileImage = data['image']?.toString() ?? '');
    } catch (error) {
      debugPrint('OPERATIONS PROFILE ERROR: $error');
    }
  }

  Future<void> _fetchSummary() async {
    if (!mounted || _summaryBusy) return;
    _summaryBusy = true;
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final response = await _get('/api/my/order/summary/');
      if (response['status'] != 'success' ||
          response['all_orders'] is! Map ||
          response['today_orders'] is! Map ||
          response['invoice_created'] is! Map) {
        throw const FormatException('Invalid order summary response.');
      }
      final all = _map(response['all_orders']);
      final today = _map(response['today_orders']);
      final waiting = _map(response['invoice_created']);
      if (!mounted) return;
      setState(() {
        _totalBills = _integer(all['count']);
        _totalAmount = _number(all['total_amount']);
        _waitingApproval = _integer(waiting['count']);
        _todayBills = _integer(today['count']);
        _todayAmount = _number(today['total_amount']);
      });
    } catch (error) {
      debugPrint('OPERATIONS SUMMARY ERROR: $error');
      if (mounted)
        setState(() => _summaryError = 'Unable to load order summary.');
    } finally {
      _summaryBusy = false;
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _fetchMailCount() async {
    if (!mounted || _mailBusy) return;
    _mailBusy = true;
    try {
      final response = await _get('/api/internal/mails/', query: {
        'type': 'inbox',
        'read_status': 'unread',
        'page': '1',
      });
      final results = _map(response['results']);
      final data = _map(response['data']);
      final count = response['unread_count'] ??
          results['unread_count'] ??
          data['unread_count'] ??
          response['count'] ??
          results['count'] ??
          data['count'];
      int unread;
      if (count != null) {
        unread = _integer(count);
      } else {
        final dynamic list = results['data'] ??
            data['data'] ??
            (response['results'] is List
                ? response['results']
                : response['data']);
        if (list is! List)
          throw const FormatException('Mail count is missing.');
        unread = list.where((item) {
          if (item is! Map) return false;
          if (item.containsKey('is_read')) return item['is_read'] != true;
          if (item.containsKey('read')) return item['read'] != true;
          return item['read_at'] == null ||
              item['read_at'].toString().trim().isEmpty;
        }).length;
      }
      if (mounted && unread != _unreadMail)
        setState(() => _unreadMail = unread);
    } catch (error) {
      debugPrint('OPERATIONS MAIL ERROR: $error');
    } finally {
      _mailBusy = false;
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _fetchSummary(),
      _fetchMailCount(),
      fetchMyAttendanceDetails(),
    ]);
  }

  Future<void> fetchMyAttendanceDetails() async {
    if (!mounted || _attendanceRequestBusy) return;
    _attendanceRequestBusy = true;
    setState(() {
      isMyAttendanceLoading = true;
      myAttendanceFailed = false;
    });
    try {
      final decoded = await _get('/api/staff/attendance/my/details/');
      if (decoded is! Map ||
          decoded['status'] != 'success' ||
          decoded['data'] is! List) {
        throw Exception('Invalid attendance response');
      }
      final statuses = <String, String>{};
      final newestIds = <String, int>{};
      for (final row in decoded['data'] as List) {
        if (row is! Map) throw Exception('Invalid attendance record');
        final date =
            DateTime.tryParse(row['attendance_date']?.toString() ?? '');
        if (date == null) continue;
        final key = DateFormat('yyyy-MM-dd').format(date);
        final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
        if (newestIds.containsKey(key) && newestIds[key]! >= id) continue;
        newestIds[key] = id;
        statuses[key] = row['status']?.toString().trim().toLowerCase() ?? '';
      }
      if (!mounted) return;
      setState(() => myAttendanceByDate = statuses);
    } catch (error) {
      debugPrint('MY ATTENDANCE ERROR: $error');
      if (mounted) setState(() => myAttendanceFailed = true);
    } finally {
      _attendanceRequestBusy = false;
      if (mounted) setState(() => isMyAttendanceLoading = false);
    }
  }

  Widget _buildMyAttendanceCalendarCard() {
    final now = DateTime.now();
    final month = DateFormat('MMM').format(now);
    final first = DateTime(now.year, now.month, 1);
    final days = DateTime(now.year, now.month + 1, 0).day;
    final offset = first.weekday - 1;
    final rows = ((offset + days) / 7).ceil();
    const sundayBlue = Color(0xFF134D99);
    const saturdayBlue = Color(0xFF91C9F2);
    const pink = Color(0xFFEB4899);
    Widget legend(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(color: Colors.black87, fontSize: 7)),
          ],
        );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF56AFFF), Color(0xFF2C74FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: () async {
            await _open(StaffSelfAttendanceScreen());
          },
          child: LayoutBuilder(builder: (context, constraints) {
            // A minimum design canvas keeps every label and all six calendar
            // rows inside the card, including on narrow screens.
            final designWidth =
                constraints.maxWidth < 220 ? 220.0 : constraints.maxWidth;
            final designHeight =
                constraints.maxHeight < 280 ? 280.0 : constraints.maxHeight;
            return FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('$month Attendance',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: const Color(0xFFBFDDFB),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(month,
                            style: const TextStyle(
                                color: Color(0xFF154776),
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    const SizedBox(height: 7),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            'Attendance tracking • ${DateFormat('MMMM yyyy').format(now)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500))),
                    const SizedBox(height: 10),
                    Expanded(
                        child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]),
                      padding: const EdgeInsets.all(8),
                      child: Column(children: [
                        const SizedBox(height: 5),
                        Row(
                            children: [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ]
                                .map((day) => Expanded(
                                    child: Center(
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(day,
                                                style: const TextStyle(
                                                    color: Color(0xFF355A7A),
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w700))))))
                                .toList()),
                        const SizedBox(height: 10),
                        Expanded(
                            child: isMyAttendanceLoading
                                ? const Center(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)))
                                : myAttendanceFailed
                                    ? Center(
                                        child: TextButton(
                                            onPressed: fetchMyAttendanceDetails,
                                            child:
                                                const Text('Retry attendance')))
                                    : Column(
                                        children: List.generate(
                                            rows,
                                            (week) => Expanded(
                                                  child: Row(
                                                      children: List.generate(7,
                                                          (column) {
                                                    final day = week * 7 +
                                                        column -
                                                        offset +
                                                        1;
                                                    final valid =
                                                        day >= 1 && day <= days;
                                                    final date = DateTime(
                                                        now.year,
                                                        now.month,
                                                        day);
                                                    final status = valid
                                                        ? myAttendanceByDate[
                                                            DateFormat(
                                                                    'yyyy-MM-dd')
                                                                .format(date)]
                                                        : null;
                                                    final today =
                                                        valid && day == now.day;
                                                    final absent =
                                                        status == 'absent';
                                                    final sunday = valid &&
                                                        date.weekday ==
                                                            DateTime.sunday;
                                                    final saturday = valid &&
                                                        date.weekday ==
                                                            DateTime.saturday;
                                                    final background = !valid
                                                        ? const Color(
                                                            0xFFF8F8F8)
                                                        : today
                                                            ? pink
                                                            : absent
                                                                ? Colors.black
                                                                : sunday
                                                                    ? sundayBlue
                                                                    : saturday
                                                                        ? saturdayBlue
                                                                        : Colors
                                                                            .white;
                                                    final foreground = today ||
                                                            absent ||
                                                            sunday
                                                        ? Colors.white
                                                        : saturday
                                                            ? sundayBlue
                                                            : Colors.black;
                                                    return Expanded(
                                                        child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      child: Tooltip(
                                                        message: valid
                                                            ? '${DateFormat('dd MMM yyyy').format(date)}: ${status ?? 'No attendance record'}'
                                                            : '',
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration: BoxDecoration(
                                                              color: background,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          7),
                                                              border: Border.all(
                                                                  color: const Color(
                                                                      0xFFF0F0F0),
                                                                  width: 0.5),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                    color: Colors
                                                                        .black
                                                                        .withOpacity(valid
                                                                            ? 0.14
                                                                            : 0.04),
                                                                    blurRadius:
                                                                        3,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            2))
                                                              ]),
                                                          child: valid
                                                              ? FittedBox(
                                                                  fit: BoxFit
                                                                      .scaleDown,
                                                                  child: Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .all(
                                                                              2),
                                                                      child: Text(
                                                                          '$day',
                                                                          style: TextStyle(
                                                                              color: foreground,
                                                                              fontSize: 17,
                                                                              fontWeight: FontWeight.w800))))
                                                              : null,
                                                        ),
                                                      ),
                                                    ));
                                                  })),
                                                )))),
                        const SizedBox(height: 12),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(children: [
                              legend(Colors.black, 'Absent'),
                              const SizedBox(width: 9),
                              legend(pink, 'Today'),
                              const SizedBox(width: 9),
                              legend(saturdayBlue, 'Saturday'),
                              const SizedBox(width: 9),
                              legend(sundayBlue, 'Sunday'),
                            ])),
                        const SizedBox(height: 4),
                      ]),
                    )),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _compact(double amount) {
    final value = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (value >= 10000000)
      return '$sign${(value / 10000000).toStringAsFixed(2)} Cr';
    if (value >= 100000) return '$sign${(value / 100000).toStringAsFixed(2)} L';
    if (value >= 1000) return '$sign${(value / 1000).toStringAsFixed(2)} K';
    return amount.toStringAsFixed(2);
  }

  Future<void> _open(Widget page) async {
    _searchFocus.unfocus();
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _refresh();
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _blue.withOpacity(.28),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 6))
        ],
      );

  Widget _info(String value, String label) => Column(children: [
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold))),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ]);

  Widget _summaryCard() {
    String display(String value) => _summaryLoading
        ? '...'
        : _summaryError != null
            ? '--'
            : value;
    return Container(
      width: double.infinity,
      decoration: _cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _info(display('$_totalBills'), 'Total Bills')),
          const SizedBox(width: 6),
          Expanded(
              child: _info(display(_compact(_totalAmount)), 'Total Volume')),
          const SizedBox(width: 6),
          Expanded(
              child:
                  _info(display('$_waitingApproval'), 'Waiting For Approval')),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _info(display('$_todayBills'), 'Today Bills')),
          const SizedBox(width: 6),
          Expanded(
              child: _info(display(_compact(_todayAmount)), 'Today Volume')),
          const SizedBox(width: 6),
          const Expanded(child: SizedBox()),
        ]),
        if (_summaryError != null) ...[
          const SizedBox(height: 8),
          TextButton(
              onPressed: _fetchSummary,
              child: const Text('Unable to load summary. Retry',
                  style: TextStyle(color: Colors.white))),
        ],
      ]),
    );
  }

  List<_OperationsCard> get _cards => [
        _OperationsCard('Attendance', 'Employee attendance & time',
            Icons.event_available_rounded, () => StaffSelfAttendanceScreen()),
        _OperationsCard(
            'Sales',
            'Manage sales orders & invoices',
            Icons.trending_up_rounded,
            () => OrderList(
                  status: null,
                )),
        _OperationsCard('Logistics (DGM)', 'Track shipments & delivery',
            Icons.local_shipping_rounded, () => daily_goods_movementt()),
        _OperationsCard('Inventory', 'Stock & warehouse overview',
            Icons.inventory_2_rounded, () => Product_List()),
        _OperationsCard('Reports', 'Analytics, exports & summaries',
            Icons.analytics_outlined, () => const OperationsReportsPage()),
      ];

  Widget _menuCard(_OperationsCard card) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(card.page()),
          child: Ink(
            decoration: _cardDecoration,
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 170;
              return Stack(children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                width: compact ? 78 : 94,
                                height: compact ? 78 : 94,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(.20),
                                ),
                                child: Icon(card.icon,
                                    size: compact ? 42 : 50,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            card.title,
                            maxLines: 1,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 16 : 19,
                                height: 1.15,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            card.subtitle,
                            maxLines: 1,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 13 : 15,
                                height: 1.4,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(.23)),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ]);
            }),
          ),
        ),
      );

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _query = '';
        _searchController.clear();
      }
    });
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    } else {
      _searchFocus.unfocus();
    }
  }

    Widget _buildDropdownTile(
        BuildContext context, String title, List<String> options) {
      return ExpansionTile(
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        iconColor: Colors.black,
        collapsedIconColor: Colors.black,
        title: Text(
          title,
          style: const TextStyle(color: Colors.black),
        ),
        children: options.map((option) {
          return ListTile(
            tileColor: Colors.white,
            title: Text(
              option,
              style: const TextStyle(color: Colors.black),
            ),
            onTap: () {
              Navigator.pop(context);
              drower().navigateToSelectedPage(context, option);
            },
          );
        }).toList(),
      );
    }

  Widget _operationsDrawer() => Drawer(
    backgroundColor: Colors.white,
    child: Container(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('lib/assets/appstore.png',
                    width: 90, height: 90, fit: BoxFit.cover),
                ),
              ],
            ),
          ),
_buildDropdownTile(context, 'Proforma Invoice', [
                    // 'New Proforma Invoice',
                    'Proforma Invoice List',
                    'Proforma Invoice List (Payment-Slips)',
                  ]),
_buildDropdownTile(
                    context,
                    'Delivery Note',
                    [
                      'Delivery Order (DO)',
                      'Delivery Order(Printed)',
                      'Delivery Order(Pending For Packing)',
                      'Packed For Delivery(PFD)',
                      'Out For Delivery(OFD)',
                      'Return From Delivery (RFD)',
                      'Delivery Order(Shipped)',
                      'Daily Goods Movement',
                    ],
                  ),
_buildDropdownTile(context, 'Orders', [
                    // 'New Orders',
                    'Orders List',
                    'Waiting For Approval',
                    'Invoice Approved',
                    'Pre Booked',
                    'Waiting For Confirmation',
                    'DO(Delivery Order)',
                    'Printed',
                    'Pending For Packing',
                    'PFD (Packed For Delivery)',
                    'OFD (Out For Delivery)',
                    'Return From Delivery',
                    'Shipped',
                    'Invoice Rejected'
                  ]),
_buildDropdownTile(
                      context, 'GRV', [
                        // 'Create New GRV', 
                        'GRVs List']),
        ],
      ),
    ),
  );

  Widget _bottomItem(IconData icon, String label, VoidCallback action,
      {bool selected = false, int count = 0}) {
    final color = selected ? _blue : const Color(0xFF6B7280);
    return Expanded(
        child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
          height: 54,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                  width: 36,
                  height: 32,
                  decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEAF2FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 23)),
              if (count > 0)
                Positioned(
                    right: -7,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1.5)),
                      child: Text(count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    )),
            ]),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ])),
    ));
  }

  Widget _bottomNavigation() => Material(
        color: Colors.white,
        elevation: 14,
        shadowColor: Colors.black.withOpacity(.10),
        child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(children: [
                    _bottomItem(Icons.person_outline_rounded, 'Profile',
                        () => _open(EditProfileScreen())),
                    _bottomItem(Icons.mail_outline_rounded, 'Mail',
                        () => _open(const StaffMailPage()),
                        count: _unreadMail),
                    _bottomItem(Icons.search_rounded, 'Search', _toggleSearch,
                        selected: _searchOpen),
                  ])),
              if (_searchOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search cards',
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.cancel_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              }),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                ),
            ])),
      );

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final cards = _cards
        .where((card) =>
            '${card.title} ${card.subtitle}'.toLowerCase().contains(query))
        .toList();
    final image = _profileImage.trim();
    final imageUrl = image.isEmpty
        ? ''
        : image.startsWith('http')
            ? image
            : '$api$image';
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (drawerContext) => IconButton(
            tooltip: MaterialLocalizations.of(drawerContext).openAppDrawerTooltip,
            icon: const Icon(Icons.menu),
            onPressed: () {
              _searchFocus.unfocus();
              Scaffold.of(drawerContext).openDrawer();
            },
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, size: 27),
            onPressed: () async => await logoutUser(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _operationsDrawer(),
      bottomNavigationBar: _bottomNavigation(),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    GestureDetector(
                        onTap: () => _open(EditProfileScreen()),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : const AssetImage('lib/assets/female.jpeg')
                                  as ImageProvider,
                        )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(_username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold))),
                  ]),
                  // const SizedBox(height: 10),
                  // _summaryCard(),
                  const SizedBox(height: 16),
                  if (cards.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text('No cards found.')))
                  else
                    LayoutBuilder(builder: (context, constraints) {
                      const columns = 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 185),
                        itemBuilder: (_, index) =>
                            cards[index].title == 'Attendance'
                                ? _buildMyAttendanceCalendarCard()
                                : _menuCard(cards[index]),
                      );
                    }),
                  const SizedBox(height: 12),
                ],
              ))),
    );
  }
}

class _OperationsCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() page;
  const _OperationsCard(this.title, this.subtitle, this.icon, this.page);
}

class OperationsReportsPage extends StatelessWidget {
  const OperationsReportsPage({Key? key}) : super(key: key);

  static const _ink = Color(0xFF172B4D);
  static const _blue = Color(0xFF2C74FF);

  static const _reports = <String>[
    'Sales Report',
    'Sales Report Excel',
    'GST Report',
    'Tracking Report',
    'Credit Sales Report',
    'COD Sales Report',
    'Statewise Sales Report',
    'Expence Report',
    'Delivery Report',
    'Product Sale Report',
    'Stock Report',
    'Damaged Stock',
    'Finance Report',
    'Actual Delivery Report',
    'Order Comparison Report',
    'Product Usability Report',
    'Dispatched & Pending Orders Report',
  ];

  static const _icons = <IconData>[
    Icons.trending_up_rounded,
    Icons.table_chart_outlined,
    Icons.receipt_long_outlined,
    Icons.route_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.payments_outlined,
    Icons.map_outlined,
    Icons.money_off_rounded,
    Icons.local_shipping_outlined,
    Icons.shopping_bag_outlined,
    Icons.inventory_2_outlined,
    Icons.broken_image_outlined,
    Icons.account_balance_outlined,
    Icons.task_alt_rounded,
    Icons.compare_arrows_rounded,
    Icons.insights_rounded,
    Icons.pending_actions_rounded,
  ];

  Widget _reportTile(BuildContext context, int index) {
    final title = _reports[index];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17345C).withOpacity(.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => drower().navigateToSelectedPage(context, title),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icons[index], color: _blue, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .1,
                ),
              )),
              const SizedBox(width: 12),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF8798B0), size: 20),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('Reports',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFEBEFF5)),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            final sidePadding = constraints.maxWidth > 760
                ? (constraints.maxWidth - 720) / 2
                : 18.0;
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(sidePadding, 20, sidePadding, 24),
              itemCount: _reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: _reportTile,
            );
          }),
        ),
      );
}
