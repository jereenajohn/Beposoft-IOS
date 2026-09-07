import 'dart:convert';
import 'dart:io';
import 'package:beposoft/Sales%20Directors/sd_add_attendance.dart';
import 'package:beposoft/Sales%20Directors/sd_add_team_staffs.dart';
import 'package:beposoft/Sales%20Directors/sd_all_dsr_reportpage.dart';
import 'package:beposoft/Sales%20Directors/sd_confirm_call_duration.dart';
import 'package:beposoft/pages/ACCOUNTS/add_self_attendance.dart';
import 'package:beposoft/pages/ACCOUNTS/add_services.dart';
import 'package:beposoft/pages/ACCOUNTS/customer.dart';
import 'package:beposoft/pages/ACCOUNTS/grv_list.dart';
import 'package:beposoft/pages/ACCOUNTS/mailboxpage..dart';
import 'package:beposoft/pages/ACCOUNTS/order_list.dart';
import 'package:beposoft/pages/ACCOUNTS/performa_invoice_list.dart';
import 'package:beposoft/pages/ACCOUNTS/view_staff.dart';
import 'package:beposoft/pages/ADMIN/add_attendance.dart';
import 'package:beposoft/pages/ADMIN/localpurchaseorderscreen.dart';
import 'package:beposoft/pages/BDM/bdm_customer_list.dart';
import 'package:beposoft/pages/BDM/bdm_grv_list.dart';
import 'package:beposoft/pages/BDM/bdm_order_list.dart';
import 'package:beposoft/pages/BDM/bdm_staff_list.dart';
import 'package:beposoft/pages/BDM/bdm_today_order_list.dart';
import 'package:beposoft/pages/BDO/EmployeeLeaveFormPage%20.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_order_view.dart';
import 'package:beposoft/pages/logout_hekper.dart';
import 'package:intl/intl.dart';
import 'package:beposoft/pages/auth_status_checker.dart';
import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/add_attribute.dart';
import 'package:beposoft/pages/ACCOUNTS/add_bank.dart';
import 'package:beposoft/pages/ACCOUNTS/add_company.dart';
import 'package:beposoft/pages/ACCOUNTS/add_department.dart';
import 'package:beposoft/pages/ACCOUNTS/add_family.dart';
import 'package:beposoft/pages/ACCOUNTS/add_state.dart';
import 'package:beposoft/pages/ACCOUNTS/add_supervisor.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/methods.dart';
import 'package:beposoft/pages/ACCOUNTS/profilepage.dart';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'dart:async';

class SdDashboard extends StatefulWidget {
  @override
  State<SdDashboard> createState() => _SdDashboardState();
}

class _SdDashboardState extends State<SdDashboard>
    with WidgetsBindingObserver {
        List<String> statusOptions = ["pending", "approved", "rejected"];
  List<Map<String, dynamic>> grvlist = [];
  List<Map<String, dynamic>> proforma = [];
  List<Map<String, dynamic>> salesReportList = [];
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> filteredOrders = [];
  List<Map<String, dynamic>> shippedOrders = [];
  List<Map<String, dynamic>> fam = [];
  List<Map<String, dynamic>> myTeamDetailedSummary = [];
  bool isTeamSummaryLoading = false;
  String? selectedHourSlot;
  DateTime selectedTeamDate = DateTime.now();
  int familyTotalBills = 0;
  double familyTotalAmount = 0.0;
  int familyInvoiceCreatedBills = 0;
  int familyTodaysBills = 0;
  double familyTodaysTotalAmount = 0.0;
  bool isFamilySummaryLoading = false;
  bool isManager = false;
  int inboxMailCount = 0;
Timer? mailCountTimer;
      String profileImage = '';
      bool isFetchingInboxMailCount = false;

  String? username = '';

  // ============================================================
  // BOTTOM NAVIGATION + DASHBOARD SEARCH
  // Same interaction pattern as BDO dashboard
  // ============================================================

  bool isBottomSearchOpen = false;
  String dashboardSearchQuery = '';

  final TextEditingController dashboardSearchController =
      TextEditingController();

  final FocusNode dashboardSearchFocusNode = FocusNode();
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addObserver(this);

  _getUsername();
  fetchproformaData();
  initdata();
  getSalesReport();
  fetchOrderData();
  getcustomer();
  fetchInboxMailCount();
  getProfile();
  fetchMyTeamDetailedSummary();
  fetchFamilyWiseOrderSummary();

  mailCountTimer = Timer.periodic(
    const Duration(seconds: 15),
    (_) {
      if (mounted) {
        fetchInboxMailCount();
      }
    },
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    AuthStatusChecker.start(context);
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    checkAppUpdate(context);
  });
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);

  if (state == AppLifecycleState.resumed) {
    fetchInboxMailCount();
  }
}
  void initdata() async {
    await getfamily();
  }

