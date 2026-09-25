import 'dart:async';
import 'dart:convert';

import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';


// ============================================================
// MY GRV PAGE
// ============================================================

class MyGrvPage extends StatefulWidget {
  const MyGrvPage({super.key});

  @override
  State<MyGrvPage> createState() => _MyGrvPageState();
}


class _MyGrvPageState extends State<MyGrvPage> {

  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue = Color(0xFF2C74FF);

  static const Color lightBlue = Color(0xFF56AFFF);

  static const Color backgroundColor = Color(0xFFF5F7FB);

  static const Color textColor = Color(0xFF172033);

  static const Color secondaryText = Color(0xFF7A8495);

  static const Color borderColor = Color(0xFFE8ECF3);


  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> grvList = [];

  List<Map<String, dynamic>> filteredGrvList = [];


  // ============================================================
  // PAGINATION
  // ============================================================

  String? nextPageUrl;

  int totalCount = 0;

  bool isLoadingMore = false;

  bool hasMore = false;


  // ============================================================
  // LOADING
  // ============================================================

  bool isLoading = true;

  String? errorMessage;


  // ============================================================
  // SEARCH AND FILTER
  // ============================================================

  final TextEditingController searchController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  String searchQuery = '';

  String selectedStatus = 'All';


  final List<String> statusFilters = [

    'All',

    'Pending',

    'Waiting For Approval',

    'Approved',

    'Rejected',

  ];


  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {

    super.initState();

    fetchMyGrvData();

    scrollController.addListener(_onScroll);

  }


  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {

    searchController.dispose();

    scrollController.removeListener(_onScroll);

    scrollController.dispose();

    super.dispose();

  }


  // ============================================================
  // TOKEN
  // ============================================================

  Future<String?> getTokenFromPrefs() async {

    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    return prefs.getString('token');

  }


  // ============================================================
  // API URL
  // ============================================================

  Uri get grvApiUrl {

    return Uri.parse(
      '$api/api/my/grv/data/',
    );

  }


  // ============================================================
  // FETCH MY GRV DATA
  // ============================================================

