import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beposoft/Sales%20Directors/SD_dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/api.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SdAllDsrReportPage extends StatefulWidget {
  const SdAllDsrReportPage({super.key});

  @override
  State<SdAllDsrReportPage> createState() => _SdAllDsrReportPageState();
}

class _SdAllDsrReportPageState extends State<SdAllDsrReportPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  bool isLoading = true;
  bool isInitialLoading = true;
  bool isLoadingMore = false;
  bool hasNextPage = true;
  bool isExporting = false;
  bool isStaffLoading = false;
  bool isStateLoading = false;
  bool isDistrictLoading = false;
  bool isUpdatingStatus = false;

  String? nextPageUrl;

  int totalCount = 0;
  int staffCount = 0;
  String totalCallDuration = "00:00:00";
  double callDurationAverage8hrs = 0.0;

  int filteredTotalCount = 0;
  int filteredStaffCount = 0;
  String filteredTotalCallDuration = "00:00:00";
  double filteredCallDurationAverage8hrs = 0.0;

  DateTimeRange? selectedDateRange;
  String selectedSummaryFilter = "";

  int? loggedInFamilyId;

  int? selectedStaffId;
  String selectedStaffName = "";

  int? selectedStateId;
  String selectedStateName = "";

  int? selectedDistrictId;
  String selectedDistrictName = "";

  List<Map<String, dynamic>> dsrList = [];
  List<Map<String, dynamic>> filteredDsrList = [];

  List<Map<String, dynamic>> staffList = [];
  List<Map<String, dynamic>> stateList = [];
  List<Map<String, dynamic>> districtList = [];
  List<Map<String, dynamic>> allDistrictList = [];

  final Set<int> _expandedProductCards = {};

  final List<String> allowedStatuses = [
    'dsr created',
    'dsr approved',
    'dsr confirmed',
    'dsr rejected',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initPage();
  }

  Future<void> _initPage() async {
    loggedInFamilyId = await getFamilyIdFromProfile();
    await fetchStaffByFamily();
    await getState();
    await getDistricts();
    await fetchDsrList(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<String?> gettokenFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getdepFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  Future<void> _navigateBack() async {
    final dep = await getdepFromPrefs();
    if (!mounted) return;

    if (dep == "BDO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => bdo_dashbord()),
      );
    } else if (dep == "SD") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SdDashboard()),
      );
    } else if (dep == "BDM") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => bdm_dashbord()),
      );
    } else if (dep == "warehouse") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WarehouseDashboard()),
      );
    } else if (dep == "Warehouse Admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WarehouseAdmin()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => dashboard()),
      );
    }
  }

  Future<int?> getFamilyIdFromProfile() async {
    try {
      final token = await gettokenFromPrefs();
      if (token == null || token.isEmpty) return null;

      final response = await http.get(
        Uri.parse('$api/api/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final familyId = parsed["data"]?["family_id"] ?? parsed["data"]?["family"];

        if (familyId is int) return familyId;
        return int.tryParse(familyId.toString());
      }

      return null;
    } catch (e) {
      debugPrint("PROFILE FETCH ERROR: $e");
      return null;
    }
  }

  Future<void> fetchStaffByFamily() async {
    try {
      setState(() => isStaffLoading = true);

      final token = await gettokenFromPrefs();

      int? familyId = loggedInFamilyId;
      familyId ??= await getFamilyIdFromProfile();

      if (familyId == null) {
        setState(() {
          staffList = [];
          isStaffLoading = false;
        });
        return;
      }

      loggedInFamilyId = familyId;

      final response = await http.get(
        Uri.parse('$api/api/users/family/$familyId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final List<Map<String, dynamic>> tempStaff = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final data = parsed["data"] ?? [];

        for (final item in data) {
          tempStaff.add({
            "id": item["id"],
            "name": item["name"]?.toString() ?? "",
          });
        }
      }

      if (!mounted) return;
      setState(() {
        staffList = tempStaff;
        isStaffLoading = false;
      });
    } catch (e) {
      debugPrint("STAFF FETCH ERROR: $e");
      if (!mounted) return;
      setState(() {
        staffList = [];
        isStaffLoading = false;
      });
    }
  }

  Future<void> getState() async {
    try {
      setState(() => isStateLoading = true);

      final token = await gettokenFromPrefs();

      final response = await http.get(
        Uri.parse('$api/api/states/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final List<Map<String, dynamic>> tempStates = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final data = parsed["data"] ?? [];

        for (final item in data) {
          tempStates.add({
            "id": item["id"],
            "name": item["name"]?.toString() ?? "",
          });
        }
      }

      if (!mounted) return;
      setState(() {
        stateList = tempStates;
        isStateLoading = false;
      });
    } catch (e) {
      debugPrint("STATE FETCH ERROR: $e");
      if (!mounted) return;
      setState(() {
        stateList = [];
        isStateLoading = false;
      });
    }
  }

  Future<void> getDistricts() async {
    try {
      setState(() => isDistrictLoading = true);

      final token = await gettokenFromPrefs();

      final response = await http.get(
        Uri.parse('$api/api/districts/add/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final List<Map<String, dynamic>> tempDistricts = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final rawData = parsed is Map && parsed["data"] is List
            ? parsed["data"]
            : parsed is List
                ? parsed
                : [];

        for (final item in rawData) {
          tempDistricts.add({
            "id": item["id"],
            "name": item["name"]?.toString() ??
                item["district_name"]?.toString() ??
                "",
            "state_id": item["state"] ??
                item["state_id"] ??
                item["state_name_id"] ??
                item["stateId"],
          });
        }
      }

      if (!mounted) return;
      setState(() {
        allDistrictList = tempDistricts;
        districtList = _getFilteredDistrictsForSelectedState();
        isDistrictLoading = false;
      });
    } catch (e) {
      debugPrint("DISTRICT FETCH ERROR: $e");
      if (!mounted) return;
      setState(() {
        allDistrictList = [];
        districtList = [];
        isDistrictLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredDistrictsForSelectedState() {
    if (selectedStateId == null) {
      return List<Map<String, dynamic>>.from(allDistrictList);
    }

    return allDistrictList.where((item) {
      final value = item["state_id"];
      final id = value is int ? value : int.tryParse(value.toString());
      return id == selectedStateId;
    }).toList();
  }

  void _refreshDistrictOptionsAfterStateChange() {
    districtList = _getFilteredDistrictsForSelectedState();

    if (selectedDistrictId != null) {
      final exists = districtList.any((e) => e["id"] == selectedDistrictId);
      if (!exists) {
        selectedDistrictId = null;
        selectedDistrictName = "";
      }
    }
  }

  String _formatDateForApi(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  String formatDateTime(String value) {
    if (value.trim().isEmpty) return "-";
    try {
      final dt = DateTime.parse(value).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year} "
          "${dt.hour.toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return value;
    }
  }

  String formatDateOnly(DateTime value) {
    return "${value.day.toString().padLeft(2, '0')}-"
        "${value.month.toString().padLeft(2, '0')}-"
        "${value.year}";
  }

  String _safeText(dynamic value) {
    if (value == null) return "-";
    final text = value.toString().trim();
    return text.isEmpty ? "-" : text;
  }

  String _capitalizeWords(String value) {
    return value.split(" ").map((e) {
      if (e.isEmpty) return e;
      return e[0].toUpperCase() + e.substring(1);
    }).join(" ");
  }

  int _durationToSeconds(String value) {
    try {
      final parts = value.split(":");
      if (parts.length != 3) return 0;

      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;

      return h * 3600 + m * 60 + s;
    } catch (_) {
      return 0;
    }
  }

  String _secondsToDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    return "${h.toString().padLeft(2, '0')}:"
        "${m.toString().padLeft(2, '0')}:"
        "${s.toString().padLeft(2, '0')}";
  }

  Uri _buildUri({String? nextUrl}) {
    if (nextUrl != null && nextUrl.isNotEmpty) {
      return Uri.parse(nextUrl);
    }

    final Map<String, String> queryParams = {};

    if (_searchController.text.trim().isNotEmpty) {
      queryParams["search"] = _searchController.text.trim();
    }

    if (selectedDateRange != null) {
      queryParams["start_date"] = _formatDateForApi(selectedDateRange!.start);
      queryParams["end_date"] = _formatDateForApi(selectedDateRange!.end);
    }

    if (selectedStaffId != null) {
      queryParams["created_by"] = selectedStaffId.toString();
    }

    if (selectedStateId != null) {
      queryParams["state"] = selectedStateId.toString();
    }

    if (selectedDistrictId != null) {
      queryParams["district"] = selectedDistrictId.toString();
    }

    if (selectedSummaryFilter == "active") {
      queryParams["call_status"] = "active";
    } else if (selectedSummaryFilter == "productive") {
      queryParams["call_status"] = "productive";
    } else if (selectedSummaryFilter == "created") {
      queryParams["status"] = "dsr created";
    } else if (selectedSummaryFilter == "approved") {
      queryParams["status"] = "dsr approved";
    } else if (selectedSummaryFilter == "confirmed") {
      queryParams["status"] = "dsr confirmed";
    } else if (selectedSummaryFilter == "rejected") {
      queryParams["status"] = "dsr rejected";
    }

    return Uri.parse('$api/api/sales/team/member/daily/report/all/')
        .replace(queryParameters: queryParams);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoading &&
        !isLoadingMore &&
        hasNextPage) {
      fetchDsrList();
    }
  }

  Future<void> fetchDsrList({bool isRefresh = false}) async {
    try {
      if (isRefresh) {
        setState(() {
          isLoading = true;
          isInitialLoading = true;
          isLoadingMore = false;
          hasNextPage = true;
          nextPageUrl = null;
          dsrList.clear();
          filteredDsrList.clear();
          _expandedProductCards.clear();
        });
      } else {
        if (!hasNextPage || nextPageUrl == null) return;
        setState(() => isLoadingMore = true);
      }

      final token = await gettokenFromPrefs();
      final uri = isRefresh ? _buildUri() : _buildUri(nextUrl: nextPageUrl);

      debugPrint("FETCH ALL DSR URL: $uri");

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("FETCH ALL DSR STATUS: ${response.statusCode}");
      debugPrint("FETCH ALL DSR BODY: ${response.body}");

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);

        final Map results = parsed["results"] ?? {};
        final List data = results["data"] ?? [];

        final List<Map<String, dynamic>> tempList = [];

        for (final item in data) {
          final invoiceDetails = item["invoice_details"];

          final List<Map<String, dynamic>> products = [];

          if (invoiceDetails != null && invoiceDetails["items"] is List) {
            for (final p in invoiceDetails["items"]) {
              products.add({
                "product_id": p["product_id"],
                "name": p["name"]?.toString() ?? "",
                "image": p["image"] != null && p["image"].toString().isNotEmpty
                    ? "$api${p["image"]}"
                    : "",
                "quantity": p["quantity"] ?? 0,
              });
            }
          }

          tempList.add({
            "id": item["id"],
            "team": item["team"],
            "team_name": item["team_name"]?.toString() ?? "",
            "division": item["division"],
            "division_name": item["division_name"]?.toString() ?? "",
            "state": item["state"],
            "state_name": item["state_name"]?.toString() ?? "",
            "district": item["district"],
            "district_name": item["district_name"]?.toString() ?? "",
            "created_by": item["created_by"],
            "created_by_name": item["created_by_name"]?.toString() ?? "",
            "invoice_id": item["invoice"],
            "invoice_no": item["invoice_number"]?.toString() ??
                invoiceDetails?["invoice"]?.toString() ??
                "",
            "invoice_amount": invoiceDetails?["total_amount"]?.toString() ?? "0",
            "invoice_payment_status":
                invoiceDetails?["payment_status"]?.toString() ?? "",
            "invoice_status": invoiceDetails?["status"]?.toString() ?? "",
            "order_date": invoiceDetails?["order_date"]?.toString() ?? "",
            "customer_name": item["customer_name"]?.toString() ?? "",
            "phone": item["phone"]?.toString() ?? "",
            "call_status": item["call_status"]?.toString() ?? "",
            "status": item["status"]?.toString() ?? "",
            "call_duration": item["call_duration"]?.toString() ?? "00:00:00",
            "call_duration_percentage_8hrs":
                item["call_duration_percentage_8hrs"] ?? 0,
            "note": item["note"]?.toString() ?? "",
            "created_at": item["created_at"]?.toString() ?? "",
            "total_quantity": invoiceDetails?["total_quantity"]?.toString() ?? "0",
            "total_items_count":
                invoiceDetails?["total_items_count"]?.toString() ?? "0",
            "product_details": products,
          });
        }

        if (!mounted) return;

        setState(() {
          totalCount = parsed["count"] ?? tempList.length;
          staffCount = results["staff_count"] ?? 0;
          totalCallDuration = results["total_call_duration"] ?? "00:00:00";
          callDurationAverage8hrs =
              double.tryParse("${results["call_duration_average_8hrs"] ?? 0}") ??
                  0.0;

          if (isRefresh) {
            dsrList = tempList;
          } else {
            dsrList.addAll(tempList);
          }

          nextPageUrl = parsed["next"];
          hasNextPage = nextPageUrl != null;

          isLoading = false;
          isInitialLoading = false;
          isLoadingMore = false;
        });

        _applyFilters();
      } else {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          isInitialLoading = false;
          isLoadingMore = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Failed: ${response.body}"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        isInitialLoading = false;
        isLoadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Error: $e"),
        ),
      );
    }
  }

  void _applyFilters() {
    filteredDsrList = List<Map<String, dynamic>>.from(dsrList);

    filteredTotalCount = filteredDsrList.length;

    final uniqueStaff = <String>{};
    int totalSeconds = 0;

    for (final item in filteredDsrList) {
      final name = item["created_by_name"]?.toString().trim() ?? "";
      if (name.isNotEmpty) uniqueStaff.add(name);

      totalSeconds += _durationToSeconds(
        item["call_duration"]?.toString() ?? "00:00:00",
      );
    }

    filteredStaffCount = uniqueStaff.length;
    filteredTotalCallDuration = _secondsToDuration(totalSeconds);
    filteredCallDurationAverage8hrs = callDurationAverage8hrs;

    if (mounted) setState(() {});
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: selectedDateRange,
      helpText: "Select Date Range",
    );

    if (picked != null) {
      setState(() => selectedDateRange = picked);
      fetchDsrList(isRefresh: true);
    }
  }

  void _clearDateRange() {
    setState(() => selectedDateRange = null);
    fetchDsrList(isRefresh: true);
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      selectedDateRange = null;
      selectedSummaryFilter = "";
      selectedStaffId = null;
      selectedStaffName = "";
      selectedStateId = null;
      selectedStateName = "";
      selectedDistrictId = null;
      selectedDistrictName = "";
      _refreshDistrictOptionsAfterStateChange();
    });

    fetchDsrList(isRefresh: true);
  }

  Color getCallStatusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == "productive") return Colors.green;
    if (s == "active") return Colors.orange;
    return Colors.grey;
  }

  Color getDsrStatusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == "dsr rejected") return Colors.red;
    if (s == "dsr approved") return Colors.green;
    if (s == "dsr confirmed") return Colors.deepPurple;
    if (s == "dsr created") return Colors.blue;
    return Colors.grey;
  }

  Widget buildInfoRow(
    String title,
    String value, {
    IconData? icon,
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 95,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Text(
            ":  ",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: TextStyle(
                fontSize: 12.5,
                color: valueColor ?? Colors.black87,
                fontWeight: valueWeight ?? FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildChip(String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.isEmpty ? "-" : label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xff2196F3), size: 20),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xff0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSummary() {
    final int createdCount = filteredDsrList
        .where((e) => e["status"].toString().toLowerCase() == "dsr created")
        .length;
    final int approvedCount = filteredDsrList
        .where((e) => e["status"].toString().toLowerCase() == "dsr approved")
        .length;
    final int confirmedCount = filteredDsrList
        .where((e) => e["status"].toString().toLowerCase() == "dsr confirmed")
        .length;
    final int rejectedCount = filteredDsrList
        .where((e) => e["status"].toString().toLowerCase() == "dsr rejected")
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "All DSR Report Summary",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem(
                "Records",
                filteredTotalCount.toString(),
                Icons.assignment_outlined,
              ),
              const SizedBox(width: 8),
              _buildSummaryItem(
                "Staff",
                staffCount.toString(),
                Icons.groups_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSummaryItem(
                "Call Duration",
                totalCallDuration,
                Icons.timer_outlined,
              ),
              const SizedBox(width: 8),
              _buildSummaryItem(
                "8 Hrs %",
                callDurationAverage8hrs.toStringAsFixed(2),
                Icons.percent_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildChip("Created: $createdCount", Colors.blue),
              buildChip("Approved: $approvedCount", Colors.green),
              buildChip("Confirmed: $confirmedCount", Colors.deepPurple),
              buildChip("Rejected: $rejectedCount", Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductImagePlaceholder() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_outlined, size: 26, color: Colors.grey.shade400),
    );
  }

  Widget _buildProductTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> p) {
    final imageUrl = p["image"]?.toString().trim() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(),
                  )
                : _buildProductImagePlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _safeText(p["name"]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                _buildProductTag("Qty: ${p["quantity"] ?? "-"}", Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProductDetails(int itemId, List<Map<String, dynamic>> products) {
    if (products.isEmpty) return const SizedBox.shrink();

    final bool isExpanded = _expandedProductCards.contains(itemId);
    final bool hasMore = products.length > 1;
    final visibleProducts = isExpanded ? products : [products.first];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          "Product Details",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 10),
        ...visibleProducts.map((p) => _buildProductRow(p)).toList(),
        if (hasMore)
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedProductCards.remove(itemId);
                } else {
                  _expandedProductCards.add(itemId);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xff2196F3).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xff2196F3).withOpacity(0.18),
                ),
              ),
              child: Text(
                isExpanded ? "See Less" : "See More Products",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff2196F3),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> item, int index) {
    final itemId = item["id"] is int
        ? item["id"]
        : int.tryParse(item["id"].toString()) ?? index;

    final products = item["product_details"] is List
        ? List<Map<String, dynamic>>.from(item["product_details"])
        : <Map<String, dynamic>>[];

    final callStatus = item["call_status"]?.toString() ?? "";
    final dsrStatus = item["status"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xff2196F3).withOpacity(0.12),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    color: Color(0xff2196F3),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _safeText(item["customer_name"]),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff0F172A),
                  ),
                ),
              ),
              buildChip(
  _capitalizeWords(dsrStatus),
  getDsrStatusColor(dsrStatus),
  onTap: () => _openStatusBottomSheet(item),
),
const SizedBox(width: 6),
InkWell(
  onTap: () => _openStatusBottomSheet(item),
  borderRadius: BorderRadius.circular(10),
  child: Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(
      Icons.edit_outlined,
      size: 18,
      color: Colors.blue,
    ),
  ),
),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildChip(
                _capitalizeWords(callStatus),
                getCallStatusColor(callStatus),
              ),
              buildChip(
                "Duration: ${_safeText(item["call_duration"])}",
                Colors.indigo,
              ),
              buildChip(
                "8 Hrs: ${_safeText(item["call_duration_percentage_8hrs"])}%",
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 14),
          buildInfoRow("Staff", _safeText(item["created_by_name"]),
              icon: Icons.person_outline),
          buildInfoRow("Phone", _safeText(item["phone"]),
              icon: Icons.phone_outlined),
          buildInfoRow("Team", _safeText(item["team_name"]),
              icon: Icons.groups_outlined),
          buildInfoRow("Division", _safeText(item["division_name"]),
              icon: Icons.category_outlined),
          buildInfoRow("State", _safeText(item["state_name"]),
              icon: Icons.location_on_outlined),
          buildInfoRow("District", _safeText(item["district_name"]),
              icon: Icons.map_outlined),
          buildInfoRow("Invoice", _safeText(item["invoice_no"]),
              icon: Icons.receipt_long_outlined),
          buildInfoRow("Amount", _safeText(item["invoice_amount"]),
              icon: Icons.currency_rupee_outlined),
          buildInfoRow("Payment", _safeText(item["invoice_payment_status"]),
              icon: Icons.payment_outlined),
          buildInfoRow("Invoice Status", _safeText(item["invoice_status"]),
              icon: Icons.verified_outlined),
          buildInfoRow("Order Date", _safeText(item["order_date"]),
              icon: Icons.date_range_outlined),
          buildInfoRow("Created", formatDateTime(item["created_at"]?.toString() ?? ""),
              icon: Icons.access_time_outlined),
          buildInfoRow("Note", _safeText(item["note"]),
              icon: Icons.note_alt_outlined),
          buildProductDetails(itemId, products),
        ],
      ),
    );
  }

  Future<void> _openStatusBottomSheet(Map<String, dynamic> item) async {
    String selectedStatus = item["status"]?.toString().trim() ?? "";

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Update DSR Status",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _safeText(item["customer_name"]),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ...allowedStatuses.map(
                      (status) => RadioListTile<String>(
                        value: status,
                        groupValue: selectedStatus,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _capitalizeWords(status),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onChanged: isUpdatingStatus
                            ? null
                            : (value) {
                                if (value == null) return;
                                setBottomState(() => selectedStatus = value);
                              },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isUpdatingStatus
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await updateDsrStatus(item["id"], selectedStatus);
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Update Status",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> updateDsrStatus(int id, String status) async {
    try {
      setState(() => isUpdatingStatus = true);

      final token = await gettokenFromPrefs();

      final response = await http.patch(
        Uri.parse('$api/api/sales/team/member/daily/report/edit/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"status": status}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        await fetchDsrList(isRefresh: true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Status updated successfully"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Failed: ${response.body}"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Error: $e"),
        ),
      );
    } finally {
      if (mounted) setState(() => isUpdatingStatus = false);
    }
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required bool isLoading,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? title : value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value.isEmpty ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
            ),
            if (value.isNotEmpty)
              InkWell(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              )
            else if (isLoading)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required Function(Map<String, dynamic>) onSelect,
  }) async {
    final TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> visibleItems = List.from(items);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xffF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    onChanged: (value) {
                      setBottomState(() {
                        visibleItems = items.where((item) {
                          return item["name"]
                              .toString()
                              .toLowerCase()
                              .contains(value.toLowerCase());
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: visibleItems.isEmpty
                        ? const Center(child: Text("No data found"))
                        : ListView.builder(
                            itemCount: visibleItems.length,
                            itemBuilder: (context, index) {
                              final item = visibleItems[index];
                              return ListTile(
                                title: Text(item["name"]?.toString() ?? ""),
                                onTap: () {
                                  Navigator.pop(context);
                                  onSelect(item);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Filters",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _clearAllFilters();
                          },
                          child: const Text("Clear All"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: "Search customer, phone, staff, invoice",
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: const Color(0xffF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              onChanged: (_) {
                                _debounce?.cancel();
                                _debounce = Timer(
                                  const Duration(milliseconds: 500),
                                  () => fetchDsrList(isRefresh: true),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _pickDateRange,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selectedDateRange == null
                                            ? "Select Date Range"
                                            : "${formatDateOnly(selectedDateRange!.start)} to ${formatDateOnly(selectedDateRange!.end)}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: selectedDateRange == null
                                              ? Colors.grey.shade600
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (selectedDateRange != null)
                                      InkWell(
                                        onTap: _clearDateRange,
                                        child: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.date_range,
                                        color: Colors.grey,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            _buildDropdownTile(
                              title: "Select Staff",
                              value: selectedStaffName,
                              isLoading: isStaffLoading,
                              onTap: () {
                                _showSelectionSheet(
                                  title: "Select Staff",
                                  items: staffList,
                                  onSelect: (item) {
                                    setState(() {
                                      selectedStaffId = item["id"];
                                      selectedStaffName =
                                          item["name"]?.toString() ?? "";
                                    });
                                    setBottomState(() {});
                                    fetchDsrList(isRefresh: true);
                                  },
                                );
                              },
                              onClear: () {
                                setState(() {
                                  selectedStaffId = null;
                                  selectedStaffName = "";
                                });
                                setBottomState(() {});
                                fetchDsrList(isRefresh: true);
                              },
                            ),
                            _buildDropdownTile(
                              title: "Select State",
                              value: selectedStateName,
                              isLoading: isStateLoading,
                              onTap: () {
                                _showSelectionSheet(
                                  title: "Select State",
                                  items: stateList,
                                  onSelect: (item) {
                                    setState(() {
                                      selectedStateId = item["id"];
                                      selectedStateName =
                                          item["name"]?.toString() ?? "";
                                      _refreshDistrictOptionsAfterStateChange();
                                    });
                                    setBottomState(() {});
                                    fetchDsrList(isRefresh: true);
                                  },
                                );
                              },
                              onClear: () {
                                setState(() {
                                  selectedStateId = null;
                                  selectedStateName = "";
                                  selectedDistrictId = null;
                                  selectedDistrictName = "";
                                  _refreshDistrictOptionsAfterStateChange();
                                });
                                setBottomState(() {});
                                fetchDsrList(isRefresh: true);
                              },
                            ),
                            _buildDropdownTile(
                              title: "Select District",
                              value: selectedDistrictName,
                              isLoading: isDistrictLoading,
                              onTap: () {
                                _showSelectionSheet(
                                  title: "Select District",
                                  items: districtList,
                                  onSelect: (item) {
                                    setState(() {
                                      selectedDistrictId = item["id"];
                                      selectedDistrictName =
                                          item["name"]?.toString() ?? "";
                                    });
                                    setBottomState(() {});
                                    fetchDsrList(isRefresh: true);
                                  },
                                );
                              },
                              onClear: () {
                                setState(() {
                                  selectedDistrictId = null;
                                  selectedDistrictName = "";
                                });
                                setBottomState(() {});
                                fetchDsrList(isRefresh: true);
                              },
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Quick Filters",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _filterChoice("All", ""),
                                _filterChoice("Active", "active"),
                                _filterChoice("Productive", "productive"),
                                _filterChoice("Created", "created"),
                                _filterChoice("Approved", "approved"),
                                _filterChoice("Confirmed", "confirmed"),
                                _filterChoice("Rejected", "rejected"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          fetchDsrList(isRefresh: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChoice(String title, String value) {
    final selected = selectedSummaryFilter == value;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) {
        setState(() => selectedSummaryFilter = value);
        fetchDsrList(isRefresh: true);
      },
      selectedColor: const Color(0xff2196F3).withOpacity(0.18),
      labelStyle: TextStyle(
        color: selected ? const Color(0xff2196F3) : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: const Color(0xffF8FAFC),
      side: BorderSide(
        color: selected ? const Color(0xff2196F3) : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildBody() {
    if (isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => fetchDsrList(isRefresh: true),
      child: filteredDsrList.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildTopSummary(),
                const SizedBox(height: 120),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 54, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        "No DSR records found",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: filteredDsrList.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) return _buildTopSummary();

                if (index == filteredDsrList.length + 1) {
                  return Column(
                    children: [
                      if (isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                      if (!hasNextPage && filteredDsrList.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 18),
                          child: Text(
                            "No more records",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                    ],
                  );
                }

                final item = filteredDsrList[index - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildCard(item, index - 1),
                );
              },
            ),
    );
  }

 Future<void> exportToExcel() async {
  try {
    if (filteredDsrList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("No data available to export"),
        ),
      );
      return;
    }

    setState(() => isExporting = true);

    final ex.Excel excel = ex.Excel.createExcel();
    const String sheetName = "All DSR Report";
    final ex.Sheet sheet = excel[sheetName];
    excel.delete("Sheet1");

    final headers = [
      "Sl No",
      "Date",
      "Staff",
      "Team",
      "Division",
      "Customer",
      "Phone",
      "State",
      "District",
      "Call Status",
      "DSR Status",
      "Call Duration",
      "8 Hrs %",
      "Invoice",
      "Invoice Amount",
      "Payment Status",
      "Invoice Status",
      "Order Date",
      "Note",
    ];

    sheet.appendRow(headers);

    for (int i = 0; i < filteredDsrList.length; i++) {
      final item = filteredDsrList[i];

      sheet.appendRow([
        "${i + 1}",
        formatDateTime(item["created_at"]?.toString() ?? ""),
        _safeText(item["created_by_name"]),
        _safeText(item["team_name"]),
        _safeText(item["division_name"]),
        _safeText(item["customer_name"]),
        _safeText(item["phone"]),
        _safeText(item["state_name"]),
        _safeText(item["district_name"]),
        _safeText(item["call_status"]),
        _safeText(item["status"]),
        _safeText(item["call_duration"]),
        _safeText(item["call_duration_percentage_8hrs"]),
        _safeText(item["invoice_no"]),
        _safeText(item["invoice_amount"]),
        _safeText(item["invoice_payment_status"]),
        _safeText(item["invoice_status"]),
        _safeText(item["order_date"]),
        _safeText(item["note"]),
      ]);
    }

    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath =
        "${directory.path}/all_dsr_report_${DateTime.now().millisecondsSinceEpoch}.xlsx";

    final List<int>? fileBytes = excel.encode();

    if (fileBytes == null) {
      throw Exception("Failed to generate Excel file");
    }

    final File file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "All DSR Report",
    );
  } catch (e) {
    debugPrint("EXCEL EXPORT ERROR: $e");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text("Excel export failed: $e"),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => isExporting = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: _navigateBack,
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          ),
          title: const Text(
            "All DSR Report",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _openFilterBottomSheet,
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xff2196F3).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.filter_alt_outlined,
                  color: Color(0xff2196F3),
                  size: 20,
                ),
              ),
            ),
            IconButton(
              onPressed: isExporting ? null : exportToExcel,
              icon: isExporting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.file_download_outlined,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }
}