Future<void> getProfile() async {
    try {
      final token = await getTokenFromPrefs();

      final response = await http.get(
        Uri.parse('$api/api/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final data = parsed['data'];

        setState(() {
          isManager = data['is_manager'] ?? false;
          profileImage = data['image']?.toString() ?? '';
        });

        debugPrint("IS MANAGER : $isManager");
        debugPrint("PROFILE IMAGE : $profileImage");
      }
    } catch (e) {
      debugPrint("PROFILE ERROR : $e");
    }
  }
    String getProfileImageUrl() {
    if (profileImage.trim().isEmpty) return '';
    if (profileImage.startsWith('http')) return profileImage;
    return '$api$profileImage';
  }

  int approval = 0;
  int confirm = 0;
  int customers = 0;
  List<Map<String, dynamic>> customer = [];
  List<Map<String, dynamic>> filteredProducts = [];
  double totalAmountToday = 0.0;
  var family = '';
  String familyName = '';
Future<void> fetchInboxMailCount() async {
  if (isFetchingInboxMailCount) return;

  isFetchingInboxMailCount = true;

  try {
    final String? token = await getTokenFromPrefs();

    if (token == null || token.trim().isEmpty) {
      return;
    }

    final Uri uri = Uri.parse(
      '$api/api/internal/mails/',
    ).replace(
      queryParameters: {
        'type': 'inbox',
        'read_status': 'unread',
        'page': '1',
      },
    );

    final http.Response response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      debugPrint(
        'MAIL COUNT REQUEST FAILED: '
        '${response.statusCode} ${response.body}',
      );
      return;
    }

    final dynamic decoded = jsonDecode(response.body);

    int newUnreadCount = 0;

    if (decoded is Map<String, dynamic>) {
      final dynamic results = decoded['results'];
      final dynamic data = decoded['data'];

      final dynamic rawUnreadCount =
          decoded['unread_count'] ??
          (results is Map ? results['unread_count'] : null) ??
          (data is Map ? data['unread_count'] : null);

      final dynamic rawFilteredCount =
          decoded['count'] ??
          (results is Map ? results['count'] : null) ??
          (data is Map ? data['count'] : null);

      if (rawUnreadCount != null) {
        newUnreadCount =
            rawUnreadCount is int
                ? rawUnreadCount
                : int.tryParse(rawUnreadCount.toString()) ?? 0;
      } else if (rawFilteredCount != null) {
        newUnreadCount =
            rawFilteredCount is int
                ? rawFilteredCount
                : int.tryParse(rawFilteredCount.toString()) ?? 0;
      } else {
        dynamic mailList;

        if (results is Map && results['data'] is List) {
          mailList = results['data'];
        } else if (data is Map && data['data'] is List) {
          mailList = data['data'];
        } else if (results is List) {
          mailList = results;
        } else if (data is List) {
          mailList = data;
        }

        if (mailList is List) {
          newUnreadCount = mailList.where((dynamic mail) {
            if (mail is! Map) return false;

            if (mail.containsKey('is_read')) {
              return mail['is_read'] != true;
            }

            if (mail.containsKey('read')) {
              return mail['read'] != true;
            }

            final dynamic readAt = mail['read_at'];

            return readAt == null ||
                readAt.toString().trim().isEmpty;
          }).length;
        }
      }
    }

    if (!mounted) return;

    if (inboxMailCount != newUnreadCount) {
      setState(() {
        inboxMailCount = newUnreadCount;
      });
    }
  } catch (error, stackTrace) {
    debugPrint('MAIL COUNT ERROR: $error');
    debugPrintStack(stackTrace: stackTrace);
  } finally {
    isFetchingInboxMailCount = false;
  }
}
@override
void dispose() {
  _isDisposed = true;

  WidgetsBinding.instance.removeObserver(this);
  mailCountTimer?.cancel();
  dashboardSearchController.dispose();
  dashboardSearchFocusNode.dispose();

  super.dispose();
}
  Future<bool> checkAppUpdate(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      String? storeVersion;
      Uri? storeUrl;

      if (Platform.isAndroid) {
        final response = await http.get(Uri.parse(
          'https://play.google.com/store/apps/details?id=com.bepositive.beposoft&hl=en',
        ));

        if (response.statusCode == 200) {
          final content = response.body;
          final versionRegex = RegExp(r'\[\[\["([0-9.]+)"\]\]');
          final match = versionRegex.firstMatch(content);

          if (match != null) {
            storeVersion = match.group(1);
            storeUrl = Uri.parse(
              'https://play.google.com/store/apps/details?id=com.bepositive.beposoft',
            );
          }
        }
      } else if (Platform.isIOS) {
        final response = await http.get(
          Uri.parse('https://itunes.apple.com/lookup?id=6748010646&country=in'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['resultCount'] != null &&
              data['resultCount'] > 0 &&
              data['results'] != null &&
              data['results'] is List &&
              data['results'].isNotEmpty) {
            final appData = data['results'][0];
            storeVersion = appData['version']?.toString();
            storeUrl = Uri.parse(
              'https://apps.apple.com/in/app/beposoft/id6748010646',
            );
          }
        }
      }

      if (storeVersion != null &&
          _isUpdateAvailable(currentVersion, storeVersion)) {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.only(top: 20),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Column(
              children: [
                Icon(
                  Icons.system_update,
                  size: 48,
                  color: Colors.green,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Update Available',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'A new version ($storeVersion) is available.\n\nYou are using $currentVersion.\n\nPlease update the app to continue enjoying the latest features and improvements.',
              style: const TextStyle(fontSize: 16),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: const Text("Update Now"),
                onPressed: () async {
                  if (storeUrl != null && await canLaunchUrl(storeUrl)) {
                    await launchUrl(
                      storeUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text("Maybe Later"),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        return result == true;
      }
    } catch (e) {
      // Optional: print(e);
    }

    return true;
  }

  bool _isUpdateAvailable(String currentVersion, String storeVersion) {
    List<int> currentParts =
        currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    List<int> storeParts =
        storeVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    int maxLength = currentParts.length > storeParts.length
        ? currentParts.length
        : storeParts.length;

    while (currentParts.length < maxLength) {
      currentParts.add(0);
    }
    while (storeParts.length < maxLength) {
      storeParts.add(0);
    }

    for (int i = 0; i < maxLength; i++) {
      if (storeParts[i] > currentParts[i]) {
        return true;
      } else if (storeParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }

  Future<void> fetchFamilyWiseOrderSummary() async {
    if (!mounted) return;

    setState(() {
      isFamilySummaryLoading = true;
    });

    try {
      final String? token = await getTokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;

        setState(() {
          familyTotalBills = 0;
          familyTotalAmount = 0.0;
          familyInvoiceCreatedBills = 0;
          familyTodaysBills = 0;
          familyTodaysTotalAmount = 0.0;
        });

        return;
      }

      final http.Response response = await http.get(
        Uri.parse(
          '$api/api/my/order/summary/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
        'MY ORDER SUMMARY RESPONSE: ${response.statusCode}',
      );

      debugPrint(
        'MY ORDER SUMMARY BODY: ${response.body}',
      );

      if (response.statusCode == 200) {
        final dynamic parsed = jsonDecode(
          response.body,
        );

        if (parsed is Map<String, dynamic> &&
            parsed['status'] == 'success') {
          final Map<String, dynamic> currentMonthOrders =
              parsed['current_month_orders'] is Map
                  ? Map<String, dynamic>.from(
                      parsed['current_month_orders'],
                    )
                  : <String, dynamic>{};

          final Map<String, dynamic> todayOrders =
              parsed['today_orders'] is Map
                  ? Map<String, dynamic>.from(
                      parsed['today_orders'],
                    )
                  : <String, dynamic>{};

          final Map<String, dynamic> invoiceCreated =
              parsed['invoice_created'] is Map
                  ? Map<String, dynamic>.from(
                      parsed['invoice_created'],
                    )
                  : <String, dynamic>{};

          if (!mounted) return;

          setState(() {
            familyTotalBills = int.tryParse(
                  currentMonthOrders['count']?.toString() ?? '0',
                ) ??
                0;

            familyTotalAmount = double.tryParse(
                  currentMonthOrders['total_amount']?.toString() ?? '0',
                ) ??
                0.0;

            familyInvoiceCreatedBills = int.tryParse(
                  invoiceCreated['count']?.toString() ?? '0',
                ) ??
                0;

            familyTodaysBills = int.tryParse(
                  todayOrders['count']?.toString() ?? '0',
                ) ??
                0;

            familyTodaysTotalAmount = double.tryParse(
                  todayOrders['total_amount']?.toString() ?? '0',
                ) ??
                0.0;
          });
        } else {
          if (!mounted) return;

          setState(() {
            familyTotalBills = 0;
            familyTotalAmount = 0.0;
            familyInvoiceCreatedBills = 0;
            familyTodaysBills = 0;
            familyTodaysTotalAmount = 0.0;
          });
        }
      } else {
        debugPrint(
          'Failed to fetch my order summary: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'Error in fetchFamilyWiseOrderSummary: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          isFamilySummaryLoading = false;
        });
      }
    }
  }

  String formatCompactAmount(dynamic value) {
    double amount = 0.0;

    if (value is int) {
      amount = value.toDouble();
    } else if (value is double) {
      amount = value;
    } else {
      amount = double.tryParse(value.toString()) ?? 0.0;
    }

    if (amount >= 10000000) {
      return "${(amount / 10000000).toStringAsFixed(2)} Cr";
    } else if (amount >= 100000) {
      return "${(amount / 100000).toStringAsFixed(2)} L";
    } else if (amount >= 1000) {
      return "${(amount / 1000).toStringAsFixed(2)} K";
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  Future<void> fetchMyTeamDetailedSummary() async {
    setState(() {
      isTeamSummaryLoading = true;
    });

    try {
      final token = await getTokenFromPrefs();
      final String selectedDate = formatApiDate(selectedTeamDate);

      final Map<String, String> queryParams = {
        'start_date': selectedDate,
        'end_date': selectedDate,
      };

      if (selectedHourSlot != null && selectedHourSlot!.trim().isNotEmpty) {
        queryParams['time_duration'] = selectedHourSlot!.trim();
      }

      final uri = Uri.parse('$api/api/my/sales/team/detailed/summary/').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);

        if (parsed['success'] == true && parsed['data'] != null) {
          List<Map<String, dynamic>> tempList = [];

          for (var item in parsed['data']) {
            tempList.add({
              "team": {
                "team_id": item["team"]?["team_id"] ?? 0,
                "team_name": item["team"]?["team_name"] ?? "",
              },
              "summary": {
                "total_bill": item["summary"]?["total_bill"] ?? 0,
                "total_volume": item["summary"]?["total_volume"] ?? 0,
                "total_unbilled": item["summary"]?["total_unbilled"] ?? 0,
                "billing": item["summary"]?["billing"] ?? 0,
                "volume": item["summary"]?["volume"] ?? 0,
                "hourly_durations": item["summary"]?["hourly_durations"] ?? {},
                "new_customers": item["summary"]?["new_customers"] ?? 0,
                "new_conversions": item["summary"]?["new_conversions"] ?? 0,
                "total_call_count": item["summary"]?["total_call_count"] ?? 0,
                "total_call_duration":
                    item["summary"]?["total_call_duration"] ?? 0.0,
                "call_duration_average":
                    item["summary"]?["call_duration_average"] ?? 0.0,
                "call_duration_percentage_8hrs":
                    item["summary"]?["call_duration_percentage_8hrs"] ?? 0.0,
                "total_bdo_count": item["summary"]?["total_bdo_count"] ?? 0,
                "active_count": item["summary"]?["active_count"] ?? 0,
                "productive_count": item["summary"]?["productive_count"] ?? 0,
                "unique_customer_count":
                    item["summary"]?["unique_customer_count"] ?? 0,
                "report_count": item["summary"]?["report_count"] ?? 0,
                "present_count": item["summary"]?["present_count"] ?? 0,
                "absent_count": item["summary"]?["absent_count"] ?? 0,
                "half_day_count": item["summary"]?["half_day_count"] ?? 0,
                "total_team_count": item["summary"]?["total_team_count"] ?? 0,
              },
              "members": item["members"] != null
                  ? List<Map<String, dynamic>>.from(
                      item["members"].map((member) => {
                            "staff_id": member["staff_id"] ?? 0,
                            "staff_name": member["staff_name"] ?? "",
                            "attendance_summary": {
                              "present_count": member["attendance_summary"]
                                      ?["present_count"] ??
                                  0,
                              "absent_count": member["attendance_summary"]
                                      ?["absent_count"] ??
                                  0,
                              "half_day_count": member["attendance_summary"]
                                      ?["half_day_count"] ??
                                  0,
                            },
                            "attendance_details": member[
                                        "attendance_details"] !=
                                    null
                                ? List<Map<String, dynamic>>.from(
                                    member["attendance_details"]
                                        .map((attendance) => {
                                              "id": attendance["id"] ?? 0,
                                              "staff_id":
                                                  attendance["staff_id"] ?? 0,
                                              "staff_name":
                                                  attendance["staff_name"] ??
                                                      "",
                                              "status":
                                                  attendance["status"] ?? "",
                                              "created_at":
                                                  attendance["created_at"] ??
                                                      "",
                                              "updated_at":
                                                  attendance["updated_at"] ??
                                                      "",
                                            }),
                                  )
                                : [],
                            "summary": {
                              "total_bill":
                                  member["summary"]?["total_bill"] ?? 0,
                              "total_volume":
                                  member["summary"]?["total_volume"] ?? 0,
                              "total_unbilled":
                                  member["summary"]?["total_unbilled"] ?? 0,
                              "billing": member["summary"]?["billing"] ?? 0,
                              "volume": member["summary"]?["volume"] ?? 0,
                              "hourly_durations":
                                  member["summary"]?["hourly_durations"] ?? {},
                              "new_customers":
                                  member["summary"]?["new_customers"] ?? 0,
                              "new_conversions":
                                  member["summary"]?["new_conversions"] ?? 0,
                              "total_call_count":
                                  member["summary"]?["total_call_count"] ?? 0,
                              "total_call_duration": member["summary"]
                                      ?["total_call_duration"] ??
                                  0.0,
                              "call_duration_average": member["summary"]
                                      ?["call_duration_average"] ??
                                  0.0,
                              "call_duration_percentage_8hrs": member["summary"]
                                      ?["call_duration_percentage_8hrs"] ??
                                  0.0,
                              "total_bdo_count":
                                  member["summary"]?["total_bdo_count"] ?? 0,
                              "active_count":
                                  member["summary"]?["active_count"] ?? 0,
                              "productive_count":
                                  member["summary"]?["productive_count"] ?? 0,
                              "unique_customer_count": member["summary"]
                                      ?["unique_customer_count"] ??
                                  0,
                              "report_count":
                                  member["summary"]?["report_count"] ?? 0,
                              "present_count":
                                  member["summary"]?["present_count"] ?? 0,
                              "absent_count":
                                  member["summary"]?["absent_count"] ?? 0,
                              "half_day_count":
                                  member["summary"]?["half_day_count"] ?? 0,
                              "total_team_count":
                                  member["summary"]?["total_team_count"] ?? 0,
                            },
                            "reports": member["reports"] != null
                                ? List<Map<String, dynamic>>.from(
                                    member["reports"])
                                : [],
                          }),
                    )
                  : [],
            });
          }

          setState(() {
            myTeamDetailedSummary = tempList;
          });
        } else {
          setState(() {
            myTeamDetailedSummary = [];
          });
        }
      } else {
        debugPrint("Failed to fetch team summary: ${response.statusCode}");
        setState(() {
          myTeamDetailedSummary = [];
        });
      }
    } catch (e) {
      debugPrint("Error in fetchMyTeamDetailedSummary: $e");
      setState(() {
        myTeamDetailedSummary = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          isTeamSummaryLoading = false;
        });
      }
    }
  }

  String formatHourSlotLabel(String slot) {
    try {
      final parts = slot.split("-");
      if (parts.length != 2) return slot;

      String formatPart(String value, {required bool forcePm}) {
        final timeParts = value.split(":");
        int hour = int.tryParse(timeParts[0]) ?? 0;
        int minute = int.tryParse(timeParts[1]) ?? 0;

        int actualHour = hour;

        if (forcePm && hour < 12) {
          actualHour = hour + 12;
        }

        final suffix = actualHour >= 12 ? "PM" : "AM";

        int displayHour;
        if (actualHour == 0) {
          displayHour = 12;
        } else if (actualHour > 12) {
          displayHour = actualHour - 12;
        } else {
          displayHour = actualHour;
        }

        if (minute == 0) {
          return "$displayHour $suffix";
        }

        return "$displayHour:${minute.toString().padLeft(2, '0')} $suffix";
      }

      final startRaw = parts[0];
      final endRaw = parts[1];

      final startHour = int.tryParse(startRaw.split(":")[0]) ?? 0;
      final endHour = int.tryParse(endRaw.split(":")[0]) ?? 0;

      final startForcePm = startHour >= 1 && startHour <= 7;
      final endForcePm = endHour >= 1 && endHour <= 7;

      return "${formatPart(startRaw, forcePm: startForcePm)} - ${formatPart(endRaw, forcePm: endForcePm)}";
    } catch (e) {
      return slot;
    }
  }

  Future<void> refreshDashboardData() async {
    try {
      setState(() {
        selectedHourSlot = null;
      });

      await Future.wait([
        fetchproformaData(),
        getfamily(),
        getSalesReport(),
        fetchOrderData(),
        fetchMyTeamDetailedSummary(),
        fetchFamilyWiseOrderSummary(),
        fetchInboxMailCount(),
      ]);
    } catch (e) {
      debugPrint("Error refreshing dashboard: $e");
    }
  }

  String formatApiDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String formatDisplayDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Future<void> pickTeamDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedTeamDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedTeamDate = picked;
        selectedHourSlot = null;
      });
      await fetchMyTeamDetailedSummary();
    }
  }

  String formatDoubleValue(dynamic value) {
    double number = 0.0;

    if (value is int) {
      number = value.toDouble();
    } else if (value is double) {
      number = value;
    } else {
      number = double.tryParse(value.toString()) ?? 0.0;
    }

    return number.toStringAsFixed(2);
  }

  String getAttendanceStatus(Map<String, dynamic> member) {
    final attendanceDetails =
        List<Map<String, dynamic>>.from(member["attendance_details"] ?? []);

    if (attendanceDetails.isNotEmpty) {
      final latestAttendance = attendanceDetails.first;
      final status = (latestAttendance["status"] ?? "").toString().trim();

      if (status.isNotEmpty) {
        return status.replaceAll("_", " ").toUpperCase();
      }
    }

    return "Attendance not added";
  }

  Color getAttendanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "present":
        return Colors.green;
      case "half day":
        return Colors.orange;
      case "absent":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


  // ============================================================
  // INFO CARD
  // Required by the existing family summary method.
  // ============================================================

  Widget _buildInfoCard(
    String value,
    String label,
    int notificationCount,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (notificationCount > 0)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      notificationCount > 99
                          ? '99+'
                          : notificationCount.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFamilySummaryInfoCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Add navigation if needed
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => bdm_OrderList(status: null),
                    //   ),
                    // );
                  },
                  child: _buildInfoCard(
                    isFamilySummaryLoading
                        ? "..."
                        : familyTotalBills.toString(),
                    'Month Bills',
                    0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildInfoCard(
                  isFamilySummaryLoading
                      ? "."
                      : formatCompactAmount(familyTotalAmount),
                  'Month Volume',
                  0,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Waiting For Approval navigation commented because
                    // this position now displays static Rank.
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => bdm_OrderList(
                    //       status: "Invoice Created",
                    //     ),
                    //   ),
                    // );
                  },
                  child: _buildInfoCard(
                    '0',
                    // 'Waiting For Approval',
                    'Rank',
                    0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Add today order page navigation if needed
                  },
                  child: _buildInfoCard(
                    isFamilySummaryLoading
                        ? "..."
                        : familyTodaysBills.toString(),
                    'Today Bills',
                    0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildInfoCard(
                  isFamilySummaryLoading
                      ? "."
                      : formatCompactAmount(familyTodaysTotalAmount),
                  'Today Volume',
                  0,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummaryChip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$title : $value",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAttendanceBodyCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSkeletonLine({
    double? width,
    double height = 14,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildTeamSummarySkeleton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonLine(width: 180, height: 18),
                  const SizedBox(height: 10),
                  _buildSkeletonLine(width: 130, height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSkeletonMetricCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSkeletonMetricCard()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSkeletonMetricCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSkeletonMetricCard()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSkeletonLine(width: 120, height: 14),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 170,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildSkeletonMemberCard(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonMetricCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonLine(width: 70, height: 16),
          const SizedBox(height: 8),
          _buildSkeletonLine(width: 90, height: 12),
        ],
      ),
    );
  }

  Widget _buildSkeletonMemberCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonLine(width: 140, height: 16),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSkeletonMiniStat()),
              const SizedBox(width: 8),
              Expanded(child: _buildSkeletonMiniStat()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSkeletonMiniStat()),
              const SizedBox(width: 8),
              Expanded(child: _buildSkeletonMiniStat()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonMiniStat() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonLine(width: 60, height: 14),
          const SizedBox(height: 6),
          _buildSkeletonLine(width: 70, height: 11),
        ],
      ),
    );
  }

  Widget _buildAttendanceTableSkeleton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSkeletonLine(width: 160, height: 16),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 110,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildSkeletonLine(height: 13)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSkeletonLine(height: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    5,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _buildSkeletonLine(height: 13)),
                            const SizedBox(width: 12),
                            Container(
                              width: 90,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAttendanceTableSection() {
    if (isTeamSummaryLoading) {
      return _buildTeamSummarySkeleton();
    }

    if (myTeamDetailedSummary.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text(
            "No attendance data available",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final teamData = myTeamDetailedSummary.first;
    final team = teamData["team"] ?? {};
    final members = List<Map<String, dynamic>>.from(teamData["members"] ?? []);

    int presentCount = 0;
    int absentCount = 0;
    int halfDayCount = 0;

    for (final member in members) {
      final status = getAttendanceStatus(member).toLowerCase();

      if (status == "present") {
        presentCount++;
      } else if (status == "half day") {
        halfDayCount++;
      } else {
        absentCount++;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${team["team_name"] ?? ""} - Attendance",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: pickTeamDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatDisplayDate(selectedTeamDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 6),
                // Text(
                //   "Date: ${formatDisplayDate(selectedTeamDate)}",
                //   style: const TextStyle(
                //     color: Colors.white70,
                //     fontSize: 12,
                //     fontWeight: FontWeight.w500,
                //   ),
                // ),
                const SizedBox(height: 10),
                // Wrap(
                //   spacing: 10,
                //   runSpacing: 10,
                //   children: [
                //     _buildAttendanceSummaryChip(
                //       "Present",
                //       "$presentCount",
                //       Colors.green,
                //     ),
                //     _buildAttendanceSummaryChip(
                //       "Absent",
                //       "$absentCount",
                //       Colors.red,
                //     ),
                //     _buildAttendanceSummaryChip(
                //       "Half Day",
                //       "$halfDayCount",
                //       Colors.orange,
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Table(
              border: TableBorder.all(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              columnWidths: const {
                0: FlexColumnWidth(2.4),
                1: FlexColumnWidth(1.4),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                  ),
                  children: [
                    _buildAttendanceHeaderCell("Staff Name"),
                    _buildAttendanceHeaderCell("Status"),
                  ],
                ),
                ...members.map((member) {
                  final status = getAttendanceStatus(member);

                  return TableRow(
                    children: [
                      _buildAttendanceBodyCell(
                        member["staff_name"]?.toString() ?? "-",
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: getAttendanceStatusColor(status)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: getAttendanceStatusColor(status),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> getprofiledata() async {
    try {
      final token = await getTokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        setState(() {
          family = productsData['family'].toString() ?? '';
          isManager = parsed['data']['is_manager'] ?? false;

          getGrvList();

          var matchingFamily = fam.firstWhere(
            (element) => element['id'].toString() == family,
            orElse: () => {'id': null, 'name': 'Unknown'},
          );

          // Store the matching family name
          familyName = matchingFamily['name'];
        });
        fetchbdmOrderData();
        getcustomer();
      }
    } catch (error) {}
  }

  Future<void> getfamily() async {
    try {
      final token = await getTokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/familys/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];
        List<Map<String, dynamic>> familylist = [];

        for (var productData in productsData) {
          familylist.add({
            'id': productData['id'].toString(), // Convert the ID to String
            'name': productData['name'],
          });
        }

        setState(() {
          fam = familylist;
        });
        await getprofiledata();
      }
    } catch (error) {}
  }

  Future<void> getcustomer() async {
    try {
      final token = await getTokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/customers/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];
        List<Map<String, dynamic>> managerlist = [];

        for (var productData in productsData) {
          if (familyName == productData['family']) {
            managerlist.add({
              'id': productData['id'],
              'name': productData['name'],
              'created_at': productData['created_at']
            });
          }
        }

        setState(() {
          customer = managerlist; // Update full customer list
          filteredProducts =
              List.from(customer); // Show all customers initially
        });
      }
    } catch (error) {}
  }

  // Variables to track the totals
  int totalOrdersToday = 0;
  int totalOrdersInvoiceCreated = 0;
  int Shippedorders = 0;
  // Variables to track the totals
  int todaysbill = 0;
  int shippedbills = 0;

  int waitingbills = 0;
  Future<void> fetchbdmOrderData() async {
    try {
      final token = await getTokenFromPrefs();

      String url = '$api/api/orders/';
      List<Map<String, dynamic>> orderList = [];

      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List ordersData = responseData['results'];

        List<Map<String, dynamic>> newOrders = [];

        DateTime currentDate = DateTime.now();
        String today = DateFormat('yyyy-MM-dd').format(currentDate);

        for (var orderData in ordersData) {
          String rawOrderDate = orderData['order_date'] ?? "";
          String formattedOrderDate = rawOrderDate;
          try {
            DateTime parsedOrderDate =
                DateFormat('yyyy-MM-dd').parse(rawOrderDate);
            formattedOrderDate =
                DateFormat('yyyy-MM-dd').format(parsedOrderDate);
          } catch (e) {}

          if (orderData['status'] != "Order Request by Warehouse") {
            if (familyName == orderData['family']) {
              newOrders.add({
                'id': orderData['id'],
                'family': orderData['family'],
                'invoice': orderData['invoice'],
                'manage_staff': orderData['manage_staff'],
                'customer': {
                  'id': orderData['customer']['id'],
                  'name': orderData['customer']['name'],
                  'phone': orderData['customer']['phone'],
                  'email': orderData['customer']['email'],
                  'address': orderData['customer']['address'],
                },
                'status': orderData['status'],
                'total_amount': orderData['total_amount'],
                'order_date': formattedOrderDate,
              });

              // Count orders for today
              if (formattedOrderDate == today) {
                totalOrdersToday++;
                totalAmountToday +=
                    double.tryParse(orderData['total_amount'].toString()) ??
                        0.0;
              }

              // Count orders with status "Invoice Created"
              if (orderData['status'] == "Invoice Created") {
                totalOrdersInvoiceCreated++;
              }
              if (formattedOrderDate == today &&
                  orderData['status'] == "Shipped") {
                Shippedorders++;
              }
            }
          }
        }

        setState(() {
          orders = newOrders;
          todaysbill = totalOrdersToday;
          waitingbills = totalOrdersInvoiceCreated;
          shippedbills = Shippedorders;
          filteredOrders = newOrders;
        });

        // Print the counts (or use them as needed)
      } else {
        throw Exception("Failed to load order data");
      }
    } catch (error) {}
  }

  Future<void> fetchOrderData() async {
    try {
      final token = await getTokenFromPrefs();
      var response = await http.get(
        Uri.parse('$api/api/orders/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed;
        List<Map<String, dynamic>> orderList = [];

        for (var productData in productsData) {
          String rawOrderDate = productData['order_date'];
          String formattedOrderDate = rawOrderDate;

          try {
            DateTime parsedOrderDate =
                DateFormat('yyyy-MM-dd').parse(rawOrderDate);
            formattedOrderDate = DateFormat('yyyy-MM-dd')
                .format(parsedOrderDate); // Convert to desired format
          } catch (e) {}

          orderList.add({
            'id': productData['id'],
            'invoice': productData['invoice'],
            'manage_staff': productData['manage_staff'],
            'customer': {
              'name': productData['customer']['name'],
              'phone': productData['customer']['phone'],
              'email': productData['customer']['email'],
              'address': productData['customer']['address'],
            },
            'billing_address': {
              'name': productData['billing_address']['name'],
              'email': productData['billing_address']['email'],
              'zipcode': productData['billing_address']['zipcode'],
              'address': productData['billing_address']['address'],
              'phone': productData['billing_address']['phone'],
              'city': productData['billing_address']['city'],
              'state': productData['billing_address']['state'],
            },
            'bank': {
              'name': productData['bank']['name'],
              'account_number': productData['bank']['account_number'],
              'ifsc_code': productData['bank']['ifsc_code'],
              'branch': productData['bank']['branch'],
            },
            'items': productData['items'] != null
                ? productData['items'].map((item) {
                    return {
                      'id': item['id'],
                      'name': item['name'],
                      'quantity': item['quantity'],
                      'price': item['price'],
                      'tax': item['tax'],
                      'discount': item['discount'],
                      'images': item['images'],
                    };
                  }).toList()
                : [],
            'status': productData['status'],
            'total_amount': productData['total_amount'],
            'order_date': formattedOrderDate, // Use the formatted string
          });
          if (productData['status'] == 'Invoice Created') {
            approval++;
          } else if (productData['status'] == 'Invoice Approved') {
            confirm++;
          }
        }

        // Filter orders by 'Shipped' status and today's date
        DateTime today = DateTime.now();
        String formattedToday = DateFormat('yyyy-MM-dd').format(today);

        var shippedOrdersToday = orderList.where((order) {
          return order['status'] == 'Shipped' &&
              order['order_date'] == formattedToday; // Match today's date
        }).toList();

        // Get the length of today's shipped orders

        setState(() {
          orders = orderList;
          filteredOrders = orderList;
          shippedOrders =
              shippedOrdersToday; // Set filtered today's shipped orders
        });
      }
    } catch (error) {}
  }

  Future<void> getSalesReport() async {
    setState(() {});
    try {
      final token = await getTokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/salesreport'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var salesData = parsed['Sales report'];

        List<Map<String, dynamic>> salesReportDataList = [];
        for (var reportData in salesData) {
          salesReportDataList.add({
            'date': reportData['date'],
            'total_bills_in_date': reportData['total_bills_in_date'],
            'amount': reportData['amount'],
            'approved': {
              'bills': reportData['approved']['bills'],
              'amount': reportData['approved']['amount']
            },
            'rejected': {
              'bills': reportData['rejected']['bills'],
              'amount': reportData['rejected']['amount']
            }
          });
        }

        setState(() {
          salesReportList = salesReportDataList;
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Failed to fetch sales report data'),
        //     duration: Duration(seconds: 2),
        //   ),
        // );
      }
    } catch (error) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Error fetching sales report data'),
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } finally {
      setState(() {});
    }
  }

  bool _isDisposed = false;


  String getTodaysBills() {
    // Get today's date in the same format as in the response (yyyy-MM-dd)
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Find today's report entry
    var todaysReport = salesReportList.firstWhere(
      (report) => report['date'] == currentDate,
      orElse: () => {}, // Return null if no report for today
    );

    if (todaysReport['total_bills_in_date'] != null) {
      return todaysReport['total_bills_in_date'].toString();
    } else {
      return '0'; // Return '0' if no report is found for today
    }
  }

  Future<void> fetchproformaData() async {
    try {
      final token = await getTokenFromPrefs();
      final response = await http.get(
        Uri.parse('$api/api/performa/invoice/staff/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final data = parsed['data'] as List;

        List<Map<String, dynamic>> performaInvoiceList = [];

        for (var productData in data) {
          performaInvoiceList.add({
            'id': productData['id'],
            'invoice': productData['invoice'],
            'manage_staff': productData['manage_staff'],
            'customer_name': productData['customermame'], // corrected key
            'status': productData['status'],
            'total_amount': productData['total_amount'],
            'order_date': productData['order_date'],
            'created_at':
                '', // No such key in your sample, use empty or handle differently
          });
        }

        if (mounted) {
          setState(() {
            proforma = performaInvoiceList;
          });
        }
      } else {}
    } catch (error) {}
  }

// Get token from SharedPreferences
  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getusernameFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  int grv = 0;
  var grvpending;
// Function to fetch GRV data
  Future<void> getGrvList() async {
    try {
      final token = await getTokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/grv/data/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        List<Map<String, dynamic>> grvDataList = [];
        int grv = 0;

        for (var productData in productsData) {
          if (family.toString() == productData['family'].toString()) {
            grvDataList.add({
              'id': productData['id'],
              'product': productData['product'],
              'returnreason': productData['returnreason'],
              'invoice': productData['invoice'],
              'customer': productData['customer'],
              'staff': productData['staff'],
              'remark': productData['remark'],
              'status': productData['status'] ?? statusOptions[0],
              'order_date': productData['order_date'],
            });
            if (productData['status'] == "pending") {
              grv = grv + 1;
            }
          }
        }

        if (mounted) {
          setState(() {
            grvlist = grvDataList;
            grvpending = grv;
          });
        }
      }
    } catch (error) {}
  }

  // Retrieve the username from SharedPreferences
  Future<void> _getUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final name = await getusernameFromPrefs();

    setState(() {
      username = name ?? 'Guest'; // Default to 'Guest' if no username
    });
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.remove('department');
    // await prefs.remove('token');
    //   await prefs.remove('username');

    // Use a post-frame callback to show the SnackBar after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ScaffoldMessenger.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged out successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    // Wait for the SnackBar to disappear before navigating
    await Future.delayed(Duration(seconds: 2));

    // Navigate to the HomePage after the snackbar is shown
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => login()),
    );
  }

  drower d = drower();

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
            d.navigateToSelectedPage3(context, option);
          },
        );
      }).toList(),
    );
  }

  Widget buildMyTeamSummarySection() {
    if (isTeamSummaryLoading) {
      return _buildTeamSummarySkeleton();
    }

    if (myTeamDetailedSummary.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text(
            "No team summary available",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final teamData = myTeamDetailedSummary.first;
    final team = Map<String, dynamic>.from(teamData["team"] ?? {});
    final summary = Map<String, dynamic>.from(teamData["summary"] ?? {});
    final members = List<Map<String, dynamic>>.from(teamData["members"] ?? []);

    Map<String, dynamic> teamHourlyDurations =
        Map<String, dynamic>.from(summary["hourly_durations"] ?? {});

    List<String> hourSlots = teamHourlyDurations.keys.toList();

    if (hourSlots.isEmpty && members.isNotEmpty) {
      final firstMemberSummary =
          Map<String, dynamic>.from(members.first["summary"] ?? {});
      teamHourlyDurations = Map<String, dynamic>.from(
        firstMemberSummary["hourly_durations"] ?? {},
      );
      hourSlots = teamHourlyDurations.keys.toList();
    }

    if (hourSlots.isEmpty) {
      hourSlots = [
        "09:00-10:00",
        "10:00-11:00",
        "11:00-12:00",
        "12:00-01:00",
        "01:00-02:00",
        "02:00-03:00",
        "03:00-04:00",
        "04:00-05:00",
        "05:00-06:00",
        "06:00-07:00",
      ];
    }

    final bool isHourlyFilterApplied =
        selectedHourSlot != null && selectedHourSlot!.isNotEmpty;

    final double teamDisplayDuration =
        (summary["total_call_duration"] ?? 0).toDouble();

    final String teamDurationTitle =
        isHourlyFilterApplied ? "Selected Hour CD" : "Total Team CD";

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        team["team_name"]?.toString() ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: pickTeamDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatDisplayDate(selectedTeamDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isHourlyFilterApplied
                      ? "Time Range: ${formatHourSlotLabel(selectedHourSlot!)}"
                      : "Full Day Summary",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        "Total Bill",
                        "${summary["total_bill"] ?? 0}",
                        Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        "Total Volume",
                        "${summary["total_volume"] ?? 0}",
                        Icons.inventory_2_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        teamDurationTitle,
                        "${formatDoubleValue(teamDisplayDuration)} mins",
                        Icons.call,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        "Average CD",
                        "${formatDoubleValue(summary["call_duration_average"] ?? 0)} mins",
                        Icons.av_timer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Team Members",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedHourSlot,
                          hint: const Text(
                            "Select Time Duration",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: "",
                              child: Text("Select Time Duration"),
                            ),
                            ...hourSlots.map((slot) {
                              return DropdownMenuItem<String>(
                                value: slot,
                                child: Text(formatHourSlotLabel(slot)),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              if (value == null || value.isEmpty) {
                                selectedHourSlot = null;
                              } else {
                                selectedHourSlot = value;
                              }
                            });

                            await fetchMyTeamDetailedSummary();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  itemCount: members.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final memberSummary =
                        Map<String, dynamic>.from(member["summary"] ?? {});
                    final attendanceSummary = Map<String, dynamic>.from(
                      member["attendance_summary"] ?? {},
                    );

                    final double memberDisplayDuration =
                        (memberSummary["total_call_duration"] ?? 0).toDouble();

                    final String memberDurationTitle =
                        isHourlyFilterApplied ? "Selected Hour CD" : "Total CD";

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${index + 1}. ${member["staff_name"] ?? ""}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniStat(
                                  memberDurationTitle,
                                  "${formatDoubleValue(memberDisplayDuration)} mins",
                                ),
                              ),
                              Expanded(
                                child: _buildMiniStat(
                                  "Calls",
                                  "${memberSummary["total_call_count"] ?? 0}",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniStat(
                                  "Bill",
                                  "${memberSummary["total_bill"] ?? 0}",
                                ),
                              ),
                              Expanded(
                                child: _buildMiniStat(
                                  "Volume",
                                  "${memberSummary["total_volume"] ?? 0}",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon(icon, color: Colors.blue, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }


  // ============================================================
  // SD DASHBOARD FRONT MENU
  // All drawer options are represented here as dashboard cards.
  // ============================================================

  List<Map<String, dynamic>> _getSdFrontMenuItems() {
    return [
      {
        'title': 'Attendance',
        'icon': Icons.fact_check_outlined,
        'groupType': 'attendanceManagement',
        'keywords':
            'attendance add attendance add attendance team add approve attendance',
      },

      // {
      //   'title': 'Add Attendance',
      //   'icon': Icons.person_outline_rounded,
      //   'keywords': 'attendance add attendance',
      // },

      {
        'title': 'Customers',
        'icon': Icons.people_alt_outlined,
        'groupType': 'customers',
        'keywords': 'customers add customer view customers',
      },
      {
        'title': 'Proforma Invoice',
        'icon': Icons.description_outlined,
        'groupType': 'proforma',
        'keywords':
            'proforma invoice new proforma invoice proforma invoice list orders list',
      },

      // {
      //   'title': 'Orders',
      //   'icon': Icons.receipt_long_outlined,
      //   'groupType': 'orders',
      //   'keywords': 'orders order list orders list shipped orders',
      // },

      {
        'title': 'BDO DSR',
        'icon': Icons.analytics_outlined,
        'groupType': 'bdoDsr',
        'keywords':
            'bdo dsr add team add team members view all team members approve bdo call duration',
      },

      // {
      //   'title': 'Communication',
      //   'icon': Icons.mail_outline_rounded,
      //   'groupType': 'communication',
      //   'keywords': 'send mail mail employee leave form leave',
      // },

      // if (isManager)
      //   {
      //     'title': 'BDO Approvals',
      //     'icon': Icons.verified_outlined,
      //     'groupType': 'bdoApprovals',
      //     'keywords': 'approve bdo call duration approval bdo',
      //   },

      {
        'title': 'Staff',
        'icon': Icons.groups_2_outlined,
        'keywords': 'staff view staffs team',
      },

      // {
      //   'title': 'Local Purchase Order',
      //   'icon': Icons.shopping_cart_checkout_rounded,
      //   'keywords': 'local purchase order lpo purchase',
      // },

      // Existing SD quick access retained in code, but card is commented.
      // {
      //   'title': 'Operations',
      //   'icon': Icons.dashboard_customize_outlined,
      //   'groupType': 'operations',
      //   'keywords':
      //       'shipped orders list bdo call list call duration operations',
      // },
    ];
  }

  List<Map<String, dynamic>> _getSdGroupItems(String groupType) {
    switch (groupType) {
      case 'customers':
        return [
          {
            'title': 'Add Customer',
            'icon': Icons.person_add_alt_1_outlined,
          },
          {
            'title': 'Customers',
            'icon': Icons.people_outline_rounded,
          },
        ];

      case 'proforma':
        return [
          {
            'title': 'New Proforma Invoice',
            'icon': Icons.note_add_outlined,
          },
          {
            'title': 'Proforma Invoice List',
            'icon': Icons.description_outlined,
          },
          {
            'title': 'Orders List',
            'icon': Icons.list_alt_rounded,
          },
        ];

      // case 'orders':
      //   return [
      //     {
      //       'title': 'Orders List',
      //       'icon': Icons.list_alt_rounded,
      //     },
      //   ];

      case 'bdoDsr':
        return [
          {
            'title': 'Add Team',
            'icon': Icons.group_add_outlined,
          },
          {
            'title': 'Add Team Members',
            'icon': Icons.person_add_alt_outlined,
          },
          {
            'title': 'View All Team Members',
            'icon': Icons.groups_outlined,
          },
          if (isManager)
            {
              'title': 'Approve BDO Call Duration',
              'icon': Icons.verified_outlined,
            },
        ];

      // case 'communication':
      //   return [
      //     {
      //       'title': 'Send Mail',
      //       'icon': Icons.mail_outline_rounded,
      //     },
      //     {
      //       'title': 'Employee Leave Form',
      //       'icon': Icons.event_note_outlined,
      //     },
      //   ];

      case 'attendanceManagement':
        return [
          {
            'title': 'Add Attendance',
            'icon': Icons.person_outline_rounded,
          },
          if (isManager)
            {
              'title': 'Add Attendance Team',
              'icon': Icons.people_alt_outlined,
            },
          if (isManager)
            {
              'title': 'Add & Approve Attendance',
              'icon': Icons.fact_check_outlined,
            },
        ];

      // case 'bdoApprovals':
      //   return [
      //     {
      //       'title': 'Approve BDO Call Duration',
      //       'icon': Icons.verified_outlined,
      //     },
      //   ];

      // case 'operations':
      //   return [
      //     {
      //       'title': 'BDO Call List',
      //       'icon': Icons.call_outlined,
      //     },
      //   ];

      default:
        return [];
    }
  }

  // ============================================================
  // DASHBOARD CARD NAVIGATION
  // ============================================================

  Future<void> _navigateFromFrontCard(String item) async {
    switch (item) {
      case 'Add Attendance':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffSelfAttendanceScreen(),
          ),
        );
        return;

      case 'Send Mail':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => const StaffMailPage(),
          ),
        );

        if (!mounted) return;
        await fetchInboxMailCount();
        return;

      case 'Add Attendance Team':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SDAllMembersPage(),
          ),
        );
        return;

      case 'Add & Approve Attendance':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const sdAllAttendanceAddPage(),
          ),
        );
        return;

      case 'Approve BDO Call Duration':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SdAllDsrReportPage(),
          ),
        );
        return;

      case 'Employee Leave Form':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeLeaveFormPage(),
          ),
        );
        return;

      case 'Staff':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => bdm_staff_list(
              family: familyName,
            ),
          ),
        );
        return;

      case 'Local Purchase Order':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalPurchaseOrderScreen(),
          ),
        );
        return;

      case 'Shipped Orders List':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => bdm_OrderList(
              status: 'Shipped',
            ),
          ),
        );
        return;

      case 'BDO Call List':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SdConfirmCallDuration(),
          ),
        );
        return;

      case 'Logout':
        await logoutUser(context);
        return;

      // These were dropdown entries in the original SD drawer.
      // Preserve the exact original navigation handler.
      case 'Add Customer':
      case 'Customers':
      case 'New Proforma Invoice':
      case 'Proforma Invoice List':
      case 'Orders List':
      case 'Add Team':
      case 'Add Team Members':
      case 'View All Team Members':
        d.navigateToSelectedPage3(
          context,
          item,
        );
        return;

      default:
        return;
    }
  }

  // ============================================================
  // SIMPLE BDO-STYLE FRONT MENU CARD
  // ============================================================

  Widget _buildFrontMenuCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF56AFFF),
                Color(0xFF2C74FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2C74FF).withOpacity(0.28),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withOpacity(0.92),
                      size: 18,
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
  // GROUPED BDO-STYLE MENU CARD
  // ============================================================

  Widget _buildGroupedMenuCard({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required bool isVerySmallPhone,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF56AFFF),
            Color(0xFF2C74FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C74FF).withOpacity(0.28),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(
          isVerySmallPhone ? 10 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmallPhone ? 11.5 : 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: isVerySmallPhone ? 32 : 34,
                  height: isVerySmallPhone ? 32 : 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isVerySmallPhone ? 18 : 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 4);
                },
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> menuItem = items[index];

                  final String itemTitle =
                      menuItem['title']?.toString() ?? '';

                  final IconData itemIcon =
                      menuItem['icon'] as IconData;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                        _navigateFromFrontCard(
                          itemTitle,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isVerySmallPhone ? 6 : 7,
                          vertical: isVerySmallPhone ? 5 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.11),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              itemIcon,
                              color: Colors.white,
                              size: isVerySmallPhone ? 13 : 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                itemTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      isVerySmallPhone ? 8.5 : 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withOpacity(0.90),
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FRONT MENU GRID
  // ============================================================

  Widget _buildFrontMenuSection() {
    final List<Map<String, dynamic>> items =
        _getSdFrontMenuItems();

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool isVerySmallPhone =
            constraints.maxWidth < 340;

        final double horizontalSpacing =
            isVerySmallPhone ? 8 : 12;

        final double verticalSpacing =
            isVerySmallPhone ? 8 : 12;

        final double cardHeight =
            isVerySmallPhone ? 195 : 210;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: horizontalSpacing,
            mainAxisSpacing: verticalSpacing,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final Map<String, dynamic> item =
                items[index];

            final String itemTitle =
                item['title']?.toString() ?? '';

            final IconData itemIcon =
                item['icon'] as IconData;

            final String? groupType =
                item['groupType']?.toString();

            if (groupType != null &&
                groupType.isNotEmpty) {
              return _buildGroupedMenuCard(
                title: itemTitle,
                icon: itemIcon,
                items: _getSdGroupItems(
                  groupType,
                ),
                isVerySmallPhone:
                    isVerySmallPhone,
              );
            }

            return _buildFrontMenuCard(
              title: itemTitle,
              icon: itemIcon,
              onTap: () {
                _navigateFromFrontCard(
                  itemTitle,
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DASHBOARD SEARCH RESULTS
  // ============================================================

  Widget _buildDashboardSearchResults() {
    final String query =
        dashboardSearchQuery.trim().toLowerCase();

    final List<Map<String, dynamic>> matchedItems =
        _getSdFrontMenuItems().where(
      (Map<String, dynamic> item) {
        final String title =
            item['title']?.toString().toLowerCase() ?? '';

        final String keywords =
            item['keywords']?.toString().toLowerCase() ?? '';

        if (title.contains(query) ||
            keywords.contains(query)) {
          return true;
        }

        final String? groupType =
            item['groupType']?.toString();

        if (groupType != null &&
            groupType.isNotEmpty) {
          return _getSdGroupItems(groupType).any(
            (groupItem) => (groupItem['title']
                        ?.toString()
                        .toLowerCase() ??
                    '')
                .contains(query),
          );
        }

        return false;
      },
    ).toList();

    if (matchedItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 52,
          horizontal: 24,
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(0xFF8E8E93),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No cards found',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool isVerySmallPhone =
            constraints.maxWidth < 340;

        final double horizontalSpacing =
            isVerySmallPhone ? 8 : 12;

        final double verticalSpacing =
            isVerySmallPhone ? 8 : 12;

        final double cardHeight =
            isVerySmallPhone ? 195 : 210;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matchedItems.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: horizontalSpacing,
            mainAxisSpacing: verticalSpacing,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final Map<String, dynamic> item =
                matchedItems[index];

            final String itemTitle =
                item['title']?.toString() ?? '';

            final IconData itemIcon =
                item['icon'] as IconData;

            final String? groupType =
                item['groupType']?.toString();

            if (groupType != null &&
                groupType.isNotEmpty) {
              return _buildGroupedMenuCard(
                title: itemTitle,
                icon: itemIcon,
                items: _getSdGroupItems(
                  groupType,
                ),
                isVerySmallPhone:
                    isVerySmallPhone,
              );
            }

            return _buildFrontMenuCard(
              title: itemTitle,
              icon: itemIcon,
              onTap: () {
                _navigateFromFrontCard(
                  itemTitle,
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BOTTOM SEARCH
  // ============================================================

  void _toggleBottomSearch() {
    final bool shouldOpen =
        !isBottomSearchOpen;

    setState(() {
      isBottomSearchOpen = shouldOpen;

      if (!shouldOpen) {
        dashboardSearchQuery = '';
        dashboardSearchController.clear();
      }
    });

    if (shouldOpen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (!mounted) return;
          dashboardSearchFocusNode.requestFocus();
        },
      );
    } else {
      dashboardSearchFocusNode.unfocus();
    }
  }

  void _closeBottomSearch() {
    if (!isBottomSearchOpen &&
        dashboardSearchController.text.isEmpty &&
        dashboardSearchQuery.isEmpty) {
      return;
    }

    dashboardSearchFocusNode.unfocus();

    setState(() {
      isBottomSearchOpen = false;
      dashboardSearchQuery = '';
      dashboardSearchController.clear();
    });
  }

  // ============================================================
  // BOTTOM NAVIGATION ACTIONS
  // ============================================================

  Future<void> _openBottomMail() async {
    _closeBottomSearch();

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const StaffMailPage(),
      ),
    );

    if (!mounted) return;
    await fetchInboxMailCount();
  }

  void _openBottomProfile() {
    _closeBottomSearch();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(),
      ),
    );
  }

  // ============================================================
  // MODERN BOTTOM NAVIGATION - SAME BDO DESIGN
  // ============================================================

  Widget _buildModernBottomNavigationBar() {
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Material(
        color: Colors.white,
        elevation: 14,
        shadowColor: Colors.black.withOpacity(0.10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 68,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 7,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBottomNavigationItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      isSelected: false,
                      onTap: _openBottomProfile,
                    ),
                  ),
                  Expanded(
                    child: _buildBottomNavigationItem(
                      icon: Icons.mail_outline_rounded,
                      label: 'Mail',
                      isSelected: false,
                      badgeCount: inboxMailCount,
                      onTap: () {
                        _openBottomMail();
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildBottomNavigationItem(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      isSelected: isBottomSearchOpen,
                      onTap: _toggleBottomSearch,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 220,
              ),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isBottomSearchOpen
                  ? Padding(
                      key: const ValueKey<String>(
                        'sd-dashboard-search-open',
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        9,
                        12,
                        4,
                      ),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5E5EA),
                          ),
                        ),
                        child: TextField(
                          controller:
                              dashboardSearchController,
                          focusNode:
                              dashboardSearchFocusNode,
                          textInputAction:
                              TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (String value) {
                            setState(() {
                              dashboardSearchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search cards',
                            hintStyle: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF8E8E93),
                              size: 22,
                            ),
                            suffixIcon:
                                dashboardSearchQuery.isNotEmpty
                                    ? IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          dashboardSearchController
                                              .clear();

                                          setState(() {
                                            dashboardSearchQuery =
                                                '';
                                          });

                                          dashboardSearchFocusNode
                                              .requestFocus();
                                        },
                                        icon: const Icon(
                                          Icons.cancel_rounded,
                                          color: Color(0xFF8E8E93),
                                          size: 20,
                                        ),
                                      )
                                    : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>(
                        'sd-dashboard-search-closed',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final Color foregroundColor =
        isSelected
            ? const Color(0xFF2C74FF)
            : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    width: 36,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEAF2FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: foregroundColor,
                      size: 23,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -7,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          badgeCount > 99
                              ? '99+'
                              : badgeCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 10.5,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BDO-STYLE SUMMARY CARD
  // Existing SD summary data retained.
  // ============================================================

  Widget _buildSdSummaryCard() {
    Widget buildInfo(
      String value,
      String label,
    ) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: buildInfo(
                  isFamilySummaryLoading
                      ? '...'
                      : familyTotalBills.toString(),
                  'Month Bills',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: buildInfo(
                  isFamilySummaryLoading
                      ? '...'
                      : formatCompactAmount(
                          familyTotalAmount,
                        ),
                  'Month Volume',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: buildInfo(
                  // isFamilySummaryLoading
                  //     ? '...'
                  //     : familyInvoiceCreatedBills
                  //         .toString(),
                  '0',
                  // 'Waiting For Approval',
                  'Rank',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: buildInfo(
                  isFamilySummaryLoading
                      ? '...'
                      : familyTodaysBills.toString(),
                  'Today Bills',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: buildInfo(
                  isFamilySummaryLoading
                      ? '...'
                      : formatCompactAmount(
                          familyTodaysTotalAmount,
                        ),
                  'Today Volume',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: buildInfo(
                  '0',
                  'Points',
                ),
              ),
            ],
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.only(
                right: 12,
              ),
              child: IconButton(
                tooltip: 'Logout',
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.black,
                  size: 27,
                ),
                onPressed: () async {
                  await logoutUser(context);
                },
              ),
            ),
          ],
        ),

        // ======================================================
        // DRAWER COMMENTED.
        // Every functional option from the old drawer is now
        // available through the dashboard cards above.
        // ======================================================
        // drawer: Drawer(...),

        bottomNavigationBar:
            _buildModernBottomNavigationBar(),

        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: refreshDashboardData,
            color: Colors.blue,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProfileScreen(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor:
                              const Color(0xFFE5E7EB),
                          backgroundImage:
                              getProfileImageUrl().isNotEmpty
                                  ? NetworkImage(
                                      getProfileImageUrl(),
                                    )
                                  : const AssetImage(
                                      'lib/assets/female.jpeg',
                                    ) as ImageProvider,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '$username',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _buildSdSummaryCard(),

                  const SizedBox(height: 14),

                  if (isBottomSearchOpen &&
                      dashboardSearchQuery
                          .trim()
                          .isNotEmpty)
                    _buildDashboardSearchResults()
                  else
                    _buildFrontMenuSection(),

                  const SizedBox(height: 10),

                  // ==================================================
                  // Existing large team summary / attendance sections
                  // are intentionally not rendered here so the SD
                  // dashboard follows the same compact BDO dashboard
                  // design. Their methods and API logic remain intact.
                  // ==================================================
                  // buildMyTeamSummarySection(),
                  // buildAttendanceTableSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
