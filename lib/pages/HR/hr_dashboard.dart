import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:beposoft/pages/ACCOUNTS/add_self_attendance.dart';
import 'package:beposoft/pages/ACCOUNTS/mailboxpage..dart';
import 'package:beposoft/pages/ADMIN/add_attendance.dart';
import 'package:beposoft/pages/ADMIN/all_local_purchases_screen.dart';
import 'package:beposoft/pages/ADMIN/localpurchaseorderscreen.dart';
import 'package:beposoft/pages/BDO/EmployeeLeaveFormPage%20.dart';
import 'package:beposoft/pages/api.dart';
import 'package:beposoft/pages/auth_status_checker.dart';
import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/Staff_exit_form_page.dart';
import 'package:beposoft/pages/ACCOUNTS/add_staff.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/profilepage.dart';
import 'package:beposoft/pages/ACCOUNTS/staff_exit_form_list.dart';
import 'package:beposoft/pages/ACCOUNTS/view_staff.dart';
import 'package:beposoft/pages/HR/EmployeeLeaveListPage.dart';
import 'package:beposoft/pages/HR/add_teamlead.dart';
import 'package:beposoft/pages/HR/attendance.dart';
import 'package:beposoft/pages/HR/staff_attendance.dart';
import 'package:beposoft/pages/logout_hekper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class HrDashboard extends StatefulWidget {
  const HrDashboard({super.key});

  @override
  State<HrDashboard> createState() => _HrDashboardState();
}