  Future<void> fetchMyGrvData({
    bool refresh = false,
  }) async {

    if (!mounted) return;

    setState(() {

      isLoading = true;

      errorMessage = null;

    });

    try {

      final String? token =
          await getTokenFromPrefs();

      if (token == null || token.trim().isEmpty) {

        throw Exception(
          'Your session has expired. Please log in again.',
        );

      }

      final http.Response response =
          await http.get(

        grvApiUrl,

        headers: {

          'Authorization': 'Bearer $token',

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

      ).timeout(

        const Duration(seconds: 30),

      );


      debugPrint(
        'MY GRV RESPONSE STATUS: ${response.statusCode}',
      );


      if (response.statusCode == 401) {

        throw Exception(
          'Your session has expired. Please log in again.',
        );

      }


      if (response.statusCode == 403) {

        throw Exception(
          'You do not have permission to view GRV records.',
        );

      }


      if (response.statusCode != 200) {

        throw Exception(
          'Unable to fetch GRV records. '
          'Server returned ${response.statusCode}.',
        );

      }


      final dynamic decoded =
          jsonDecode(response.body);


      if (decoded is! Map<String, dynamic>) {

        throw const FormatException(
          'Invalid GRV response format.',
        );

      }


      // ========================================================
      // ACTUAL RESPONSE STRUCTURE
      //
      // {
      //   "count": 17,
      //   "next": null,
      //   "previous": null,
      //   "results": {
      //     "status": "success",
      //     "message": "...",
      //     "data": []
      //   }
      // }
      // ========================================================

      final dynamic results =
          decoded['results'];


      if (results is! Map) {

        throw const FormatException(
          'GRV results are missing.',
        );

      }


      if (results['status']?.toString().toLowerCase() ==
          'error') {

        throw Exception(
          results['message']?.toString() ??
              'Unable to fetch GRV records.',
        );

      }


      final dynamic rawData =
          results['data'];


      if (rawData is! List) {

        throw const FormatException(
          'GRV data must be a list.',
        );

      }


      final List<Map<String, dynamic>> newData =
          rawData.map(

        (dynamic item) {

          return Map<String, dynamic>.from(
            item as Map,
          );

        },

      ).toList();


      final String? next =
          decoded['next']?.toString();


      if (!mounted) return;


      setState(() {

        grvList = newData;

        totalCount =
            int.tryParse(
              decoded['count']?.toString() ?? '',
            ) ??
            newData.length;

        nextPageUrl =
            next != null && next.trim().isNotEmpty
                ? next
                : null;

        hasMore = nextPageUrl != null;

        isLoading = false;

        errorMessage = null;

      });


      applyFilters();


    } on TimeoutException {

      if (!mounted) return;

      setState(() {

        isLoading = false;

        errorMessage =
            'Request timed out. Please check your internet connection.';

      });


    } catch (error, stackTrace) {

      debugPrint(
        'MY GRV ERROR: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );


      if (!mounted) return;


      setState(() {

        isLoading = false;

        errorMessage = error.toString().replaceFirst(
          'Exception: ',
          '',
        );

      });

    }

  }


  // ============================================================
  // PAGINATION SCROLL LISTENER
  // ============================================================

  void _onScroll() {

    if (!scrollController.hasClients) return;

    if (isLoading || isLoadingMore || !hasMore) {

      return;

    }

    final double remaining =
        scrollController.position.extentAfter;

    if (remaining < 350) {

      fetchNextPage();

    }

  }


  // ============================================================
  // FETCH NEXT PAGE
  // ============================================================

  Future<void> fetchNextPage() async {

    if (isLoadingMore ||
        !hasMore ||
        nextPageUrl == null) {

      return;

    }


    setState(() {

      isLoadingMore = true;

    });


    try {

      final String? token =
          await getTokenFromPrefs();


      if (token == null || token.trim().isEmpty) {

        throw Exception(
          'Session expired.',
        );

      }


      final Uri nextUri =
          grvApiUrl.resolve(nextPageUrl!);


      // Prevent sending the bearer token to an unexpected host.

      if (nextUri.scheme != grvApiUrl.scheme ||
          nextUri.host != grvApiUrl.host ||
          nextUri.port != grvApiUrl.port ||
          nextUri.path != grvApiUrl.path) {

        throw Exception(
          'Invalid pagination URL received.',
        );

      }


      final http.Response response =
          await http.get(

        nextUri,

        headers: {

          'Authorization': 'Bearer $token',

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

      ).timeout(

        const Duration(seconds: 30),

      );


      if (response.statusCode != 200) {

        throw Exception(
          'Unable to load more records.',
        );

      }


      final dynamic decoded =
          jsonDecode(response.body);


      if (decoded is! Map<String, dynamic>) {

        throw const FormatException(
          'Invalid pagination response.',
        );

      }


      final dynamic results =
          decoded['results'];


      if (results is! Map ||
          results['data'] is! List) {

        throw const FormatException(
          'Invalid pagination data.',
        );

      }


      final List<Map<String, dynamic>> newData =
          (results['data'] as List).map(

        (dynamic item) {

          return Map<String, dynamic>.from(
            item as Map,
          );

        },

      ).toList();


      final String? next =
          decoded['next']?.toString();


      if (!mounted) return;


      setState(() {

        // Avoid duplicate GRV records between pages.

        final Set<String> existingIds =
            grvList.map(

          (item) => item['id'].toString(),

        ).toSet();


        for (final item in newData) {

          final String id =
              item['id'].toString();

          if (!existingIds.contains(id)) {

            grvList.add(item);

            existingIds.add(id);

          }

        }


        nextPageUrl =
            next != null && next.trim().isNotEmpty
                ? next
                : null;

        hasMore = nextPageUrl != null;

      });


      applyFilters();


    } catch (error) {

      debugPrint(
        'MY GRV PAGINATION ERROR: $error',
      );


      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(
              error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
            ),

            behavior: SnackBarBehavior.floating,

          ),

        );

      }


    } finally {

      if (mounted) {

        setState(() {

          isLoadingMore = false;

        });

      }

    }

  }


  // ============================================================
  // SEARCH AND FILTER
  // ============================================================

  void applyFilters() {

    final String query =
        searchQuery.trim().toLowerCase();


    final List<Map<String, dynamic>> filtered =
        grvList.where(

      (Map<String, dynamic> item) {


        final String status =
            item['status']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';


        final bool matchesStatus =
            selectedStatus == 'All' ||
            status == selectedStatus.toLowerCase();


        final String searchableText = [

          item['product'],

          item['customer'],

          item['shipping_customer'],

          item['invoice'],

          item['staff'],

          item['returnreason'],

          item['remark'],

          item['note'],

          item['id'],

        ].map(

          (dynamic value) =>
              value?.toString() ?? '',

        ).join(' ').toLowerCase();


        final bool matchesSearch =
            query.isEmpty ||
            searchableText.contains(query);


        return matchesStatus && matchesSearch;

      },

    ).toList();


    if (!mounted) return;


    setState(() {

      filteredGrvList = filtered;

    });

  }


  // ============================================================
  // HELPERS
  // ============================================================

  String safeText(dynamic value) {

    if (value == null) return '—';

    final String text =
        value.toString().trim();

    if (text.isEmpty) return '—';

    return text;

  }


  int parseInt(dynamic value) {

    if (value is int) return value;

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;

  }


