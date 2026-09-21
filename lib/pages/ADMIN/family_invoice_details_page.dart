import 'dart:convert';

import 'package:beposoft/pages/ACCOUNTS/order.review.dart';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyInvoiceDetailsPage extends StatefulWidget {
  final int familyId;
  final String familyName;
  final DateTime startDate;
  final DateTime endDate;

  const FamilyInvoiceDetailsPage({
    super.key,
    required this.familyId,
    required this.familyName,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<FamilyInvoiceDetailsPage> createState() =>
      _FamilyInvoiceDetailsPageState();
}

class _FamilyInvoiceDetailsPageState
    extends State<FamilyInvoiceDetailsPage> {
  // ---------------------------------------------------------------------------
  // COLORS
  // ---------------------------------------------------------------------------

  static const Color _primaryBlue = Color(0xFF2F7CFF);
  static const Color _secondaryBlue = Color(0xFF55B5FF);
  static const Color _deepBlue = Color(0xFF175CD3);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFD92D20);
  static const Color _orange = Color(0xFFF79009);

  static const Color _backgroundColor = Color(0xFFF5F7FB);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF172033);
  static const Color _textSecondary = Color(0xFF667085);
  static const Color _borderColor = Color(0xFFE7ECF3);

  static const LinearGradient _dashboardBlueGradient = LinearGradient(
    colors: [
      _secondaryBlue,
      _primaryBlue,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  bool isLoading = true;
  bool isPageLoading = false;
  bool isOpeningInvoice = false;

  String? errorMessage;

  String familyName = '';

  int totalOrders = 0;

  // NEW
  double totalAmount = 0.0;

  List<Map<String, dynamic>> hourlyOrders = [];
  List<Map<String, dynamic>> groupedData = [];
  List<Map<String, dynamic>> invoices = [];

  int totalCount = 0;
  int totalPages = 1;
  int currentPage = 1;
  int pageSize = 50;

  String? nextPage;
  String? previousPage;

  @override
  void initState() {
    super.initState();

    familyName = widget.familyName;

    fetchFamilyInvoices(
      page: 1,
    );
  }

  // ---------------------------------------------------------------------------
  // BASIC HELPERS
  // ---------------------------------------------------------------------------

  int _asInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  double _asDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
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
          (Map item) => Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  Future<String?> _getToken() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(
      'token',
    );
  }

  // ---------------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------------

  String get _dateRangeText {
    final bool sameDay =
        widget.startDate.year == widget.endDate.year &&
            widget.startDate.month == widget.endDate.month &&
            widget.startDate.day == widget.endDate.day;

    if (sameDay) {
      return DateFormat(
        'dd MMM yyyy',
      ).format(
        widget.startDate,
      );
    }

    return '${DateFormat('dd MMM yyyy').format(widget.startDate)}'
        ' - '
        '${DateFormat('dd MMM yyyy').format(widget.endDate)}';
  }

  // ---------------------------------------------------------------------------
  // MONEY FORMAT
  // ---------------------------------------------------------------------------

  String _formatAmount(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(
      amount,
    );
  }

  // ---------------------------------------------------------------------------
  // TIME FORMAT
  // ---------------------------------------------------------------------------

  String _formatHourRange(String hourRange) {
    final String value = hourRange.trim();

    if (value.isEmpty || value == '-') {
      return value;
    }

    final List<String> parts = value.split('-');

    if (parts.length != 2) {
      return value;
    }

    return '${_formatSingleHour(parts[0])}'
        '-'
        '${_formatSingleHour(parts[1])}';
  }

  String _formatSingleHour(String time) {
    final String cleanTime = time.trim();

    final List<String> parts = cleanTime.split(':');

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
        parts.length > 1 ? parts[1] : '00';

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

  String _formatCreatedTime(dynamic value) {
    if (value == null) {
      return '-';
    }

    try {
      final DateTime parsed = DateTime.parse(
        value.toString(),
      ).toLocal();

      return DateFormat(
        'dd MMM yyyy • h:mm a',
      ).format(
        parsed,
      );
    } catch (_) {
      return value.toString();
    }
  }

  // ---------------------------------------------------------------------------
  // STATUS DISPLAY
  // ---------------------------------------------------------------------------

  String _statusDisplayName(String status) {
    switch (status.trim()) {
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
        return 'Return From Delivery';

      default:
        return status;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status.trim()) {
      case 'Invoice Approved':
        return const Color(0xFFECFDF3);

      case 'Invoice Rejected':
        return const Color(0xFFFFF1F1);

      case 'Shipped':
        return const Color(0xFFECFDF3);

      case 'Ready to ship':
        return const Color(0xFFEEF5FF);

      case 'Packed':
        return const Color(0xFFFFF7E8);

      case 'Packing under progress':
        return const Color(0xFFEEF5FF);

      case 'To Print':
        return const Color(0xFFEEF5FF);

      default:
        return const Color(0xFFF2F4F7);
    }
  }

  Color _statusTextColor(String status) {
    switch (status.trim()) {
      case 'Invoice Approved':
        return _green;

      case 'Invoice Rejected':
        return _red;

      case 'Shipped':
        return _green;

      case 'Ready to ship':
        return _deepBlue;

      case 'Packed':
        return _orange;

      case 'Packing under progress':
        return _deepBlue;

      case 'To Print':
        return _deepBlue;

      default:
        return _textSecondary;
    }
  }

  // ---------------------------------------------------------------------------
  // FETCH FAMILY INVOICES
  // ---------------------------------------------------------------------------

  Future<void> fetchFamilyInvoices({
    required int page,
  }) async {
    if (page < 1) {
      return;
    }

    if (page == 1) {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isPageLoading = true;
          errorMessage = null;
        });
      }
    }

    try {
      final String? token = await _getToken();

      if (token == null || token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found',
        );
      }

      final String startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(
        widget.startDate,
      );

      final String endDate = DateFormat(
        'yyyy-MM-dd',
      ).format(
        widget.endDate,
      );

      final Uri uri = Uri.parse(
        '$api/api/orders/hourly/family/${widget.familyId}/',
      ).replace(
        queryParameters: {
          'start_date': startDate,
          'end_date': endDate,
          'page': page.toString(),
        },
      );

      debugPrint(
        '==========================================',
      );
      debugPrint(
        'FAMILY INVOICE DETAILS API',
      );
      debugPrint(
        'URL: $uri',
      );
      debugPrint(
        'FAMILY ID: ${widget.familyId}',
      );
      debugPrint(
        'PAGE: $page',
      );
      debugPrint(
        'START DATE: $startDate',
      );
      debugPrint(
        'END DATE: $endDate',
      );

      final http.Response response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
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
          'Unable to load family invoices '
          '(${response.statusCode})',
        );
      }

      final dynamic decoded = jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        throw Exception(
          'Invalid server response',
        );
      }

      final Map<String, dynamic> responseData =
          Map<String, dynamic>.from(
        decoded,
      );

      if ((responseData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase() !=
          'success') {
        throw Exception(
          responseData['message']?.toString() ??
              'Unable to load family invoices',
        );
      }

      final Map<String, dynamic> summary = _asMap(
        responseData['summary'],
      );

      final Map<String, dynamic> pagination = _asMap(
        responseData['pagination'],
      );

      final List<Map<String, dynamic>> parsedGroupedData =
          _asMapList(
        responseData['data'],
      );

      final List<Map<String, dynamic>> parsedInvoices =
          <Map<String, dynamic>>[];

      for (final Map<String, dynamic> group
          in parsedGroupedData) {
        final String hour =
            group['hour']?.toString() ?? '-';

        final List<Map<String, dynamic>> groupInvoices =
            _asMapList(
          group['data'],
        );

        for (final Map<String, dynamic> invoice
            in groupInvoices) {
          parsedInvoices.add(
            <String, dynamic>{
              ...invoice,
              '_hour': hour,
            },
          );
        }
      }

      // -----------------------------------------------------------------------
      // TOTAL AMOUNT
      //
      // Prefer backend summary total_amount because pagination means the
      // currently loaded invoice page may contain only part of the family data.
      // -----------------------------------------------------------------------

      double parsedTotalAmount = _asDouble(
        summary['total_amount'],
      );

      if (parsedTotalAmount == 0.0 &&
          responseData['total_amount'] != null) {
        parsedTotalAmount = _asDouble(
          responseData['total_amount'],
        );
      }

      // Fallback only when backend has not returned a total amount.
      if (parsedTotalAmount == 0.0 &&
          parsedInvoices.isNotEmpty &&
          _asInt(pagination['total_pages']) <= 1) {
        parsedTotalAmount =
            parsedInvoices.fold<double>(
          0.0,
          (
            double total,
            Map<String, dynamic> invoice,
          ) {
            return total +
                _asDouble(
                  invoice['amount'] ??
                      invoice['total_amount'],
                );
          },
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        familyName =
            (responseData['family_name'] ??
                    widget.familyName)
                .toString();

        totalOrders = _asInt(
          summary['total_orders'],
        );

        totalAmount = parsedTotalAmount;

        hourlyOrders = _asMapList(
          summary['hourly_orders'],
        );

        groupedData = parsedGroupedData;
        invoices = parsedInvoices;

        totalCount = _asInt(
          pagination['count'],
        );

        totalPages = _asInt(
          pagination['total_pages'],
        );

        if (totalPages <= 0) {
          totalPages = 1;
        }

        currentPage = _asInt(
          pagination['current_page'],
        );

        if (currentPage <= 0) {
          currentPage = page;
        }

        pageSize = _asInt(
          pagination['page_size'],
        );

        if (pageSize <= 0) {
          pageSize = 50;
        }

        nextPage = pagination['next']?.toString();
        previousPage =
            pagination['previous']?.toString();

        isLoading = false;
        isPageLoading = false;
        errorMessage = null;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'FamilyInvoiceDetailsPage error: $e',
      );

      debugPrint(
        'STACK TRACE: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        isPageLoading = false;

        errorMessage = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ---------------------------------------------------------------------------
  // OPEN ORDER REVIEW
  //
  // SAME FLOW USED BY StaffOrderSummaryPage
  // ---------------------------------------------------------------------------

  Future<void> openOrderReview(
    int orderId,
  ) async {
    if (orderId <= 0) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Invalid order ID.',
          ),
        ),
      );

      return;
    }

    if (isOpeningInvoice) {
      return;
    }

    setState(() {
      isOpeningInvoice = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (
        BuildContext dialogContext,
      ) {
        return const Center(
          child: CircularProgressIndicator(
            color: _primaryBlue,
          ),
        );
      },
    );

    bool dialogOpen = true;

    try {
      final String? token = await _getToken();

      if (token == null ||
          token.trim().isEmpty) {
        if (!mounted) {
          return;
        }

        if (dialogOpen) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pop();

          dialogOpen = false;
        }

        setState(() {
          isOpeningInvoice = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Authentication token not found.',
            ),
          ),
        );

        return;
      }

      final Uri url = Uri.parse(
        '$api/api/order/$orderId/items/',
      );

      debugPrint(
        '==========================================',
      );
      debugPrint(
        'OPEN FAMILY INVOICE',
      );
      debugPrint(
        'ORDER ID: $orderId',
      );
      debugPrint(
        'URL: $url',
      );

      final http.Response response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
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

      if (!mounted) {
        return;
      }

      if (dialogOpen) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop();

        dialogOpen = false;
      }

      if (response.statusCode != 200) {
        setState(() {
          isOpeningInvoice = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Unable to load order details. '
              'Status: ${response.statusCode}',
            ),
          ),
        );

        return;
      }

      final dynamic decoded = jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        setState(() {
          isOpeningInvoice = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Invalid order response.',
            ),
          ),
        );

        return;
      }

      final dynamic order = decoded['order'];

      if (order is! Map) {
        setState(() {
          isOpeningInvoice = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Order information not found.',
            ),
          ),
        );

        return;
      }

      final dynamic customer = order['customer'];

      if (customer is! Map) {
        setState(() {
          isOpeningInvoice = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Customer information not found.',
            ),
          ),
        );

        return;
      }

      final int customerId = _asInt(
        customer['id'],
      );

      if (customerId <= 0) {
        setState(() {
          isOpeningInvoice = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Invalid customer ID.',
            ),
          ),
        );

        return;
      }

      setState(() {
        isOpeningInvoice = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderReview(
            id: orderId,
            customer: customerId,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'OPEN FAMILY INVOICE ERROR: $error',
      );

      debugPrint(
        'OPEN FAMILY INVOICE STACK TRACE: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      if (dialogOpen &&
          Navigator.of(
            context,
            rootNavigator: true,
          ).canPop()) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop();

        dialogOpen = false;
      }

      setState(() {
        isOpeningInvoice = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Unable to open order details.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SUMMARY HELPERS
  // ---------------------------------------------------------------------------

  int get _activeHours {
    return hourlyOrders.where(
      (
        Map<String, dynamic> item,
      ) {
        return _asInt(
              item['orders'],
            ) >
            0;
      },
    ).length;
  }

  List<Map<String, dynamic>> get _activeHourlyOrders {
    return hourlyOrders.where(
      (
        Map<String, dynamic> item,
      ) {
        return _asInt(
              item['orders'],
            ) >
            0;
      },
    ).toList();
  }

  double get _currentPageAmount {
    return invoices.fold<double>(
      0,
      (
        double total,
        Map<String, dynamic> invoice,
      ) {
        return total +
            _asDouble(
              invoice['amount'] ??
                  invoice['total_amount'],
            );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------------

  Widget _buildLoadingView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        30,
      ),
      children: [
        _buildSkeleton(
          250,
        ),
        const SizedBox(
          height: 20,
        ),
        _buildSkeleton(
          120,
        ),
        const SizedBox(
          height: 14,
        ),
        _buildSkeleton(
          180,
        ),
        const SizedBox(
          height: 14,
        ),
        _buildSkeleton(
          180,
        ),
      ],
    );
  }

  Widget _buildSkeleton(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: _borderColor,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------------

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(
          24,
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            maxWidth: 430,
          ),
          padding: const EdgeInsets.all(
            28,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              24,
            ),
            border: Border.all(
              color: _borderColor,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _red,
                  size: 32,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              const Text(
                'Unable to load invoices',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                errorMessage ??
                    'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    fetchFamilyInvoices(
                      page: currentPage,
                    );
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text(
                    'Try Again',
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
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

  // ---------------------------------------------------------------------------
  // HERO CARD
  // ---------------------------------------------------------------------------

  Widget _buildHeroCard() {
    final String initial = familyName.trim().isEmpty
        ? '?'
        : familyName
            .trim()
            .substring(
              0,
              1,
            )
            .toUpperCase();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _dashboardBlueGradient,
        borderRadius: BorderRadius.circular(
          24,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(
              0.20,
            ),
            blurRadius: 24,
            offset: const Offset(
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
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(
                  0.07,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            right: 50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(
                  0.05,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              20,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                          0.18,
                        ),
                        borderRadius: BorderRadius.circular(
                          17,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(
                            0.24,
                          ),
                        ),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            familyName,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          const Text(
                            'Invoice performance details',
                            style: TextStyle(
                              color: Color(
                                0xFFE7F1FF,
                              ),
                              fontSize: 11.5,
                              fontWeight:
                                  FontWeight.w500,
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

                // -------------------------------------------------------------
                // TOTAL INVOICES + ACTIVE HOURS
                // -------------------------------------------------------------

                Row(
                  children: [
                    Expanded(
                      child: _buildHeroMetric(
                        title: 'TOTAL INVOICES',
                        value: NumberFormat
                            .decimalPattern(
                          'en_IN',
                        ).format(
                          totalOrders,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.white.withOpacity(
                        0.20,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(
                          left: 18,
                        ),
                        child: _buildHeroMetric(
                          title: 'ACTIVE HOURS',
                          value: '$_activeHours',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                // -------------------------------------------------------------
                // NEW TOTAL AMOUNT
                // -------------------------------------------------------------

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.14,
                    ),
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(
                        0.22,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            0.14,
                          ),
                          borderRadius: BorderRadius.circular(
                            9,
                          ),
                        ),
                        child: const Icon(
                          Icons.currency_rupee_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(
                        width: 11,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL AMOUNT',
                              style: TextStyle(
                                color: Color(
                                  0xFFDDEBFF,
                                ),
                                fontSize: 9.5,
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              _formatAmount(
                                totalAmount,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // -------------------------------------------------------------
                // SELECTED PERIOD
                // -------------------------------------------------------------

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.14,
                    ),
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(
                        0.22,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            0.14,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            9,
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Period',
                              style: TextStyle(
                                color: Color(
                                  0xFFDDEBFF,
                                ),
                                fontSize: 9.5,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              _dateRangeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight:
                                    FontWeight.w800,
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

  Widget _buildHeroMetric({
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFDDEBFF),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // QUICK SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildQuickSummary() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallSummaryCard(
            icon: Icons.receipt_long_rounded,
            title: 'Records',
            value: NumberFormat.decimalPattern(
              'en_IN',
            ).format(
              totalCount,
            ),
            iconColor: _primaryBlue,
            iconBackground:
                const Color(0xFFEEF5FF),
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: _buildSmallSummaryCard(
            icon: Icons.layers_rounded,
            title: 'Pages',
            value: NumberFormat.decimalPattern(
              'en_IN',
            ).format(
              totalPages,
            ),
            iconColor: _green,
            iconBackground:
                const Color(0xFFECFDF3),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      padding: const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828)
                .withOpacity(
              0.035,
            ),
            blurRadius: 14,
            offset: const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 19,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOURLY BREAKDOWN
  // ---------------------------------------------------------------------------

  Widget _buildHourlySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828)
                .withOpacity(
              0.04,
            ),
            blurRadius: 18,
            offset: const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEEF5FF),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: _primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hourly Performance',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(
                      height: 2,
                    ),
                    Text(
                      'Invoice distribution by hour',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEEF5FF),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  '$_activeHours active',
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
          if (_activeHourlyOrders.isEmpty)
            _buildEmptyHourly()
          else
            ..._activeHourlyOrders.map(
              (
                Map<String, dynamic> item,
              ) {
                return _buildHourRow(
                  hour:
                      item['hour']?.toString() ??
                          '-',
                  orders: _asInt(
                    item['orders'],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyHourly() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          13,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            color: Color(0xFF98A2B3),
          ),
          SizedBox(
            height: 7,
          ),
          Text(
            'No active invoice hours',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourRow({
    required String hour,
    required int orders,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(
                9,
              ),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: _primaryBlue,
              size: 16,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              _formatHourRange(
                hour,
              ),
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            constraints:
                const BoxConstraints(
              minWidth: 44,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(
                9,
              ),
            ),
            child: Text(
              NumberFormat.decimalPattern(
                'en_IN',
              ).format(
                orders,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _deepBlue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INVOICE SECTION
  // ---------------------------------------------------------------------------

  Widget _buildInvoicesSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5FF),
                borderRadius: BorderRadius.circular(
                  11,
                ),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: _primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(
              width: 11,
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Records',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(
                    height: 2,
                  ),
                  Text(
                    'Detailed invoices for this division',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10.5,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5FF),
                borderRadius: BorderRadius.circular(
                  20,
                ),
              ),
              child: Text(
                '${invoices.length} shown',
                style: const TextStyle(
                  color: _deepBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 14,
        ),
        if (invoices.isEmpty)
          _buildEmptyInvoices()
        else
          ...invoices.map(
            (
              Map<String, dynamic> invoice,
            ) {
              return _buildInvoiceCard(
                invoice,
              );
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CLICKABLE INVOICE CARD
  // ---------------------------------------------------------------------------

  Widget _buildInvoiceCard(
    Map<String, dynamic> invoice,
  ) {
    final Map<String, dynamic> customer =
        _asMap(
      invoice['customer'],
    );

    final Map<String, dynamic> staff =
        _asMap(
      invoice['manage_staff'],
    );

    final Map<String, dynamic> company =
        _asMap(
      invoice['company'],
    );

    final String invoiceNumber =
        (invoice['invoice'] ??
                invoice['invoice_number'] ??
                '-')
            .toString();

    final String customerName =
        (customer['name'] ??
                invoice['customer_name'] ??
                'Unknown Customer')
            .toString();

    final String staffName =
        (staff['name'] ??
                invoice['staff_name'] ??
                '-')
            .toString();

    final String companyName =
        (company['name'] ??
                invoice['company_name'] ??
                '-')
            .toString();

    final String status =
        (invoice['status'] ?? '-')
            .toString();

    final double amount = _asDouble(
      invoice['amount'] ??
          invoice['total_amount'],
    );

    final String hour =
        (invoice['_hour'] ?? '-')
            .toString();

    final int orderId = _asInt(
      invoice['order_id'] ??
          invoice['id'],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828)
                .withOpacity(
              0.035,
            ),
            blurRadius: 14,
            offset: const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          18,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(
            18,
          ),
          onTap: () {
            openOrderReview(
              orderId,
            );
          },
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  15,
                  15,
                  15,
                  13,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient:
                            _dashboardBlueGradient,
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: const Icon(
                        Icons.receipt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  invoiceNumber,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              const Icon(
                                Icons
                                    .arrow_forward_ios_rounded,
                                color: _textSecondary,
                                size: 12,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            customerName,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11.5,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _statusBackgroundColor(
                          status,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: Text(
                        _statusDisplayName(
                          status,
                        ),
                        style: TextStyle(
                          color: _statusTextColor(
                            status,
                          ),
                          fontSize: 9,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                color: _borderColor,
              ),
              Padding(
                padding: const EdgeInsets.all(
                  15,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInvoiceInfo(
                            icon:
                                Icons.person_outline_rounded,
                            label: 'Staff',
                            value: staffName,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: _buildInvoiceInfo(
                            icon:
                                Icons.schedule_rounded,
                            label: 'Hour',
                            value:
                                _formatHourRange(
                              hour,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInvoiceInfo(
                            icon:
                                Icons.currency_rupee_rounded,
                            label: 'Amount',
                            value:
                                _formatAmount(
                              amount,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: _buildInvoiceInfo(
                            icon:
                                Icons.access_time_rounded,
                            label: 'Created',
                            value:
                                _formatCreatedTime(
                              invoice['created_at'],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(
                        11,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFF8FAFC),
                        borderRadius:
                            BorderRadius.circular(
                          11,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            color: _textSecondary,
                            size: 16,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Company',
                                  style: TextStyle(
                                    color:
                                        _textSecondary,
                                    fontSize: 9.5,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  companyName,
                                  style:
                                      const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 10.5,
                                    height: 1.35,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: _primaryBlue,
                            size: 20,
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
      ),
    );
  }

  Widget _buildInvoiceInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(
        10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          11,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(
                8,
              ),
            ),
            child: Icon(
              icon,
              color: _primaryBlue,
              size: 14,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 10.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInvoices() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 35,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: Color(0xFF98A2B3),
            size: 30,
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            'No invoice records found',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGINATION
  // ---------------------------------------------------------------------------

  Widget _buildPagination() {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final int firstRecord =
        totalCount == 0
            ? 0
            : ((currentPage - 1) * pageSize) +
                1;

    int lastRecord =
        currentPage * pageSize;

    if (lastRecord > totalCount) {
      lastRecord = totalCount;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Showing $firstRecord-$lastRecord of '
                  '${NumberFormat.decimalPattern('en_IN').format(totalCount)}',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isPageLoading ||
                              currentPage <= 1
                          ? null
                          : () {
                              fetchFamilyInvoices(
                                page:
                                    currentPage - 1,
                              );
                            },
                  icon: const Icon(
                    Icons
                        .arrow_back_ios_new_rounded,
                    size: 14,
                  ),
                  label: const Text(
                    'Previous',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        _deepBlue,
                    side: const BorderSide(
                      color: Color(0xFFD7E7FF),
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    textStyle:
                        const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      isPageLoading ||
                              currentPage >=
                                  totalPages
                          ? null
                          : () {
                              fetchFamilyInvoices(
                                page:
                                    currentPage + 1,
                              );
                            },
                  icon: isPageLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons
                              .arrow_forward_ios_rounded,
                          size: 14,
                        ),
                  label: const Text(
                    'Next',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor:
                        _primaryBlue,
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        const Color(
                      0xFFE4E7EC,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    textStyle:
                        const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildContent() {
    return RefreshIndicator(
      color: _primaryBlue,
      onRefresh: () {
        return fetchFamilyInvoices(
          page: currentPage,
        );
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          30,
        ),
        children: [
          _buildHeroCard(),

          const SizedBox(
            height: 18,
          ),

          _buildQuickSummary(),

          const SizedBox(
            height: 18,
          ),

          _buildHourlySection(),

          const SizedBox(
            height: 26,
          ),

          _buildInvoicesSection(),

          const SizedBox(
            height: 16,
          ),

          _buildPagination(),

          const SizedBox(
            height: 12,
          ),

          if (invoices.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5FF),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .account_balance_wallet_outlined,
                    color: _deepBlue,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 9,
                  ),
                  const Expanded(
                    child: Text(
                      'Current page invoice amount',
                      style: TextStyle(
                        color: _deepBlue,
                        fontSize: 10.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatAmount(
                      _currentPageAmount,
                    ),
                    style: const TextStyle(
                      color: _deepBlue,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        surfaceTintColor: Colors.white,
        toolbarHeight: 64,
        titleSpacing: 0,
        iconTheme: const IconThemeData(
          color: _textPrimary,
        ),
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              familyName.isEmpty
                  ? 'Invoice Details'
                  : '$familyName Invoices',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 2,
            ),
            const Text(
              'Detailed invoice performance',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),
            child: Material(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(
                12,
              ),
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                onTap: isLoading ||
                        isPageLoading ||
                        isOpeningInvoice
                    ? null
                    : () {
                        fetchFamilyInvoices(
                          page: currentPage,
                        );
                      },
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: _primaryBlue,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(
            1,
          ),
          child: Divider(
            height: 1,
            thickness: 1,
            color: _borderColor,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? _buildLoadingView()
            : errorMessage != null &&
                    invoices.isEmpty
                ? _buildErrorView()
                : Stack(
                    children: [
                      _buildContent(),
                      if (isPageLoading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child:
                              LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor:
                                Color(
                              0xFFD7E7FF,
                            ),
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              _primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}