class _HrDashboardState extends State<HrDashboard>
    with WidgetsBindingObserver {
        String? username = '';
  int inboxMailCount = 0;
      String profileImage = '';
            bool isManager = false;
            bool isFetchingInboxMailCount = false;


Timer? mailCountTimer;

  bool isBottomSearchOpen = false;
  String dashboardSearchQuery = '';
  final TextEditingController dashboardSearchController = TextEditingController();
  final FocusNode dashboardSearchFocusNode = FocusNode();

  // ============================================================
  // CEO EMPLOYEES + ATTENDANCE CARD DATA
  // ============================================================
  double todayAttendancePercentage = 0.0;
  double monthAttendancePercentage = 0.0;

  int teamWiseTotalPresent = 0;
  int teamWiseTotalTeams = 0;
  int teamWiseTotalMembers = 0;
  int teamWiseGrandTotal = 0;
  int teamWiseTotalAbsent = 0;
  int teamWiseTotalHalfDay = 0;

  List<Map<String, dynamic>> departmentAttendanceCards = [];
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addObserver(this);

  _getUsername();
  fetchInboxMailCount();
  getProfile();
  fetchTeamWiseAttendanceCount();

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
  Future<String?> getusernameFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  // Retrieve the username from SharedPreferences
  Future<void> _getUsername() async {
    final name = await getusernameFromPrefs();
    setState(() {
      username = name ?? 'Guest'; // Default to 'Guest' if no username
    });
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
  // Get token from SharedPreferences
  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

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
  WidgetsBinding.instance.removeObserver(this);
  mailCountTimer?.cancel();
  dashboardSearchController.dispose();
  dashboardSearchFocusNode.dispose();
  super.dispose();
}
  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> fetchTeamWiseAttendanceCount() async {
    try {
      final String? token = await getTokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        debugPrint("TEAM ATTENDANCE: Token not found");
        return;
      }

      final DateTime now = DateTime.now();
      final String today = DateFormat('yyyy-MM-dd').format(now);
      final String monthStart = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, now.month, 1));

      final Uri todayUri = Uri.parse(
        '$api/api/staff/attendance/team/wise/count/',
      ).replace(
        queryParameters: {
          'start_date': today,
          'end_date': today,
        },
      );

      final Uri monthUri = Uri.parse(
        '$api/api/staff/attendance/team/wise/count/',
      ).replace(
        queryParameters: {
          'start_date': monthStart,
          'end_date': today,
        },
      );

      debugPrint("TODAY ATTENDANCE URL: $todayUri");
      debugPrint("MONTH ATTENDANCE URL: $monthUri");

      final List<http.Response> responses = await Future.wait([
        http.get(
          todayUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
        http.get(
          monthUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ]);

      final http.Response todayResponse = responses[0];
      final http.Response monthResponse = responses[1];

      debugPrint(
        "TODAY ATTENDANCE STATUS: ${todayResponse.statusCode}",
      );
      debugPrint(
        "TODAY ATTENDANCE BODY: ${todayResponse.body}",
      );
      debugPrint(
        "MONTH ATTENDANCE STATUS: ${monthResponse.statusCode}",
      );
      debugPrint(
        "MONTH ATTENDANCE BODY: ${monthResponse.body}",
      );

      if (todayResponse.statusCode != 200) {
        debugPrint(
          "TODAY ATTENDANCE FAILED: "
          "${todayResponse.statusCode} ${todayResponse.body}",
        );
        return;
      }

      final dynamic todayDecoded = jsonDecode(todayResponse.body);

      final Map<String, dynamic> todayParsed =
          todayDecoded is Map<String, dynamic>
              ? todayDecoded
              : Map<String, dynamic>.from(todayDecoded as Map);

      final Map<String, dynamic> todaySummary =
          todayParsed['summary'] is Map
              ? Map<String, dynamic>.from(todayParsed['summary'])
              : <String, dynamic>{};

      final List<dynamic> todayData =
          todayParsed['data'] is List
              ? List<dynamic>.from(todayParsed['data'])
              : <dynamic>[];

      double fetchedMonthAttendancePercentage = 0.0;

      if (monthResponse.statusCode == 200) {
        final dynamic monthDecoded = jsonDecode(monthResponse.body);

        final Map<String, dynamic> monthParsed =
            monthDecoded is Map<String, dynamic>
                ? monthDecoded
                : Map<String, dynamic>.from(monthDecoded as Map);

        final Map<String, dynamic> monthSummary =
            monthParsed['summary'] is Map
                ? Map<String, dynamic>.from(monthParsed['summary'])
                : <String, dynamic>{};

        fetchedMonthAttendancePercentage = _asDouble(
          monthSummary['attendance_percentage'],
        );
      } else {
        debugPrint(
          "MONTH ATTENDANCE FAILED: "
          "${monthResponse.statusCode} ${monthResponse.body}",
        );
      }

      int salesPresent = 0;
      int salesAbsent = 0;
      int salesHalfDay = 0;

      final List<Map<String, dynamic>> cards = [];

      for (final dynamic rawItem in todayData) {
        if (rawItem is! Map) continue;

        final Map<String, dynamic> item =
            Map<String, dynamic>.from(rawItem);

        final String teamName =
            (item['team_name'] ?? '').toString().trim();

        final String upperName = teamName.toUpperCase();

        final int present = _asInt(item['present_count']);
        final int absent = _asInt(item['absent_count']);
        final int halfDay = _asInt(item['half_day_count']);

        if (upperName.startsWith('SALES DEPARTMENT')) {
          salesPresent += present;
          salesAbsent += absent;
          salesHalfDay += halfDay;
        } else {
          cards.add({
            'title': teamName,
            'present': present,
            'absent': absent,
            'half_day': halfDay,
          });
        }
      }

      cards.insert(0, {
        'title': 'SALES DEPARTMENT',
        'present': salesPresent,
        'absent': salesAbsent,
        'half_day': salesHalfDay,
      });

      if (!mounted) return;

      setState(() {
        teamWiseTotalTeams = _asInt(todaySummary['total_teams']);
        teamWiseTotalMembers = _asInt(todaySummary['total_members']);
        teamWiseTotalPresent = _asInt(todaySummary['total_present']);
        teamWiseTotalAbsent = _asInt(todaySummary['total_absent']);
        teamWiseTotalHalfDay = _asInt(todaySummary['total_half_day']);
        teamWiseGrandTotal = _asInt(todaySummary['grand_total']);

        todayAttendancePercentage = _asDouble(
          todaySummary['attendance_percentage'],
        );

        monthAttendancePercentage =
            fetchedMonthAttendancePercentage;

        departmentAttendanceCards = cards;
      });

      debugPrint(
        "TODAY ATTENDANCE PERCENTAGE: "
        "$todayAttendancePercentage",
      );

      debugPrint(
        "MONTH ATTENDANCE PERCENTAGE: "
        "$monthAttendancePercentage",
      );
    } catch (error, stackTrace) {
      debugPrint(
        "TEAM WISE ATTENDANCE COUNT ERROR: $error",
      );
      debugPrintStack(stackTrace: stackTrace);
    }
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
            d.navigateToSelectedPage(context, option);
          },
        );
      }).toList(),
    );
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.remove('userId');
    // await prefs.remove('token');

    // Show the SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged out successfully'),
        duration: Duration(seconds: 2),
      ),
    );

    // Wait for the SnackBar to disappear before navigating
    await Future.delayed(Duration(seconds: 2));

    // Navigate to the HomePage after the snackbar is shown
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => login()),
    );
  }

  drower d = drower();
  // ============================================================
  // CEO-STYLE EMPLOYEES + ATTENDANCE CARDS
  // ============================================================

  Widget _buildEmployeeColumnItem({
    required String title,
    required String value,
    required IconData icon,
    bool isGreen = false,
  }) {
    return Container(
      width: double.infinity,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: isGreen ? Colors.green : Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGreen
              ? Colors.white.withOpacity(0.35)
              : Colors.white.withOpacity(0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 11,
                fontWeight: isGreen ? FontWeight.w800 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isGreen ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTeamContainer({
    required String teamName,
    required int present,
    required int absent,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              teamName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "P: $present",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            "A: $absent",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _teamShortName(String teamName) {
    final String cleanName = teamName.trim();

    if (cleanName.isEmpty) return "-";

    final List<String> words = cleanName
        .split(RegExp(r'\s+'))
        .where((String item) => item.isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return "${words[0][0]}${words[1][0]}".toUpperCase();
    }

    return cleanName.length >= 2
        ? cleanName.substring(0, 2).toUpperCase()
        : cleanName.toUpperCase();
  }

  Widget _buildCeoStyleDashboardCard({
    required String title,
    required String value,
    required VoidCallback onTap,
    Widget? bottom,
    bool greenValueTab = false,
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
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 13),
                if (value.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    height: 32,
                    padding: EdgeInsets.symmetric(
                      horizontal: greenValueTab ? 9 : 0,
                    ),
                    decoration: greenValueTab
                        ? BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                            ),
                          )
                        : null,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    child: bottom ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesCard() {
    return _buildCeoStyleDashboardCard(
      title: "Employees",
      value: "Total $teamWiseTotalMembers",
      greenValueTab: true,
      bottom: Column(
        children: [
          _buildEmployeeColumnItem(
            title: "Present",
            value: "$teamWiseTotalPresent",
            icon: Icons.person_pin_circle_rounded,
          ),
          const SizedBox(height: 6),
          _buildEmployeeColumnItem(
            title: "Absent",
            value: "$teamWiseTotalAbsent",
            icon: Icons.cancel_rounded,
          ),
          const SizedBox(height: 6),
          _buildEmployeeColumnItem(
            title: "Half Day",
            value: "$teamWiseTotalHalfDay",
            icon: Icons.access_time_filled_rounded,
          ),
          const SizedBox(height: 6),
          _buildEmployeeColumnItem(
            title: "T Att. %",
            value: "${todayAttendancePercentage.toStringAsFixed(2)}%",
            icon: Icons.today_rounded,
            isGreen: true,
          ),
          const SizedBox(height: 6),
          _buildEmployeeColumnItem(
            title: "M Att. %",
            value: "${monthAttendancePercentage.toStringAsFixed(2)}%",
            icon: Icons.calendar_month_rounded,
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => staff_list(),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceSummaryCard() {
    return _buildCeoStyleDashboardCard(
      title: "Attendance",
      value: "",
      bottom: departmentAttendanceCards.isEmpty
          ? const Text(
              "Loading attendance...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            )
          : Column(
              children:
                  departmentAttendanceCards.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, dynamic> item = entry.value;

                final String originalName =
                    item['title'].toString();

                final String displayName = index == 1
                    ? originalName
                        .substring(
                          0,
                          originalName.length >= 3
                              ? 3
                              : originalName.length,
                        )
                        .toUpperCase()
                    : _teamShortName(originalName);

                return _buildAttendanceTeamContainer(
                  teamName: displayName,
                  present: _asInt(item['present']),
                  absent: _asInt(item['absent']),
                );
              }).toList(),
            ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HrTeamAttendanceScreen(),
          ),
        );
      },
    );
  }

  Widget _buildCeoEmployeeAttendanceSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isVerySmallPhone = constraints.maxWidth < 340;

        final double horizontalSpacing =
            isVerySmallPhone ? 8 : 12;

        final double verticalSpacing =
            isVerySmallPhone ? 8 : 12;

        // EXACTLY SAME CARD HEIGHT AS BDO DASHBOARD
        final double cardHeight =
            isVerySmallPhone ? 195 : 210;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: horizontalSpacing,
            mainAxisSpacing: verticalSpacing,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildEmployeesCard();
            }

            return _buildAttendanceSummaryCard();
          },
        );
      },
    );
  }

  double _dashboardGridSpacing(BuildContext context) {
    return MediaQuery.of(context).size.width < 340 ? 8 : 12;
  }

  // ============================================================
  // HR DASHBOARD FRONT MENU
  // ============================================================

  List<Map<String, dynamic>> _getHrFrontMenuItems() {
    return [
      {
        'title': 'Attendance Management',
        'icon': Icons.fact_check_outlined,
        'groupType': 'attendance',
        'keywords':
            'attendance add your attendance approve your team attendance '
            'add department managers add dept-wise staffs '
            'add approve all attendance view attendance',
      },
      {
        'title': 'Staff Management',
        'icon': Icons.groups_2_outlined,
        'groupType': 'staff',
        'keywords':
            'staff staffs staff management staff list view staffs employees '
            'add staff employee create staff add staff exit form '
            'employee exit resignation staff exit form list',
      },

      // ======================================================
      // EMPLOYEE LEAVE OPTIONS COMMENTED AS REQUESTED
      // ======================================================
      // {
      //   'title': 'Employee Leave List',
      //   'icon': Icons.event_note_outlined,
      //   'keywords': 'employee leave list leave requests',
      // },
      // {
      //   'title': 'Employee Leave Form',
      //   'icon': Icons.edit_calendar_outlined,
      //   'keywords': 'employee leave form apply leave',
      // },

      {
        'title': 'Local Purchase Orders',
        'icon': Icons.shopping_cart_checkout_rounded,
        'groupType': 'localPurchase',
        'keywords':
            'local purchase order local purchase orders lpo purchase '
            'add local purchase order all local purchase orders',
      },
    ];
  }

  List<Map<String, dynamic>> _getHrGroupItems(String groupType) {
    switch (groupType) {
      case 'attendance':
        return [
          {
            'title': 'Add Your Attendance',
            'icon': Icons.person_outline_rounded,
          },
          {
            'title': 'Approve Your Team Attendance',
            'icon': Icons.fact_check_outlined,
          },
          {
            'title': 'Add Department & Managers',
            'icon': Icons.account_tree_outlined,
          },
          {
            'title': 'Add Dept-wise Staffs',
            'icon': Icons.groups_outlined,
          },
          {
            'title': 'Add & Approve All Attendance',
            'icon': Icons.playlist_add_check_circle_outlined,
          },
          {
            'title': 'View Attendance',
            'icon': Icons.calendar_month_outlined,
          },
        ];

      case 'staff':
        return [
          {
            'title': 'Staffs',
            'icon': Icons.groups_2_outlined,
          },
          {
            'title': 'Add Staff',
            'icon': Icons.person_add_alt_1_outlined,
          },
          {
            'title': 'Add Staff Exit Form',
            'icon': Icons.exit_to_app_rounded,
          },
          {
            'title': 'Staff Exit Form List',
            'icon': Icons.list_alt_rounded,
          },
        ];

      case 'localPurchase':
        return [
          {
            'title': 'Add Local Purchase Order',
            'icon': Icons.shopping_cart_checkout_rounded,
          },
          {
            'title': 'All Local Purchase Orders',
            'icon': Icons.inventory_2_outlined,
          },
        ];

      default:
        return [];
    }
  }

  Future<void> _navigateFromFrontCard(String item) async {
    switch (item) {
      case 'Staffs':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => staff_list()),
        );
        return;

      case 'Add Staff':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => add_staff()),
        );
        return;

      case 'Add Staff Exit Form':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmployeeExitFormPage()),
        );
        return;

      case 'Staff Exit Form List':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmployeeExitListPage()),
        );
        return;