  double parseDouble(dynamic value) {

    if (value is num) {

      return value.toDouble();

    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;

  }


  String formatCurrency(dynamic value) {

    final double amount =
        parseDouble(value);


    return NumberFormat.currency(

      locale: 'en_IN',

      symbol: '₹',

      decimalDigits: 2,

    ).format(amount);

  }


  String formatDate(dynamic value) {

    if (value == null ||
        value.toString().trim().isEmpty) {

      return '—';

    }


    try {

      final DateTime date =
          DateTime.parse(value.toString());

      return DateFormat(
        'dd MMM yyyy',
      ).format(date);


    } catch (_) {

      return value.toString();

    }

  }


  String formatLabel(dynamic value) {

    final String text =
        safeText(value);


    if (text == '—') return text;


    return text
        .replaceAll('_', ' ')
        .split(' ')
        .map(

          (word) {

            if (word.isEmpty) return word;

            return word[0].toUpperCase() +
                word.substring(1).toLowerCase();

          },

        )
        .join(' ');

  }


  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color getStatusColor(String status) {

    switch (status.toLowerCase().trim()) {

      case 'approved':

        return const Color(0xFF16A34A);


      case 'rejected':

        return const Color(0xFFDC2626);


      case 'waiting for approval':

      case 'pending':

        return const Color(0xFFF59E0B);


      default:

        return primaryBlue;

    }

  }


  Color getStatusBackground(String status) {

    switch (status.toLowerCase().trim()) {

      case 'approved':

        return const Color(0xFFE8F8EE);


      case 'rejected':

        return const Color(0xFFFEECEC);


      case 'waiting for approval':

      case 'pending':

        return const Color(0xFFFFF5DF);


      default:

        return const Color(0xFFEAF2FF);

    }

  }


  // ============================================================
  // SUMMARY COUNTS
  // ============================================================

  int get waitingCount {

    return grvList.where(

      (item) {

        final String status =
            item['status']
                    ?.toString()
                    .toLowerCase()
                    .trim() ??
                '';

        return status == 'waiting for approval' ||
            status == 'pending';

      },

    ).length;

  }


  int get approvedCount {

    return grvList.where(

      (item) =>
          item['status']
              ?.toString()
              .toLowerCase()
              .trim() ==
          'approved',

    ).length;

  }


  int get rejectedCount {

    return grvList.where(

      (item) =>
          item['status']
              ?.toString()
              .toLowerCase()
              .trim() ==
          'rejected',

    ).length;

  }


  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget buildSummaryCard() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(22),

        gradient: const LinearGradient(

          colors: [

            lightBlue,

            primaryBlue,

          ],

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

        ),

        boxShadow: [

          BoxShadow(

            color: primaryBlue.withOpacity(0.20),

            blurRadius: 18,

            offset: const Offset(0, 8),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(

                  color: Colors.white.withOpacity(0.16),

                  borderRadius: BorderRadius.circular(12),

                ),

                child: const Icon(

                  Icons.assignment_return_outlined,

                  color: Colors.white,

                  size: 25,

                ),

              ),

              const SizedBox(width: 12),

              const Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'MY GRV SUMMARY',

                      style: TextStyle(

                        color: Colors.white70,

                        fontSize: 11,

                        fontWeight: FontWeight.w700,

                        letterSpacing: 1,

                      ),

                    ),

                    SizedBox(height: 4),

                    Text(

                      'Goods Return Voucher',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 16,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 22),

          Text(

            totalCount.toString(),

            style: const TextStyle(

              color: Colors.white,

              fontSize: 36,

              fontWeight: FontWeight.w900,

            ),

          ),

          const SizedBox(height: 3),

          const Text(

            'Total GRV Records',

            style: TextStyle(

              color: Colors.white70,

              fontSize: 12,

            ),

          ),

          const SizedBox(height: 20),

          Container(

            height: 1,

            color: Colors.white.withOpacity(0.22),

          ),

          const SizedBox(height: 18),

          Row(

            children: [

              Expanded(

                child: buildSummaryMetric(

                  'Waiting',

                  waitingCount.toString(),

                  Icons.schedule_rounded,

                ),

              ),

              Expanded(

                child: buildSummaryMetric(

                  'Approved',

                  approvedCount.toString(),

                  Icons.check_circle_outline_rounded,

                ),

              ),

              Expanded(

                child: buildSummaryMetric(

                  'Rejected',

                  rejectedCount.toString(),

                  Icons.cancel_outlined,

                ),

              ),

            ],

          ),

          if (hasMore) ...[

            const SizedBox(height: 14),

            Text(

              'Status counts reflect loaded records.',

              style: TextStyle(

                color: Colors.white.withOpacity(0.8),

                fontSize: 10,

              ),

            ),

          ],

        ],

      ),

    );

  }


  // ============================================================
  // SUMMARY METRIC
  // ============================================================

  Widget buildSummaryMetric(

    String label,

    String value,

    IconData icon,

  ) {

    return Column(

      children: [

        Icon(

          icon,

          color: Colors.white70,

          size: 20,

        ),

        const SizedBox(height: 7),

        Text(

          value,

          style: const TextStyle(

            color: Colors.white,

            fontSize: 21,

            fontWeight: FontWeight.w800,

          ),

        ),

        const SizedBox(height: 3),

        Text(

          label,

          textAlign: TextAlign.center,

          style: const TextStyle(

            color: Colors.white70,

            fontSize: 10,

            fontWeight: FontWeight.w600,

          ),

        ),

      ],

    );

  }


  // ============================================================
  // SEARCH FIELD
  // ============================================================

  Widget buildSearchField() {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(15),

        border: Border.all(

          color: borderColor,

        ),

      ),

      child: TextField(

        controller: searchController,

        onChanged: (String value) {

          searchQuery = value;

          applyFilters();

        },

        decoration: InputDecoration(

          hintText: 'Search product, invoice, customer...',

          hintStyle: const TextStyle(

            fontSize: 13,

            color: secondaryText,

          ),

          prefixIcon: const Icon(

            Icons.search_rounded,

            color: primaryBlue,

          ),

          suffixIcon: searchQuery.isNotEmpty

              ? IconButton(

                  icon: const Icon(

                    Icons.close_rounded,

                    size: 19,

                  ),

                  onPressed: () {

                    searchController.clear();

                    searchQuery = '';

                    applyFilters();

                  },

                )

              : null,

          border: InputBorder.none,

          contentPadding: const EdgeInsets.symmetric(

            horizontal: 14,

            vertical: 15,

          ),

        ),

      ),

    );

  }


  // ============================================================
  // STATUS FILTER
  // ============================================================

  Widget buildStatusFilters() {

    return SizedBox(

      height: 43,

      child: ListView.separated(

        scrollDirection: Axis.horizontal,

        itemCount: statusFilters.length,

        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),

        itemBuilder: (context, index) {

          final String status =
              statusFilters[index];


          final bool selected =
              selectedStatus == status;


          return ChoiceChip(

            label: Text(

              status,

              style: TextStyle(

                color: selected
                    ? Colors.white
                    : secondaryText,

                fontSize: 12,

                fontWeight: FontWeight.w600,

              ),

            ),

            selected: selected,

            showCheckmark: false,

            selectedColor: primaryBlue,

            backgroundColor: Colors.white,

            side: BorderSide(

              color: selected
                  ? primaryBlue
                  : borderColor,

            ),

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(12),

            ),

            onSelected: (_) {

              selectedStatus = status;

              applyFilters();

            },

          );

        },

      ),

    );

  }


  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget buildStatusBadge(String status) {

    final Color color =
        getStatusColor(status);


    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 10,

        vertical: 6,

      ),

      decoration: BoxDecoration(

        color: getStatusBackground(status),

        borderRadius: BorderRadius.circular(8),

      ),

      child: Text(

        formatLabel(status),

        style: TextStyle(

          color: color,

          fontSize: 10,

          fontWeight: FontWeight.w700,

        ),

      ),

    );

  }


  // ============================================================
  // GRV RECORD CARD
  // ============================================================

  Widget buildGrvCard(

    Map<String, dynamic> item,

  ) {

    final String product =
        safeText(item['product']);


    final String invoice =
        safeText(item['invoice']);


    final String customer =
        safeText(item['customer']);


    final String status =
        safeText(item['status']);


    final String reason =
        formatLabel(item['returnreason']);


    final int quantity =
        parseInt(item['quantity']);


    final double price =
        parseDouble(item['price']);


    final double total =
        price * quantity;


    return Container(

      margin: const EdgeInsets.only(bottom: 13),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(19),

        border: Border.all(

          color: borderColor,

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(0.025),

            blurRadius: 12,

            offset: const Offset(0, 4),

          ),

        ],

      ),

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          borderRadius: BorderRadius.circular(19),

          onTap: () {

            showGrvDetails(item);

          },

          child: Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                // ==================================================
                // INVOICE AND STATUS
                // ==================================================

                Row(

                  children: [

                    Container(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 10,

                        vertical: 7,

                      ),

                      decoration: BoxDecoration(

                        color: const Color(0xFFEAF2FF),

                        borderRadius: BorderRadius.circular(8),

                      ),

                      child: Text(

                        invoice,

                        style: const TextStyle(

                          color: primaryBlue,

                          fontSize: 11,

                          fontWeight: FontWeight.w800,

                        ),

                      ),

                    ),

                    const Spacer(),

                    Flexible(

                      child: buildStatusBadge(status),

                    ),

                  ],

                ),

                const SizedBox(height: 15),

                // ==================================================
                // PRODUCT
                // ==================================================

                Row(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Container(

                      width: 45,

                      height: 45,

                      decoration: BoxDecoration(

                        color: const Color(0xFFF0F5FF),

                        borderRadius: BorderRadius.circular(13),

                      ),

                      child: const Icon(

                        Icons.inventory_2_outlined,

                        color: primaryBlue,

                        size: 23,

                      ),

                    ),

                    const SizedBox(width: 12),

                    Expanded(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            product,

                            maxLines: 3,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(

                              color: textColor,

                              fontSize: 14,

                              fontWeight: FontWeight.w800,

                              height: 1.35,

                            ),

                          ),

                          const SizedBox(height: 6),

                          Text(

                            customer,

                            maxLines: 2,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(

                              color: secondaryText,

                              fontSize: 12,

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 15),

                const Divider(

                  height: 1,

                  color: borderColor,

                ),

                const SizedBox(height: 14),

                // ==================================================
                // QUANTITY / PRICE / TOTAL
                // ==================================================

                Row(

                  children: [

                    Expanded(

                      child: buildCardInfo(

                        'QUANTITY',

                        quantity.toString(),

                      ),

                    ),

                    Expanded(

                      child: buildCardInfo(

                        'UNIT PRICE',

                        formatCurrency(price),

                      ),

                    ),

                    Expanded(

                      child: buildCardInfo(

                        'TOTAL',

                        formatCurrency(total),

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 15),

                // ==================================================
                // RETURN REASON
                // ==================================================

                Container(

                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(

                    horizontal: 12,

                    vertical: 10,

                  ),

                  decoration: BoxDecoration(

                    color: backgroundColor,

                    borderRadius: BorderRadius.circular(10),

                  ),

                  child: Row(

                    children: [

                      const Icon(

                        Icons.assignment_return_outlined,

                        size: 16,

                        color: secondaryText,

                      ),

                      const SizedBox(width: 8),

                      Expanded(

                        child: Text(

                          'Return Reason: $reason',

                          style: const TextStyle(

                            color: textColor,

                            fontSize: 11,

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

                const SizedBox(height: 13),

                // ==================================================
                // DATE AND DETAILS
                // ==================================================

                Row(

                  children: [

                    const Icon(

                      Icons.calendar_today_outlined,

                      size: 14,

                      color: secondaryText,

                    ),

                    const SizedBox(width: 6),

                    Expanded(

                      child: Text(

                        formatDate(item['date']),

                        style: const TextStyle(

                          color: secondaryText,

                          fontSize: 11,

                        ),

                      ),

                    ),

                    const Text(

                      'View Details',

                      style: TextStyle(

                        color: primaryBlue,

                        fontSize: 11,

                        fontWeight: FontWeight.w700,

                      ),

                    ),

                    const SizedBox(width: 3),

                    const Icon(

                      Icons.arrow_forward_ios_rounded,

                      size: 12,

                      color: primaryBlue,

                    ),

                  ],

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }


  // ============================================================
  // CARD INFORMATION
  // ============================================================

  Widget buildCardInfo(

    String label,

    String value,

  ) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          label,

          style: const TextStyle(

            color: secondaryText,

            fontSize: 9,

            fontWeight: FontWeight.w700,

          ),

        ),

        const SizedBox(height: 6),

        FittedBox(

          fit: BoxFit.scaleDown,

          alignment: Alignment.centerLeft,

          child: Text(

            value,

            style: const TextStyle(

              color: textColor,

              fontSize: 13,

              fontWeight: FontWeight.w800,

            ),

          ),

        ),

      ],

    );

  }


  // ============================================================
  // GRV DETAILS BOTTOM SHEET
  // ============================================================

  void showGrvDetails(

    Map<String, dynamic> item,

  ) {

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (BuildContext context) {

        return DraggableScrollableSheet(

          initialChildSize: 0.82,

          minChildSize: 0.45,

          maxChildSize: 0.95,

          expand: false,

          builder: (

            BuildContext context,

            ScrollController sheetScrollController,

          ) {

            return Container(

              decoration: const BoxDecoration(

                color: Colors.white,

                borderRadius: BorderRadius.vertical(

                  top: Radius.circular(28),

                ),

              ),

              child: Column(

                children: [

                  const SizedBox(height: 12),

                  Container(

                    width: 42,

                    height: 5,

                    decoration: BoxDecoration(

                      color: borderColor,

                      borderRadius: BorderRadius.circular(10),

                    ),

                  ),

                  const SizedBox(height: 18),

                  Padding(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 20,

                    ),

                    child: Row(

                      children: [

                        const Expanded(

                          child: Text(

                            'GRV Details',

                            style: TextStyle(

                              color: textColor,

                              fontSize: 20,

                              fontWeight: FontWeight.w800,

                            ),

                          ),

                        ),

                        IconButton(

                          onPressed: () {

                            Navigator.pop(context);

                          },

                          icon: const Icon(

                            Icons.close_rounded,

                          ),

                        ),

                      ],

                    ),

                  ),

                  const Divider(

                    color: borderColor,

                  ),

                  Expanded(

                    child: ListView(

                      controller: sheetScrollController,

                      padding: const EdgeInsets.fromLTRB(

                        20,

                        10,

                        20,

                        35,

                      ),

                      children: [

                        // ==========================================
                        // HEADER
                        // ==========================================

                        Container(

                          padding: const EdgeInsets.all(18),

                          decoration: BoxDecoration(

                            gradient: const LinearGradient(

                              colors: [

                                lightBlue,

                                primaryBlue,

                              ],

                            ),

                            borderRadius:
                                BorderRadius.circular(18),

                          ),

                          child: Column(

                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              Text(

                                'GRV #${safeText(item['id'])}',

                                style: const TextStyle(

                                  color: Colors.white70,

                                  fontSize: 12,

                                ),

                              ),

                              const SizedBox(height: 9),

                              Text(

                                safeText(item['product']),

                                style: const TextStyle(

                                  color: Colors.white,

                                  fontSize: 17,

                                  fontWeight: FontWeight.w800,

                                ),

                              ),

                              const SizedBox(height: 12),

                              Text(

                                'Invoice: ${safeText(item['invoice'])}',

                                style: const TextStyle(

                                  color: Colors.white,

                                  fontSize: 12,

                                  fontWeight: FontWeight.w600,

                                ),

                              ),

                            ],

                          ),

                        ),

                        const SizedBox(height: 22),

                        // ==========================================
                        // STATUS
                        // ==========================================

                        buildStatusBadge(

                          safeText(item['status']),

                        ),

                        const SizedBox(height: 24),

                        // ==========================================
                        // PRODUCT DETAILS
                        // ==========================================

                        buildSectionTitle(

                          'Product Information',

                          Icons.inventory_2_outlined,

                        ),

                        buildDetailRow(

                          'Product',

                          item['product'],

                        ),

                        buildDetailRow(

                          'Product ID',

                          item['product_id'],

                        ),

                        buildDetailRow(

                          'Family ID',

                          item['family'],

                        ),

                        buildDetailRow(

                          'Quantity',

                          item['quantity'],

                        ),

                        buildDetailRow(

                          'Unit Price',

                          formatCurrency(item['price']),

                        ),

                        buildDetailRow(

                          'Total Amount',

                          formatCurrency(

                            parseDouble(item['price']) *
                                parseInt(item['quantity']),

                          ),

                        ),

                        const SizedBox(height: 24),

                        // ==========================================
                        // CUSTOMER INFORMATION
                        // ==========================================

                        buildSectionTitle(

                          'Customer Information',

                          Icons.person_outline_rounded,

                        ),

                        buildDetailRow(

                          'Customer',

                          item['customer'],

                        ),

                        buildDetailRow(

                          'Shipping Customer',

                          item['shipping_customer'],

                        ),

                        buildDetailRow(

                          'Staff',

                          item['staff'],

                        ),

                        const SizedBox(height: 24),

                        // ==========================================
                        // ORDER INFORMATION
                        // ==========================================

                        buildSectionTitle(

                          'Order Information',

                          Icons.receipt_long_outlined,

                        ),

                        buildDetailRow(

                          'Order ID',

                          item['order'],

                        ),

                        buildDetailRow(

                          'Invoice',

                          item['invoice'],

                        ),

                        buildDetailRow(

                          'Order Date',

                          formatDate(item['order_date']),

                        ),

                        buildDetailRow(

                          'GRV Date',

                          formatDate(item['date']),

                        ),

                        buildDetailRow(

                          'Time',

                          item['time'],

                        ),

                        buildDetailRow(

                          'Parcel Service',

                          item['parcel_service_name'],

                        ),

                        if (item['cod_amount'] != null)

                          buildDetailRow(

                            'COD Amount',

                            formatCurrency(item['cod_amount']),

                          ),

                        const SizedBox(height: 24),

                        // ==========================================
                        // RETURN INFORMATION
                        // ==========================================

                        buildSectionTitle(

                          'Return Information',

                          Icons.assignment_return_outlined,

                        ),

                        buildDetailRow(

                          'Return Reason',

                          formatLabel(item['returnreason']),

                        ),

                        buildDetailRow(

                          'Remark',

                          formatLabel(item['remark']),

                        ),

                        buildDetailRow(

                          'Note',

                          item['note'],

                        ),

                        const SizedBox(height: 24),

                        // ==========================================
                        // RACK DETAILS
                        // ==========================================

                        // buildRackSection(

                        //   'Allocated Rack Details',

                        //   item['rack_details'],

                        // ),

                        // const SizedBox(height: 22),

                        // buildRackSection(

                        //   'Available Rack Products',

                        //   item['rack_products'],

                        // ),

                        // const SizedBox(height: 22),

                        // buildRackSection(

                        //   'Selected Racks',

                        //   item['selected_racks'],

                        // ),

                      ],

                    ),

                  ),

                ],

              ),

            );

          },

        );

      },

    );

  }


  // ============================================================
  // DETAIL SECTION TITLE
  // ============================================================

  Widget buildSectionTitle(

    String title,

    IconData icon,

  ) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 12),

      child: Row(

        children: [

          Container(

            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(

              color: const Color(0xFFEAF2FF),

              borderRadius: BorderRadius.circular(9),

            ),

            child: Icon(

              icon,

              color: primaryBlue,

              size: 18,

            ),

          ),

          const SizedBox(width: 10),

          Expanded(

            child: Text(

              title,

              style: const TextStyle(

                color: textColor,

                fontSize: 15,

                fontWeight: FontWeight.w800,

              ),

            ),

          ),

        ],

      ),

    );

  }


  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget buildDetailRow(

    String label,

    dynamic value,

  ) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 10,

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Expanded(

            flex: 4,

            child: Text(

              label,

              style: const TextStyle(

                color: secondaryText,

                fontSize: 12,

              ),

            ),

          ),

          const SizedBox(width: 10),

          Expanded(

            flex: 6,

            child: Text(

              safeText(value),

              textAlign: TextAlign.right,

              style: const TextStyle(

                color: textColor,

                fontSize: 12,

                fontWeight: FontWeight.w700,

              ),

            ),

          ),

        ],

      ),

    );

  }


  // ============================================================
  // RACK SECTION
  // ============================================================

  Widget buildRackSection(

    String title,

    dynamic rawRacks,

  ) {

    final List<dynamic> racks =
        rawRacks is List
            ? rawRacks
            : [];


    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        buildSectionTitle(

          title,

          Icons.warehouse_outlined,

        ),

        if (racks.isEmpty)

          Container(

            width: double.infinity,

            padding: const EdgeInsets.all(15),

            decoration: BoxDecoration(

              color: backgroundColor,

              borderRadius: BorderRadius.circular(12),

            ),

            child: const Text(

              'No rack information available',

              style: TextStyle(

                color: secondaryText,

                fontSize: 12,

              ),

            ),

          )

        else

          ...racks.map(

            (dynamic rawRack) {

              final Map<String, dynamic> rack =
                  Map<String, dynamic>.from(
                    rawRack as Map,
                  );


              return Container(

                margin: const EdgeInsets.only(bottom: 9),

                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(

                  color: backgroundColor,

                  borderRadius: BorderRadius.circular(13),

                  border: Border.all(

                    color: borderColor,

                  ),

                ),

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Row(

                      children: [

                        const Icon(

                          Icons.location_on_outlined,

                          color: primaryBlue,

                          size: 18,

                        ),

                        const SizedBox(width: 7),

                        Expanded(

                          child: Text(

                            safeText(rack['rack_name']),

                            style: const TextStyle(

                              color: textColor,

                              fontSize: 13,

                              fontWeight: FontWeight.w800,

                            ),

                          ),

                        ),

                        Text(

                          safeText(rack['column_name']),

                          style: const TextStyle(

                            color: primaryBlue,

                            fontSize: 12,

                            fontWeight: FontWeight.w700,

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height: 10),

                    if (rack['quantity'] != null)

                      buildDetailRow(

                        'Quantity',

                        rack['quantity'],

                      ),

                    if (rack['rack_stock'] != null)

                      buildDetailRow(

                        'Rack Stock',

                        rack['rack_stock'],

                      ),

                    if (rack['rack_lock'] != null)

                      buildDetailRow(

                        'Rack Lock',

                        rack['rack_lock'],

                      ),

                    buildDetailRow(

                      'Usability',

                      formatLabel(rack['usability']),

                    ),

                  ],

                ),

              );

            },

          ),

      ],

    );

  }


  // ============================================================
  // LOADING VIEW
  // ============================================================

  Widget buildLoadingView() {

    return const Center(

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          CircularProgressIndicator(

            color: primaryBlue,

          ),

          SizedBox(height: 16),

          Text(

            'Loading your GRV records...',

            style: TextStyle(

              color: secondaryText,

              fontSize: 13,

            ),

          ),

        ],

      ),

    );

  }


  // ============================================================
  // ERROR VIEW
  // ============================================================

  Widget buildErrorView() {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(25),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(

              Icons.cloud_off_outlined,

              size: 65,

              color: secondaryText,

            ),

            const SizedBox(height: 18),

            const Text(

              'Unable to Load GRV Records',

              textAlign: TextAlign.center,

              style: TextStyle(

                color: textColor,

                fontSize: 17,

                fontWeight: FontWeight.w800,

              ),

            ),

            const SizedBox(height: 10),

            Text(

              errorMessage ?? 'Something went wrong.',

              textAlign: TextAlign.center,

              style: const TextStyle(

                color: secondaryText,

                fontSize: 12,

              ),

            ),

            const SizedBox(height: 22),

            ElevatedButton.icon(

              onPressed: () {

                fetchMyGrvData();

              },

              icon: const Icon(

                Icons.refresh_rounded,

              ),

              label: const Text('Try Again'),

              style: ElevatedButton.styleFrom(

                backgroundColor: primaryBlue,

                foregroundColor: Colors.white,

                padding: const EdgeInsets.symmetric(

                  horizontal: 22,

                  vertical: 13,

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }


  // ============================================================
  // EMPTY VIEW
  // ============================================================

  Widget buildEmptyView() {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 65,

        horizontal: 20,

      ),

      child: Column(

        children: [

          Container(

            width: 75,

            height: 75,

            decoration: BoxDecoration(

              color: const Color(0xFFEAF2FF),

              borderRadius: BorderRadius.circular(22),

            ),

            child: const Icon(

              Icons.inventory_2_outlined,

              color: primaryBlue,

              size: 35,

            ),

          ),

          const SizedBox(height: 18),

          const Text(

            'No GRV Records Found',

            style: TextStyle(

              color: textColor,

              fontSize: 17,

              fontWeight: FontWeight.w800,

            ),

          ),

          const SizedBox(height: 8),

          const Text(

            'There are no GRV records matching your selection.',

            textAlign: TextAlign.center,

            style: TextStyle(

              color: secondaryText,

              fontSize: 12,

            ),

          ),

        ],

      ),

    );

  }


  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget buildMainContent() {

    return RefreshIndicator(

      color: primaryBlue,

      onRefresh: () async {

        await fetchMyGrvData(
          refresh: true,
        );

      },

      child: ListView(

        controller: scrollController,

        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(

          16,

          18,

          16,

          25,

        ),

        children: [

          // ======================================================
          // SUMMARY
          // ======================================================

          buildSummaryCard(),

          const SizedBox(height: 23),

          // ======================================================
          // SECTION HEADER
          // ======================================================

          Row(

            children: [

              const Expanded(

                child: Text(

                  'My GRV Records',

                  style: TextStyle(

                    color: textColor,

                    fontSize: 18,

                    fontWeight: FontWeight.w800,

                  ),

                ),

              ),

              Container(

                padding: const EdgeInsets.symmetric(

                  horizontal: 11,

                  vertical: 7,

                ),

                decoration: BoxDecoration(

                  color: const Color(0xFFEAF2FF),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: Text(

                  '${filteredGrvList.length} Records',

                  style: const TextStyle(

                    color: primaryBlue,

                    fontSize: 11,

                    fontWeight: FontWeight.w700,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 15),

          // ======================================================
          // SEARCH
          // ======================================================

          buildSearchField(),

          const SizedBox(height: 13),

          // ======================================================
          // FILTERS
          // ======================================================

          buildStatusFilters(),

          const SizedBox(height: 20),

          // ======================================================
          // LIST
          // ======================================================

          if (filteredGrvList.isEmpty)

            buildEmptyView()

          else

            ...filteredGrvList.map(

              (Map<String, dynamic> item) {

                return buildGrvCard(item);

              },

            ),

          // ======================================================
          // PAGINATION
          // ======================================================

          if (isLoadingMore)

            const Padding(

              padding: EdgeInsets.all(20),

              child: Center(

                child: CircularProgressIndicator(

                  color: primaryBlue,

                ),

              ),

            ),

          if (hasMore && !isLoadingMore)

            Padding(

              padding: const EdgeInsets.symmetric(

                vertical: 15,

              ),

              child: Center(

                child: OutlinedButton.icon(

                  onPressed: fetchNextPage,

                  icon: const Icon(

                    Icons.expand_more_rounded,

                  ),

                  label: const Text(

                    'Load More Records',

                  ),

                  style: OutlinedButton.styleFrom(

                    foregroundColor: primaryBlue,

                    side: const BorderSide(

                      color: primaryBlue,

                    ),

                  ),

                ),

              ),

            ),

          if (!hasMore && grvList.isNotEmpty)

            Padding(

              padding: const EdgeInsets.symmetric(

                vertical: 15,

              ),

              child: Center(

                child: Text(

                  'All ${grvList.length} records loaded',

                  style: const TextStyle(

                    color: secondaryText,

                    fontSize: 11,

                  ),

                ),

              ),

            ),

        ],

      ),

    );

  }


  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: backgroundColor,

      appBar: AppBar(

        backgroundColor: Colors.white,

        surfaceTintColor: Colors.white,

        elevation: 0,

        centerTitle: false,

        leading: IconButton(

          icon: const Icon(

            Icons.arrow_back_ios_new_rounded,

            color: textColor,

            size: 19,

          ),

          onPressed: () {

            Navigator.pop(context);

          },

        ),

        title: const Text(

          'My GRV',

          style: TextStyle(

            color: textColor,

            fontSize: 18,

            fontWeight: FontWeight.w800,

          ),

        ),

        actions: [

          IconButton(

            tooltip: 'Refresh',

            onPressed: isLoading
                ? null
                : () {

                    fetchMyGrvData(
                      refresh: true,
                    );

                  },

            icon: const Icon(

              Icons.refresh_rounded,

              color: primaryBlue,

              size: 24,

            ),

          ),

          const SizedBox(width: 8),

        ],

        bottom: const PreferredSize(

          preferredSize: Size.fromHeight(1),

          child: Divider(

            height: 1,

            color: borderColor,

          ),

        ),

      ),

      body: SafeArea(

        child: isLoading

            ? buildLoadingView()

            : errorMessage != null && grvList.isEmpty

                ? buildErrorView()

                : buildMainContent(),

      ),

    );

  }

}