import 'dart:convert';
import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/ADMIN/sales_report_excel.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/MARKETING/marketing_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyReportPage extends StatefulWidget {
  final int familyId;
  final String familyName;
  final DateTimeRange selectedRange;

  const FamilyReportPage({
    super.key,
    required this.familyId,
    required this.familyName,
    required this.selectedRange,
  });

  @override
  State<FamilyReportPage> createState() => _FamilyReportPageState();
}

class _FamilyReportPageState extends State<FamilyReportPage> {
  bool isLoading = true;

  Map<String, dynamic> summary = {};
  List<dynamic> orders = [];

  Map<String, Map<String, dynamic>> staffGrouped = {};
  Map<String, Map<String, dynamic>> filteredStaff = {};

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchFamilyData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    return DateFormat("yyyy-MM-dd").format(date);
  }

  String formatDisplayDate(DateTime date) {
    return DateFormat("dd/MM/yyyy").format(date);
  }

  Future<void> fetchFamilyData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    final start = formatDate(widget.selectedRange.start);
    final end = formatDate(widget.selectedRange.end);

    final url = Uri.parse(
      "https://bepocart.in/api/orders/date/report/$start/$end/?family_id=${widget.familyId}",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body.startsWith("{")) {
        final data = jsonDecode(response.body);

        orders = data["orders"] ?? [];
        summary = data["summary"] ?? {};

        groupByStaff();
        filteredStaff = Map.from(staffGrouped);

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // -------------------------------------------------------------
  // GROUP ORDERS BY STAFF
  // -------------------------------------------------------------
  void groupByStaff() {
    staffGrouped = {};

    final List<String> pendingStatuses = [
      "Invoice Created",
      "Invoice Approved",
      "Waiting for confirmation",
      "Waiting For Confirmation",
    ];

    final List<String> excludedFromApprovedStatuses = [
      "Invoice Rejected",
      "Invoice Created",
      "Invoice Approved",
      "Waiting for confirmation",
      "Waiting For Confirmation",
    ];

    for (var order in orders) {
      final String name = order["staff_name"]?.toString() ?? "Unknown Staff";
      final double amount = ((order["amount"] ?? 0) as num).toDouble();
      final String status = order["status"]?.toString().trim() ?? "";

      final bool rejected = status == "Invoice Rejected";
      final bool pendingBill = pendingStatuses.contains(status);
      final bool approvedBill = !excludedFromApprovedStatuses.contains(status);

      if (!staffGrouped.containsKey(name)) {
        staffGrouped[name] = {
          "total_count": 0,
          "total_amount": 0.0,
          "approved_count": 0,
          "approved_amount": 0.0,
          "pending_count": 0,
          "pending_amount": 0.0,
          "rejected_count": 0,
          "rejected_amount": 0.0,
        };
      }

      staffGrouped[name]!["total_count"] += 1;
      staffGrouped[name]!["total_amount"] += amount;

      if (rejected) {
        staffGrouped[name]!["rejected_count"] += 1;
        staffGrouped[name]!["rejected_amount"] += amount;
      }

      if (pendingBill) {
        staffGrouped[name]!["pending_count"] += 1;
        staffGrouped[name]!["pending_amount"] += amount;
      }

      if (approvedBill) {
        staffGrouped[name]!["approved_count"] += 1;
        staffGrouped[name]!["approved_amount"] += amount;
      }
    }
  }

  // -------------------------------------------------------------
  // SEARCH FILTER
  // -------------------------------------------------------------
  void filterStaff(String query) {
    if (query.isEmpty) {
      filteredStaff = Map.from(staffGrouped);
    } else {
      filteredStaff = staffGrouped.map((key, value) {
        return MapEntry(key, value);
      });

      filteredStaff.removeWhere((key, value) {
        return !key.toLowerCase().contains(query.toLowerCase());
      });
    }

    if (mounted) {
      setState(() {});
    }
  }

  drower d = drower();

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  Future<void> _navigateBack() async {
    final dep = await getdepFromPrefs();

    Widget page;

    switch (dep) {
      case "BDO":
        page = bdo_dashbord();
        break;
      case "BDM":
        page = bdm_dashbord();
        break;
      case "warehouse":
        page = WarehouseDashboard();
        break;
      case "CEO":
        page = ceo_dashboard();
        break;
      case "COO":
        page = ceo_dashboard();
        break;
      case "CSO":
        page = cso_dashboard();
        break;
      case "Warehouse Admin":
        page = WarehouseAdmin();
        break;
      case "Marketing":
        page = marketing_dashboard();
        break;
      default:
        page = dashboard();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  // -------------------------------------------------------------
  // BUILD UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final reportSummary = summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.familyName} Staff Summary",
          style: const TextStyle(fontSize: 16),
        ),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SalesReportExcel(),
              ),
            );
          },
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: buildSearchBar(),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: buildCompletedSummaryCard(reportSummary),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (var staff in filteredStaff.keys)
                          buildStaffCard(
                            staff,
                            filteredStaff[staff]!,
                          ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // -------------------------------------------------------------
  // SEARCH BAR UI
  // -------------------------------------------------------------
  Widget buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: filterStaff,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: "Search staff...",
          border: InputBorder.none,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // FULL API SUMMARY CARD
  // -------------------------------------------------------------
  Widget buildCompletedSummaryCard(Map<String, dynamic> data) {
    final totalOrders = data["total_orders"] ??
        {
          "count": 0,
          "amount": 0.0,
        };

    final nonRejectedOrders = data["non_rejected_orders"] ??
        {
          "count": 0,
          "amount": 0.0,
        };

    final pendingOrders = data["pending_orders"] ??
        {
          "count": 0,
          "amount": 0.0,
        };

    final rejectedOrders = data["rejected_orders"] ??
        {
          "count": 0,
          "amount": 0.0,
        };

    final String startDate = formatDisplayDate(widget.selectedRange.start);
    final String endDate = formatDisplayDate(widget.selectedRange.end);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0150B8),
            Color(0xFF3BD67C),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${widget.familyName} Sales Summary",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "$startDate → $endDate",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          Table(
            border: TableBorder.all(
              color: Colors.white.withOpacity(0.4),
              width: 0.7,
            ),
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1.8),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                ),
                children: [
                  paddedWhiteSmall("Type", bold: true),
                  paddedWhiteSmall("Count", bold: true),
                  paddedWhiteSmall("Amount", bold: true),
                ],
              ),
              summaryRow("Total Bills", totalOrders),
              summaryRow("Approved Bills", nonRejectedOrders),
              summaryRow("Pending Bills", pendingOrders),
              summaryRow("Rejected Bills", rejectedOrders),
            ],
          ),
        ],
      ),
    );
  }

  TableRow summaryRow(String title, dynamic rowData) {
    final int count = rowData is Map ? (rowData["count"] ?? 0) : 0;

    final double amount = rowData is Map
        ? ((rowData["amount"] ?? 0) as num).toDouble()
        : 0.0;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 5,
          ),
          child: Text(
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 5,
          ),
          child: Text(
            "$count",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 5,
          ),
          child: Text(
            "₹${amount.toStringAsFixed(2)}",
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Padding paddedWhiteSmall(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STAFF CARD UI
  // -------------------------------------------------------------
  Widget buildStaffCard(String staff, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          header(staff),
          tableBody(data),
          footer(data),
        ],
      ),
    );
  }

  BoxDecoration gradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF0150B8),
          Color(0xFF3BD67C),
        ],
      ),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(12),
      ),
    );
  }

  Widget header(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: gradient(),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget tableBody(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Table(
        border: TableBorder.all(
          color: Colors.grey.shade400,
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
            ),
            children: [
              padded("Type", bold: true),
              padded("Count", bold: true),
              padded("Amount", bold: true),
            ],
          ),
          row(
            "Total Bills",
            data["total_count"],
            data["total_amount"],
          ),
          row(
            "Approved Bills",
            data["approved_count"],
            data["approved_amount"],
          ),
          row(
            "Pending Bills",
            data["pending_count"],
            data["pending_amount"],
          ),
          row(
            "Rejected Bills",
            data["rejected_count"],
            data["rejected_amount"],
          ),
        ],
      ),
    );
  }

  TableRow row(String label, dynamic count, dynamic amt) {
    final double amount = ((amt ?? 0) as num).toDouble();

    return TableRow(
      children: [
        padded(label),
        padded("${count ?? 0}"),
        padded(
          "₹${amount.toStringAsFixed(2)}",
          color: Colors.green,
        ),
      ],
    );
  }

  Padding padded(String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget footer(Map<String, dynamic> data) {
    final int count = data["total_count"] ?? 0;
    final double amount = ((data["total_amount"] ?? 0) as num).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: gradient(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Total",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          Text(
            "$count",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          Text(
            "₹${amount.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}