// 
      // case 'Employee Leave List':
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(builder: (_) => EmployeeLeaveListPage()),
      //   );
      //   return;// 
      // case 'Employee Leave Form':
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(builder: (_) => EmployeeLeaveFormPage()),
      //   );
      //   return;
      case 'Add Local Purchase Order':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LocalPurchaseOrderScreen()),
        );
        return;

      case 'All Local Purchase Orders':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AllLocalPurchaseOrderScreen()),
        );
        return;

      case 'Add Your Attendance':
      case 'Approve Your Team Attendance':
      case 'Add Department & Managers':
      case 'Add Dept-wise Staffs':
      case 'Add & Approve All Attendance':
      case 'View Attendance':
        d.navigateToSelectedPage(context, item);
        return;

      default:
        d.navigateToSelectedPage(context, item);
        return;
    }
  }

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
              colors: [Color(0xFF56AFFF), Color(0xFF2C74FF)],
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
                      child: Icon(icon, color: Colors.white, size: 19),
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
          colors: [Color(0xFF56AFFF), Color(0xFF2C74FF)],
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
        padding: EdgeInsets.all(isVerySmallPhone ? 10 : 12),
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
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final String itemTitle = item['title']?.toString() ?? '';
                  final IconData itemIcon = item['icon'] as IconData;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => _navigateFromFrontCard(itemTitle),
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
                                  fontSize: isVerySmallPhone ? 8.5 : 9.5,
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

  Widget _buildFrontMenuSection({List<Map<String, dynamic>>? sourceItems}) {
    final items = sourceItems ?? _getHrFrontMenuItems();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isVerySmallPhone = constraints.maxWidth < 340;

        final double horizontalSpacing =
            isVerySmallPhone ? 8 : 12;

        final double verticalSpacing =
            isVerySmallPhone ? 8 : 12;

        // EXACTLY SAME CARD HEIGHT AS BDO DASHBOARD
        final double cardHeight =
            isVerySmallPhone ? 195 : 210;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: horizontalSpacing,
            mainAxisSpacing: verticalSpacing,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final String title = item['title']?.toString() ?? '';
            final IconData icon = item['icon'] as IconData;
            final String? groupType = item['groupType']?.toString();

            if (groupType != null && groupType.isNotEmpty) {
              return _buildGroupedMenuCard(
                title: title,
                icon: icon,
                items: _getHrGroupItems(groupType),
                isVerySmallPhone: isVerySmallPhone,
              );
            }

            return _buildFrontMenuCard(
              title: title,
              icon: icon,
              onTap: () => _navigateFromFrontCard(title),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardSearchResults() {
    final String query = dashboardSearchQuery.trim().toLowerCase();

    final matchedItems = _getHrFrontMenuItems().where((item) {
      final String title = item['title']?.toString().toLowerCase() ?? '';
      final String keywords = item['keywords']?.toString().toLowerCase() ?? '';
      return title.contains(query) || keywords.contains(query);
    }).toList();

    if (matchedItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
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
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return _buildFrontMenuSection(sourceItems: matchedItems);
  }

  void _toggleBottomSearch() {
    final bool shouldOpen = !isBottomSearchOpen;

    setState(() {
      isBottomSearchOpen = shouldOpen;
      if (!shouldOpen) {
        dashboardSearchQuery = '';
        dashboardSearchController.clear();
      }
    });

    if (shouldOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        dashboardSearchFocusNode.requestFocus();
      });
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

  Future<void> _openBottomMail() async {
    _closeBottomSearch();

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const StaffMailPage()),
    );

    if (!mounted) return;
    await fetchInboxMailCount();
  }

  void _openBottomProfile() {
    _closeBottomSearch();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen()),
    );
  }

  Widget _buildBottomNavigationItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final Color foregroundColor = isSelected
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
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEAF2FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: foregroundColor, size: 23),
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
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
                      onTap: () => _openBottomMail(),
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
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isBottomSearchOpen
                  ? Padding(
                      key: const ValueKey<String>('dashboard-search-open'),
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 4),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        child: TextField(
                          controller: dashboardSearchController,
                          focusNode: dashboardSearchFocusNode,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (value) {
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
                            suffixIcon: dashboardSearchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      dashboardSearchController.clear();
                                      setState(() {
                                        dashboardSearchQuery = '';
                                      });
                                      dashboardSearchFocusNode.requestFocus();
                                    },
                                    icon: const Icon(
                                      Icons.cancel_rounded,
                                      color: Color(0xFF8E8E93),
                                      size: 20,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>('dashboard-search-closed'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PULL TO REFRESH
  // ============================================================

  Future<void> _refreshDashboard() async {
    dashboardSearchFocusNode.unfocus();

    if (mounted) {
      setState(() {
        isBottomSearchOpen = false;
        dashboardSearchQuery = '';
        dashboardSearchController.clear();
      });
    }

    await Future.wait<void>([
      _getUsername(),
      fetchInboxMailCount(),
      getProfile(),
      fetchTeamWiseAttendanceCount(),
    ]);
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
              padding: const EdgeInsets.only(right: 12),
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
        // DRAWER COMMENTED AS REQUESTED
        // ======================================================
        // drawer: Drawer(
        //   backgroundColor: Colors.white,
        //   child: ...
        // ),

        bottomNavigationBar: _buildModernBottomNavigationBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: getProfileImageUrl().isNotEmpty
                              ? NetworkImage(getProfileImageUrl())
                              : const AssetImage('lib/assets/female.jpeg')
                                  as ImageProvider,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isBottomSearchOpen &&
                      dashboardSearchQuery.trim().isNotEmpty)
                    _buildDashboardSearchResults()
                  else ...[
                    _buildCeoEmployeeAttendanceSection(),
                    SizedBox(
                      height: _dashboardGridSpacing(context),
                    ),
                    _buildFrontMenuSection(),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
