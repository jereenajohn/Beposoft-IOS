import 'dart:convert';

import 'package:beposoft/pages/ADMIN/family_invoice_details_page.dart';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DivisionWiseInvoicesPage extends StatefulWidget {
  const DivisionWiseInvoicesPage({super.key});

  @override
  State<DivisionWiseInvoicesPage> createState() =>
      _DivisionWiseInvoicesPageState();
}

class _DivisionWiseInvoicesPageState
    extends State<DivisionWiseInvoicesPage> {
  static const Color _primaryBlue = Color(0xFF2F7CFF);
  static const Color _secondaryBlue = Color(0xFF55B5FF);
  static const Color _deepBlue = Color(0xFF175CD3);
  static const Color _green = Color(0xFF16A34A);

  static const Color _backgroundColor = Color(0xFFF5F7FB);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF172033);
  static const Color _textSecondary = Color(0xFF667085);
  static const Color _borderColor = Color(0xFFE7ECF3);

  static const LinearGradient _dashboardBlueGradient =
      LinearGradient(
    colors: [
      _secondaryBlue,
      _primaryBlue,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool isLoading = true;
  String? errorMessage;

  DateTimeRange? selectedDateRange;

  int totalOrders = 0;

  List<Map<String, dynamic>> hourlyOrders = [];
  List<Map<String, dynamic>> familyData = [];

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    selectedDateRange = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      end: DateTime(
        now.year,
        now.month,
        now.day,
      ),
    );

    fetchDivisionWiseInvoices();
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (Map item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  String _formatHourRange(String hourRange) {
    final String value = hourRange.trim();

    if (value.isEmpty || value == '-') {
      return value;
    }

    final List<String> parts =
        value.split('-');

    if (parts.length != 2) {
      return value;
    }

    return '${_formatSingleHour(parts[0])}'
        '-'
        '${_formatSingleHour(parts[1])}';
  }

  String _formatSingleHour(String time) {
    final String cleanTime = time.trim();

    final List<String> parts =
        cleanTime.split(':');

    if (parts.isEmpty) {
      return cleanTime;
    }

    final int? hour = int.tryParse(
      parts[0],
    );

    if (hour == null) {
      return cleanTime;
    }

    final String minutes =
        parts.length > 1
            ? parts[1]
            : '00';

    int displayHour;

    if (hour == 0) {
      displayHour = 12;
    } else if (hour > 12) {
      displayHour = hour - 12;
    } else {
      displayHour = hour;
    }

    return '$displayHour:$minutes';
  }

  Future<String?> getTokenFromPrefs() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    return prefs.getString('token');
  }

  Future<void> fetchDivisionWiseInvoices() async {
    if (selectedDateRange == null) {
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final String? token =
          await getTokenFromPrefs();

      if (token == null ||
          token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found',
        );
      }

      final String startDate =
          DateFormat(
        'yyyy-MM-dd',
      ).format(
        selectedDateRange!.start,
      );

      final String endDate =
          DateFormat(
        'yyyy-MM-dd',
      ).format(
        selectedDateRange!.end,
      );

      final Uri uri = Uri.parse(
        '$api/api/orders/hourly/summary/',
      ).replace(
        queryParameters: {
          'start_date': startDate,
          'end_date': endDate,
        },
      );

      debugPrint(
        '==========================================',
      );
      debugPrint(
        'DIVISION WISE INVOICES API',
      );
      debugPrint(
        'URL: $uri',
      );
      debugPrint(
        'START DATE: $startDate',
      );
      debugPrint(
        'END DATE: $endDate',
      );

      final http.Response response =
          await http.get(
        uri,
        headers: {
          'Authorization':
              'Bearer $token',
          'Content-Type':
              'application/json',
          'Accept':
              'application/json',
        },
      );

      debugPrint(
        'STATUS CODE: ${response.statusCode}',
      );
      debugPrint(
        'RESPONSE: ${response.body}',
      );
      debugPrint(
        '==========================================',
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Unable to load invoice summary '
          '(${response.statusCode})',
        );
      }

      final dynamic decoded =
          jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        throw Exception(
          'Invalid server response',
        );
      }

      final Map<String, dynamic>
          responseData =
          Map<String, dynamic>.from(
        decoded,
      );

      if ((responseData['status'] ?? '')
              .toString()
              .toLowerCase() !=
          'success') {
        throw Exception(
          responseData['message']
                  ?.toString() ??
              'Unable to load invoice summary',
        );
      }

      final Map<String, dynamic>
          summary = _asMap(
        responseData['summary'],
      );

      List<Map<String, dynamic>>
          parsedFamilies = _asMapList(
        responseData['data'],
      );

      parsedFamilies =
          parsedFamilies.where(
        (Map<String, dynamic> family) {
          final String familyName =
              (family['family_name'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          return familyName !=
              'fitness';
        },
      ).toList();

      parsedFamilies.sort(
        (
          Map<String, dynamic> a,
          Map<String, dynamic> b,
        ) {
          final int aTotal = _asInt(
            _asMap(
              a['summary'],
            )['total_orders'],
          );

          final int bTotal = _asInt(
            _asMap(
              b['summary'],
            )['total_orders'],
          );

          return bTotal.compareTo(
            aTotal,
          );
        },
      );

      final int visibleTotalOrders =
          parsedFamilies.fold<int>(
        0,
        (
          int total,
          Map<String, dynamic> family,
        ) {
          return total +
              _asInt(
                _asMap(
                  family['summary'],
                )['total_orders'],
              );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        totalOrders =
            visibleTotalOrders;

        hourlyOrders = _asMapList(
          summary['hourly_orders'],
        );

        familyData =
            parsedFamilies;

        isLoading = false;
        errorMessage = null;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'DivisionWiseInvoicesPage fetch error: $e',
      );

      debugPrint(
        'DivisionWiseInvoicesPage stack trace: '
        '$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;

        errorMessage =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime now =
        DateTime.now();

    final DateTimeRange initialRange =
        selectedDateRange ??
            DateTimeRange(
              start: DateTime(
                now.year,
                now.month,
                now.day,
              ),
              end: DateTime(
                now.year,
                now.month,
                now.day,
              ),
            );

    final DateTimeRange? pickedRange =
        await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year + 1,
        12,
        31,
      ),
      helpText:
          'Select Invoice Date Range',
      saveText: 'APPLY',
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data:
              Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary: _primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      selectedDateRange =
          DateTimeRange(
        start: DateTime(
          pickedRange.start.year,
          pickedRange.start.month,
          pickedRange.start.day,
        ),
        end: DateTime(
          pickedRange.end.year,
          pickedRange.end.month,
          pickedRange.end.day,
        ),
      );
    });

    await fetchDivisionWiseInvoices();
  }

  String get _dateRangeText {
    if (selectedDateRange == null) {
      return '';
    }

    final DateTime start =
        selectedDateRange!.start;
    final DateTime end =
        selectedDateRange!.end;

    final bool sameDay =
        start.year == end.year &&
            start.month == end.month &&
            start.day == end.day;

    if (sameDay) {
      return DateFormat(
        'dd MMM yyyy',
      ).format(
        start,
      );
    }

    return '${DateFormat('dd MMM yyyy').format(start)}'
        ' - '
        '${DateFormat('dd MMM yyyy').format(end)}';
  }

  int _familyTotalOrders(
    Map<String, dynamic> family,
  ) {
    final Map<String, dynamic> summary =
        _asMap(
      family['summary'],
    );

    return _asInt(
      summary['total_orders'],
    );
  }

  List<Map<String, dynamic>>
      _familyHourlyOrders(
    Map<String, dynamic> family,
  ) {
    final Map<String, dynamic> summary =
        _asMap(
      family['summary'],
    );

    return _asMapList(
      summary['hourly_orders'],
    );
  }

  int _activeHourCount(
    List<Map<String, dynamic>>
        hourlyData,
  ) {
    return hourlyData.where(
      (Map<String, dynamic> item) {
        return _asInt(
              item['orders'],
            ) >
            0;
      },
    ).length;
  }

  // ---------------------------------------------------------------------------
  // NEW NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openFamilyDetails(
    Map<String, dynamic> family,
  ) async {
    if (selectedDateRange == null) {
      return;
    }

    final int familyId =
        _asInt(
      family['family_id'] ??
          family['id'],
    );

    if (familyId <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open division. Family ID is missing.',
          ),
        ),
      );

      return;
    }

    final String familyName =
        (family['family_name'] ??
                'Division')
            .toString()
            .trim();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) {
          return FamilyInvoiceDetailsPage(
            familyId: familyId,
            familyName: familyName,
            startDate:
                selectedDateRange!.start,
            endDate:
                selectedDateRange!.end,
          );
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        30,
      ),
      children: [
        _buildShimmerBox(
          height: 190,
        ),
        const SizedBox(height: 28),
        _buildShimmerBox(
          height: 170,
        ),
        const SizedBox(height: 14),
        _buildShimmerBox(
          height: 170,
        ),
        const SizedBox(height: 14),
        _buildShimmerBox(
          height: 170,
        ),
      ],
    );
  }

  Widget _buildShimmerBox({
    required double height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(
              0.035,
            ),
            blurRadius: 16,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF0F4FA,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Container(
              width: 150,
              height: 14,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF0F4FA,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  20,
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              width: 90,
              height: 12,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF0F4FA,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Container(
          width: double.infinity,
          constraints:
              const BoxConstraints(
            maxWidth: 430,
          ),
          padding:
              const EdgeInsets.all(
            28,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              24,
            ),
            border: Border.all(
              color: _borderColor,
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration:
                    const BoxDecoration(
                  color: Color(
                    0xFFFFF1F1,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .cloud_off_rounded,
                  size: 32,
                  color: Color(
                    0xFFD92D20,
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Unable to load invoice data',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      _textPrimary,
                ),
              ),
              const SizedBox(
                height: 9,
              ),
              Text(
                errorMessage ??
                    'Something went wrong.',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color:
                      _textSecondary,
                ),
              ),
              const SizedBox(
                height: 22,
              ),
              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      fetchDivisionWiseInvoices,
                  icon:
                      const Icon(
                    Icons
                        .refresh_rounded,
                    size: 19,
                  ),
                  label:
                      const Text(
                    'Try Again',
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    elevation: 0,
                    backgroundColor:
                        _primaryBlue,
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 14,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSummaryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient:
            _dashboardBlueGradient,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue
                .withOpacity(
              0.20,
            ),
            blurRadius: 24,
            offset:
                const Offset(
              0,
              10,
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -45,
            child: Container(
              width: 150,
              height: 150,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(
                  0.07,
                ),
              ),
            ),
          ),
          Positioned(
            right: 35,
            bottom: -70,
            child: Container(
              width: 140,
              height: 140,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(
                  0.05,
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .white
                            .withOpacity(
                          0.17,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        border:
                            Border.all(
                          color: Colors
                              .white
                              .withOpacity(
                            0.24,
                          ),
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .receipt_long_rounded,
                        color:
                            Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Invoice Overview',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  18,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                          SizedBox(
                            height: 4,
                          ),
                          Text(
                            'Division-wise invoice performance',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFFE7F1FF,
                              ),
                              fontSize:
                                  11.5,
                              fontWeight:
                                  FontWeight
                                      .w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 24,
                ),
                const Text(
                  'TOTAL INVOICES',
                  style: TextStyle(
                    color: Color(
                      0xFFDDEBFF,
                    ),
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  NumberFormat
                      .decimalPattern(
                    'en_IN',
                  ).format(
                    totalOrders,
                  ),
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 38,
                    fontWeight:
                        FontWeight.w900,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(
                  height: 22,
                ),
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(
                      0.14,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                    border:
                        Border.all(
                      color: Colors
                          .white
                          .withOpacity(
                        0.22,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration:
                            BoxDecoration(
                          color: Colors
                              .white
                              .withOpacity(
                            0.14,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            9,
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .calendar_month_rounded,
                          color:
                              Colors.white,
                          size: 17,
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Selected Period',
                              style:
                                  TextStyle(
                                color:
                                    Color(
                                  0xFFDDEBFF,
                                ),
                                fontSize:
                                    9.5,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              _dateRangeText,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    12.5,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(
    Map<String, dynamic> family,
  ) {
    final String familyName =
        (family['family_name'] ??
                'Unknown Division')
            .toString()
            .trim();

    final int familyTotal =
        _familyTotalOrders(
      family,
    );

    final List<Map<String, dynamic>>
        familyHours =
        _familyHourlyOrders(
      family,
    );

    final List<Map<String, dynamic>>
        activeHours =
        familyHours.where(
      (Map<String, dynamic> item) {
        return _asInt(
              item['orders'],
            ) >
            0;
      },
    ).toList();

    final int activeHourCount =
        _activeHourCount(
      familyHours,
    );

    final double percentage =
        totalOrders <= 0
            ? 0.0
            : (familyTotal /
                    totalOrders)
                .clamp(
                0.0,
                1.0,
              );

    final String initial =
        familyName.isEmpty
            ? '?'
            : familyName
                .substring(
                  0,
                  1,
                )
                .toUpperCase();

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(
              0xFF101828,
            ).withOpacity(
              0.045,
            ),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          onTap: () {
            _openFamilyDetails(
              family,
            );
          },
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  16,
                  16,
                  16,
                  14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment:
                          Alignment.center,
                      decoration:
                          BoxDecoration(
                        gradient:
                            _dashboardBlueGradient,
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: Text(
                        initial,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 19,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 13,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  familyName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    color:
                                        _textPrimary,
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              const Icon(
                                Icons
                                    .arrow_forward_ios_rounded,
                                size: 13,
                                color:
                                    _textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .schedule_rounded,
                                size: 14,
                                color:
                                    _textSecondary,
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Text(
                                '$activeHourCount active hour'
                                '${activeHourCount == 1 ? '' : 's'}',
                                style:
                                    const TextStyle(
                                  color:
                                      _textSecondary,
                                  fontSize:
                                      11.5,
                                  fontWeight:
                                      FontWeight
                                          .w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFECFDF3,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFFBBEACB,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            NumberFormat
                                .decimalPattern(
                              'en_IN',
                            ).format(
                              familyTotal,
                            ),
                            style:
                                const TextStyle(
                              color: _green,
                              fontSize:
                                  18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          const Text(
                            'Invoices',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF15803D,
                              ),
                              fontSize:
                                  9,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: _borderColor,
              ),
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  16,
                  15,
                  16,
                  16,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Invoice Contribution',
                            style:
                                TextStyle(
                              color:
                                  _textSecondary,
                              fontSize:
                                  11.5,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFEEF5FF,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),
                          ),
                          child: Text(
                            totalOrders <= 0
                                ? '0.00%'
                                : '${(percentage * 100).toStringAsFixed(2)}%',
                            style:
                                const TextStyle(
                              color:
                                  _deepBlue,
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 9,
                    ),
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        100,
                      ),
                      child:
                          LinearProgressIndicator(
                        minHeight: 7,
                        value:
                            percentage,
                        backgroundColor:
                            const Color(
                          0xFFEDF1F7,
                        ),
                        valueColor:
                            const AlwaysStoppedAnimation<
                                Color>(
                          _primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFEEF5FF,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              9,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .schedule_rounded,
                            color:
                                _primaryBlue,
                            size: 17,
                          ),
                        ),
                        const SizedBox(
                          width: 9,
                        ),
                        const Expanded(
                          child: Text(
                            'Hourly Invoices',
                            style:
                                TextStyle(
                              color:
                                  _textPrimary,
                              fontSize:
                                  13,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
                        if (activeHours
                            .isNotEmpty)
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFF2F4F7,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                            child: Text(
                              '${activeHours.length}',
                              style:
                                  const TextStyle(
                                color:
                                    _textSecondary,
                                fontSize:
                                    10,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(
                      height: 11,
                    ),
                    if (activeHours
                        .isEmpty)
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF8FAFC,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            13,
                          ),
                          border:
                              Border.all(
                            color:
                                _borderColor,
                          ),
                        ),
                        child:
                            const Column(
                          children: [
                            Icon(
                              Icons
                                  .hourglass_empty_rounded,
                              size: 22,
                              color:
                                  Color(
                                0xFF98A2B3,
                              ),
                            ),
                            SizedBox(
                              height: 7,
                            ),
                            Text(
                              'No invoices recorded during this period.',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  TextStyle(
                                color:
                                    _textSecondary,
                                fontSize:
                                    11.5,
                                fontWeight:
                                    FontWeight
                                        .w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...activeHours
                          .map(
                        (
                          Map<String,
                                  dynamic>
                              item,
                        ) {
                          return _buildHourRow(
                            hour: item[
                                        'hour']
                                    ?.toString() ??
                                '-',
                            orders:
                                _asInt(
                              item[
                                  'orders'],
                            ),
                          );
                        },
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

  Widget _buildHourRow({
    required String hour,
    required int orders,
  }) {
    final String displayHour =
        _formatHourRange(
      hour,
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color:
            const Color(
          0xFFF8FAFC,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFEEF5FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
            child:
                const Icon(
              Icons
                  .access_time_rounded,
              size: 15,
              color:
                  _primaryBlue,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              displayHour,
              style:
                  const TextStyle(
                color:
                    _textPrimary,
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Container(
            constraints:
                const BoxConstraints(
              minWidth: 42,
            ),
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFEEF5FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                9,
              ),
            ),
            child: Text(
              NumberFormat
                  .decimalPattern(
                'en_IN',
              ).format(
                orders,
              ),
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    _deepBlue,
                fontSize: 12,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        top: 4,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child:
          const Column(
        children: [
          Icon(
            Icons
                .receipt_long_outlined,
            size: 29,
            color: _primaryBlue,
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            'No invoice data available',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  _textPrimary,
              fontSize: 15,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          SizedBox(
            height: 6,
          ),
          Text(
            'There are no invoices available for the selected date range.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  _textSecondary,
              fontSize: 11.5,
              height: 1.4,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (familyData.isEmpty) {
      return RefreshIndicator(
        color: _primaryBlue,
        onRefresh:
            fetchDivisionWiseInvoices,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets
                  .fromLTRB(
            16,
            18,
            16,
            30,
          ),
          children: [
            _buildTopSummaryCard(),
            const SizedBox(
              height: 24,
            ),
            _buildEmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primaryBlue,
      onRefresh:
          fetchDivisionWiseInvoices,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets
                .fromLTRB(
          16,
          18,
          16,
          30,
        ),
        children: [
          _buildTopSummaryCard(),
          const SizedBox(
            height: 28,
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFEEF5FF,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    11,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .dashboard_rounded,
                  color:
                      _primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Division Summary',
                      style:
                          TextStyle(
                        color:
                            _textPrimary,
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    SizedBox(
                      height: 2,
                    ),
                    Text(
                      'Invoice distribution by division',
                      style:
                          TextStyle(
                        color:
                            _textSecondary,
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight
                                .w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFEEF5FF,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFFD7E7FF,
                    ),
                  ),
                ),
                child: Text(
                  '${familyData.length} Divisions',
                  style:
                      const TextStyle(
                    color:
                        _deepBlue,
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
          ...familyData.map(
            (
              Map<String, dynamic>
                  family,
            ) {
              return _buildFamilyCard(
                family,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            Colors.white,
        foregroundColor:
            _textPrimary,
        surfaceTintColor:
            Colors.white,
        titleSpacing: 0,
        toolbarHeight: 64,
        iconTheme:
            const IconThemeData(
          color: _textPrimary,
        ),
        title:
            const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Division wise Invoices',
              style:
                  TextStyle(
                color:
                    _textPrimary,
                fontSize: 17,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            SizedBox(
              height: 2,
            ),
            Text(
              'Invoice performance overview',
              style:
                  TextStyle(
                color:
                    _textSecondary,
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 12,
            ),
            child: Material(
              color:
                  const Color(
                0xFFEEF5FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                onTap:
                    isLoading
                        ? null
                        : _selectDateRange,
                child:
                    const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons
                        .calendar_month_rounded,
                    color:
                        _primaryBlue,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom:
            const PreferredSize(
          preferredSize:
              Size.fromHeight(
            1,
          ),
          child: Divider(
            height: 1,
            thickness: 1,
            color:
                _borderColor,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? _buildLoadingView()
            : errorMessage != null
                ? _buildErrorView()
                : _buildContent(),
      ),
    );
  }
}