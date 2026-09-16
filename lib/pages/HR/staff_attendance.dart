import 'dart:convert';

import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/HR/hr_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HrTeamAttendanceScreen extends StatefulWidget {
  const HrTeamAttendanceScreen({super.key});

  @override
  State<HrTeamAttendanceScreen> createState() => _HrTeamAttendanceScreenState();
}

class _HrTeamAttendanceScreenState extends State<HrTeamAttendanceScreen> {
  // ---------------------------------------------------------------------------
  // ATTENDANCE DATA
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> attendanceTeams = [];

  // ---------------------------------------------------------------------------
  // FILTER DATA
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> filterTeams = [];
  List<Map<String, dynamic>> membersData = [];

  String? selectedTeamId;
  String? selectedMemberId;

  DateTime? startDate;
  DateTime? endDate;

  // ---------------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------------

  bool isLoading = false;
  bool isFilterLoading = false;

  // ---------------------------------------------------------------------------
  // DATE FORMATTERS
  // ---------------------------------------------------------------------------

  String formatApiDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  String get formattedStartDate {
    if (startDate == null) return '';
    return formatApiDate(startDate!);
  }

  String get formattedEndDate {
    if (endDate == null) return '';
    return formatApiDate(endDate!);
  }

  // ---------------------------------------------------------------------------
  // TOKEN
  // ---------------------------------------------------------------------------

  Future<String?> getTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await Future.wait([
        fetchTeams(),
        fetchMembers(),
      ]);

      await getAllAttendance();
    });
  }

  // ---------------------------------------------------------------------------
  // COMMON RESPONSE ARRAY CONVERTER
  // ---------------------------------------------------------------------------

  List<dynamic> toArray(dynamic payload) {
    if (payload is List) {
      return payload;
    }

    if (payload is Map<String, dynamic>) {
      if (payload['data'] is List) {
        return List.from(payload['data']);
      }

      if (payload['results'] is List) {
        return List.from(payload['results']);
      }

      if (payload['results'] is Map<String, dynamic>) {
        final results = payload['results'];

        if (results['data'] is List) {
          return List.from(results['data']);
        }
      }
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // TEAM MAPPER
  // ---------------------------------------------------------------------------

  Map<String, dynamic> mapTeamItem(dynamic item) {
    if (item is! Map) {
      return {};
    }

    return {
      'id': item['id'] ?? item['team_id'],
      'team_name': item['team_name'] ?? item['name'] ?? '',
      'team_leader': item['team_leader'],
      'team_leader_name': item['team_leader_name'] ??
          item['leader_name'] ??
          item['team_leader_name_display'] ??
          '',
    };
  }

  // ---------------------------------------------------------------------------
  // MEMBER TEAM MAPPER
  // ---------------------------------------------------------------------------

  Map<String, dynamic> mapMemberTeam(dynamic team) {
    if (team is! Map) {
      return {};
    }

    final List rawMembers =
        team['members'] is List ? List.from(team['members']) : [];

    return {
      'team_id': team['team_id'] ?? team['id'],
      'team_name': team['team_name'] ?? '',
      'team_leader': team['team_leader'],
      'team_leader_name': team['team_leader_name'] ?? '',
      'is_team_leader': team['is_team_leader'] ?? false,
      'members_count': team['members_count'] ?? rawMembers.length,
      'members': rawMembers.map<Map<String, dynamic>>((member) {
        return {
          'id': member['id'],
          'team': member['team'] ?? team['team_id'] ?? team['id'],
          'team_name': member['team_name'] ?? team['team_name'] ?? '',
          'member': member['member'] ?? member['member_id'],
          'member_name': member['member_name'] ?? '',
          'created_at': member['created_at'],
        };
      }).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // FETCH DEPARTMENTS / TEAMS
  // ---------------------------------------------------------------------------

  Future<void> fetchTeams() async {
    try {
      final token = await getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception("Token missing");
      }

      final response = await http.get(
        Uri.parse('$api/api/staff/attendance/teams/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("FILTER TEAMS STATUS: ${response.statusCode}");
      debugPrint("FILTER TEAMS RESPONSE: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);

        final List<Map<String, dynamic>> list = toArray(body)
            .map<Map<String, dynamic>>(mapTeamItem)
            .where((item) => item.isNotEmpty)
            .toList();

        if (!mounted) return;

        setState(() {
          filterTeams = list;
        });
      } else {
        throw Exception(
          "Failed to fetch teams: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("FETCH TEAMS ERROR: $e");

      if (mounted) {
        showMsg("Failed to load departments");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FETCH TEAM MEMBERS
  // ---------------------------------------------------------------------------

  Future<void> fetchMembers() async {
    try {
      final token = await getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception("Token missing");
      }

      final response = await http.get(
        Uri.parse('$api/api/staff/attendance/team/members/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("FILTER MEMBERS STATUS: ${response.statusCode}");
      debugPrint("FILTER MEMBERS RESPONSE: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);

        final List<Map<String, dynamic>> list = toArray(body)
            .map<Map<String, dynamic>>(mapMemberTeam)
            .where((item) => item.isNotEmpty)
            .toList();

        if (!mounted) return;

        setState(() {
          membersData = list;
        });
      } else {
        throw Exception(
          "Failed to fetch members: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("FETCH MEMBERS ERROR: $e");

      if (mounted) {
        showMsg("Failed to load members");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MEMBERS OF SELECTED DEPARTMENT
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get filteredMembers {
    if (selectedTeamId == null || selectedTeamId!.isEmpty) {
      return [];
    }

    final Map<String, dynamic> selectedTeamData = membersData.firstWhere(
      (team) =>
          team['team_id']?.toString() == selectedTeamId.toString(),
      orElse: () => <String, dynamic>{},
    );

    if (selectedTeamData.isEmpty) {
      return [];
    }

    final dynamic rawMembers = selectedTeamData['members'];

    if (rawMembers is! List) {
      return [];
    }

    return rawMembers
        .map<Map<String, dynamic>>(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // SELECTED STAFF NAME
  // ---------------------------------------------------------------------------

  String get selectedMemberName {
    if (selectedMemberId == null || selectedMemberId!.isEmpty) {
      return '';
    }

    for (final member in filteredMembers) {
      if (member['member']?.toString() == selectedMemberId.toString()) {
        return member['member_name']?.toString() ?? '';
      }
    }

    return '';
  }

  // ---------------------------------------------------------------------------
  // PERSON ATTENDANCE SUMMARY
  // ---------------------------------------------------------------------------

  bool get canShowPersonSummary {
    return selectedTeamId != null &&
        selectedTeamId!.isNotEmpty &&
        selectedMemberId != null &&
        selectedMemberId!.isNotEmpty &&
        startDate != null &&
        endDate != null &&
        !isLoading;
  }

  List<Map<String, dynamic>> get selectedPersonAttendanceRecords {
    final List<Map<String, dynamic>> records = [];

    if (selectedMemberId == null || selectedMemberId!.isEmpty) {
      return records;
    }

    final String memberId = selectedMemberId!;
    final String memberName = selectedMemberName.trim().toLowerCase();

    for (final team in attendanceTeams) {
      final List dateWiseAttendance =
          List.from(team['date_wise_attendance'] ?? []);

      for (final dateItem in dateWiseAttendance) {
        final List attendanceList =
            List.from(dateItem['attendance'] ?? []);

        for (final attendanceItem in attendanceList) {
          if (attendanceItem is! Map) {
            continue;
          }

          final Map<String, dynamic> attendance =
              Map<String, dynamic>.from(attendanceItem);

          final dynamic possibleStaffId =
              attendance['staff'] ??
              attendance['staff_id'] ??
              attendance['member'] ??
              attendance['member_id'];

          final String staffName =
              attendance['staff_name']?.toString().trim().toLowerCase() ?? '';

          bool belongsToSelectedMember = false;

          if (possibleStaffId != null) {
            belongsToSelectedMember =
                possibleStaffId.toString() == memberId;
          }

          if (!belongsToSelectedMember &&
              memberName.isNotEmpty &&
              staffName.isNotEmpty) {
            belongsToSelectedMember = staffName == memberName;
          }

          if (!belongsToSelectedMember &&
              possibleStaffId == null &&
              staffName.isEmpty) {
            belongsToSelectedMember = true;
          }

          if (!belongsToSelectedMember &&
              possibleStaffId == null &&
              memberName.isEmpty) {
            belongsToSelectedMember = true;
          }

          if (belongsToSelectedMember) {
            records.add({
              ...attendance,
              '_attendance_date': dateItem['attendance_date'],
            });
          }
        }
      }
    }

    return records;
  }

  // ---------------------------------------------------------------------------
  // PRESENT DAYS
  // ---------------------------------------------------------------------------

  int get personPresentDays {
    final Set<String> dates = {};

    for (final attendance in selectedPersonAttendanceRecords) {
      final String status =
          attendance['status']?.toString().trim().toLowerCase() ?? '';

      if (status == 'present') {
        final String date =
            attendance['_attendance_date']?.toString() ?? '';

        if (date.isNotEmpty) {
          dates.add(date);
        }
      }
    }

    return dates.length;
  }

  // ---------------------------------------------------------------------------
  // ABSENT DAYS
  // ---------------------------------------------------------------------------

  int get personAbsentDays {
    final Set<String> dates = {};

    for (final attendance in selectedPersonAttendanceRecords) {
      final String status =
          attendance['status']?.toString().trim().toLowerCase() ?? '';

      if (status == 'absent') {
        final String date =
            attendance['_attendance_date']?.toString() ?? '';

        if (date.isNotEmpty) {
          dates.add(date);
        }
      }
    }

    return dates.length;
  }

  // ---------------------------------------------------------------------------
  // HALF DAYS
  // ---------------------------------------------------------------------------

  int get personHalfDayDays {
    final Set<String> dates = {};

    for (final attendance in selectedPersonAttendanceRecords) {
      final String status =
          attendance['status']?.toString().trim().toLowerCase() ?? '';

      if (status == 'half_day') {
        final String date =
            attendance['_attendance_date']?.toString() ?? '';

        if (date.isNotEmpty) {
          dates.add(date);
        }
      }
    }

    return dates.length;
  }

  // ---------------------------------------------------------------------------
  // TOTAL WORKING DAYS
  // ---------------------------------------------------------------------------

  int get personTotalWorkingDays {
    final Set<String> dates = {};

    for (final attendance in selectedPersonAttendanceRecords) {
      final String status =
          attendance['status']?.toString().trim().toLowerCase() ?? '';

      final String date =
          attendance['_attendance_date']?.toString() ?? '';

      if (date.isEmpty) {
        continue;
      }

      if (status == 'present' ||
          status == 'absent' ||
          status == 'half_day') {
        dates.add(date);
      }
    }

    return dates.length;
  }

  // ---------------------------------------------------------------------------
  // FETCH ATTENDANCE
  // ---------------------------------------------------------------------------

  Future<void> getAllAttendance() async {
    try {
      if (!mounted) return;

      setState(() {
        isLoading = true;
      });

      final token = await getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        throw Exception("Token missing");
      }

      final Map<String, String> queryParameters = {};

      if (startDate != null) {
        queryParameters['start_date'] = formattedStartDate;
      }

      if (endDate != null) {
        queryParameters['end_date'] = formattedEndDate;
      }

      if (selectedTeamId != null && selectedTeamId!.isNotEmpty) {
        queryParameters['team'] = selectedTeamId!;
      }

      if (selectedMemberId != null && selectedMemberId!.isNotEmpty) {
        queryParameters['member'] = selectedMemberId!;
      }

      final uri = Uri.parse(
        '$api/api/staff/attendance/',
      ).replace(
        queryParameters:
            queryParameters.isEmpty ? null : queryParameters,
      );

      debugPrint("==================================================");
      debugPrint("HR ATTENDANCE REQUEST URL:");
      debugPrint(uri.toString());
      debugPrint("==================================================");

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
        "HR ATTENDANCE STATUS: ${response.statusCode}",
      );

      debugPrint(
        "HR ATTENDANCE RESPONSE: ${response.body}",
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final dynamic parsed = jsonDecode(response.body);

        List<dynamic> data = [];

        if (parsed is Map<String, dynamic>) {
          if (parsed['results'] is Map<String, dynamic>) {
            final results = parsed['results'];

            if (results['data'] is List) {
              data = List.from(results['data']);
            }
          } else if (parsed['data'] is List) {
            data = List.from(parsed['data']);
          } else if (parsed['results'] is List) {
            data = List.from(parsed['results']);
          }
        } else if (parsed is List) {
          data = List.from(parsed);
        }

        final List<Map<String, dynamic>> mappedTeams =
            data.map<Map<String, dynamic>>((team) {
          return {
            'team_id': team['team_id'] ?? team['id'],
            'team_name':
                team['team_name'] ?? team['name'] ?? '',
            'team_leader': team['team_leader'],
            'team_leader_name':
                team['team_leader_name'] ?? '',
            'members_count': team['members_count'] ?? 0,
            'date_wise_attendance':
                List.from(
              team['date_wise_attendance'] ?? [],
            ),
          };
        }).toList();

        if (!mounted) return;

        setState(() {
          attendanceTeams = mappedTeams;
        });

        debugPrint("==================================================");
        debugPrint("SELECTED STAFF: $selectedMemberName");
        debugPrint("SELECTED MEMBER ID: $selectedMemberId");
        debugPrint("PRESENT DAYS: $personPresentDays");
        debugPrint("ABSENT DAYS: $personAbsentDays");
        debugPrint("HALF DAYS: $personHalfDayDays");
        debugPrint("TOTAL WORKING DAYS: $personTotalWorkingDays");
        debugPrint("==================================================");
      } else {
        debugPrint(
          "ATTENDANCE ERROR RESPONSE: ${response.body}",
        );

        throw Exception(
          "Failed attendance request: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("HR attendance fetch error: $e");

      if (mounted) {
        showMsg("Failed to fetch attendance");
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // APPLY FILTER
  // ---------------------------------------------------------------------------

  Future<void> applyFilter() async {
    if (startDate != null &&
        endDate != null &&
        endDate!.isBefore(startDate!)) {
      showMsg("End date cannot be before start date");
      return;
    }

    if (selectedMemberId != null &&
        selectedMemberId!.isNotEmpty &&
        (selectedTeamId == null || selectedTeamId!.isEmpty)) {
      showMsg("Please select department first");
      return;
    }

    try {
      if (!mounted) return;

      setState(() {
        isFilterLoading = true;
      });

      await getAllAttendance();
    } finally {
      if (mounted) {
        setState(() {
          isFilterLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RESET FILTER
  // ---------------------------------------------------------------------------

  Future<void> resetFilter() async {
    setState(() {
      selectedTeamId = null;
      selectedMemberId = null;
      startDate = null;
      endDate = null;
    });

    await getAllAttendance();
  }

  // ---------------------------------------------------------------------------
  // START DATE
  // ---------------------------------------------------------------------------

  Future<void> pickStartDate() async {
    final DateTime initialDate =
        startDate ?? endDate ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      startDate = pickedDate;

      if (endDate != null &&
          endDate!.isBefore(pickedDate)) {
        endDate = pickedDate;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // END DATE
  // ---------------------------------------------------------------------------

  Future<void> pickEndDate() async {
    final DateTime initialDate =
        endDate ?? startDate ?? DateTime.now();

    final DateTime firstSelectableDate =
        startDate ?? DateTime(2020);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isBefore(firstSelectableDate)
              ? firstSelectableDate
              : initialDate,
      firstDate: firstSelectableDate,
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      endDate = pickedDate;
    });
  }

  // ---------------------------------------------------------------------------
  // PICK DATE RANGE FROM APPBAR
  // ---------------------------------------------------------------------------

  Future<void> pickAttendanceDateRange() async {
    final now = DateTime.now();

    final DateTimeRange? pickedRange =
        await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange:
          startDate != null && endDate != null
              ? DateTimeRange(
                  start: startDate!,
                  end: endDate!,
                )
              : DateTimeRange(
                  start: now,
                  end: now,
                ),
    );

    if (pickedRange == null) {
      return;
    }

    setState(() {
      startDate = pickedRange.start;
      endDate = pickedRange.end;
    });

    await applyFilter();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    return prefs.getString('department');
  }

  Future<void> _navigateBack() async {
    final dep = await getdepFromPrefs();

    if (!mounted) return;

    if (dep == "BDO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => bdo_dashbord(),
        ),
      );
    } else if (dep == "BDM") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => bdm_dashbord(),
        ),
      );
    } else if (dep == "HR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HrDashboard(),
        ),
      );
    } else if (dep == "warehouse") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WarehouseDashboard(),
        ),
      );
    } else if (dep == "CEO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ceo_dashboard(),
        ),
      );
    } else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => cso_dashboard(),
        ),
      );
    } else if (dep == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ceo_dashboard(),
        ),
      );
    } else if (dep == "Warehouse Admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WarehouseAdmin(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => dashboard(),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  void showMsg(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  String getStatusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Present';

      case 'absent':
        return 'Absent';

      case 'half_day':
        return 'Half Day';

      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xff16a34a);

      case 'absent':
        return const Color(0xffdc2626);

      case 'half_day':
        return const Color(0xfff59e0b);

      default:
        return const Color(0xff64748b);
    }
  }

  // ---------------------------------------------------------------------------
  // APPROVAL
  // ---------------------------------------------------------------------------

  String getApprovalLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'pending':
        return 'Pending';

      default:
        return status;
    }
  }

  Color getApprovalColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xff16a34a);

      case 'rejected':
        return const Color(0xffdc2626);

      case 'pending':
        return const Color(0xfff59e0b);

      default:
        return const Color(0xff64748b);
    }
  }

  // ---------------------------------------------------------------------------
  // TOTAL COUNTS
  // ---------------------------------------------------------------------------

  int get totalPresent {
    int count = 0;

    for (final team in attendanceTeams) {
      final List dateWiseAttendance =
          List.from(
        team['date_wise_attendance'] ?? [],
      );

      for (final dateItem in dateWiseAttendance) {
        count += int.tryParse(
              '${dateItem['present_count'] ?? 0}',
            ) ??
            0;
      }
    }

    return count;
  }

  int get totalAbsent {
    int count = 0;

    for (final team in attendanceTeams) {
      final List dateWiseAttendance =
          List.from(
        team['date_wise_attendance'] ?? [],
      );

      for (final dateItem in dateWiseAttendance) {
        count += int.tryParse(
              '${dateItem['absent_count'] ?? 0}',
            ) ??
            0;
      }
    }

    return count;
  }

  int get totalHalfDay {
    int count = 0;

    for (final team in attendanceTeams) {
      final List dateWiseAttendance =
          List.from(
        team['date_wise_attendance'] ?? [],
      );

      for (final dateItem in dateWiseAttendance) {
        count += int.tryParse(
              '${dateItem['half_day_count'] ?? 0}',
            ) ??
            0;
      }
    }

    return count;
  }

  int get totalMarked {
    int count = 0;

    for (final team in attendanceTeams) {
      final List dateWiseAttendance =
          List.from(
        team['date_wise_attendance'] ?? [],
      );

      for (final dateItem in dateWiseAttendance) {
        count += int.tryParse(
              '${dateItem['total_count'] ?? 0}',
            ) ??
            0;
      }
    }

    return count;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef3f9),

      // -----------------------------------------------------------------------
      // APP BAR
      // -----------------------------------------------------------------------

      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
          onPressed: _navigateBack,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "Attendance",
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Select Date Range",
            onPressed: pickAttendanceDateRange,
            icon: const Icon(
              Icons.date_range_outlined,
            ),
          ),
          IconButton(
            tooltip: "Refresh",
            onPressed: getAllAttendance,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // BODY
      // -----------------------------------------------------------------------

      body: RefreshIndicator(
        onRefresh: getAllAttendance,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // -----------------------------------------------------------------
              // FILTER
              // -----------------------------------------------------------------

              _buildFilterCard(),

              // -----------------------------------------------------------------
              // PERSON SUMMARY
              // -----------------------------------------------------------------

              if (canShowPersonSummary) ...[
                const SizedBox(height: 14),
                _buildPersonSummaryCard(),
              ],

              const SizedBox(height: 14),

              // _buildSummaryCard(),

              // -----------------------------------------------------------------
              // DATA
              // -----------------------------------------------------------------

              isLoading
                  ? const Padding(
                      padding:
                          EdgeInsets.only(top: 60),
                      child: Center(
                        child:
                            CircularProgressIndicator(),
                      ),
                    )
                  : attendanceTeams.isEmpty
                      ? _buildEmptyCard(
                          "No attendance data found",
                        )
                      : Column(
                          children:
                              attendanceTeams.map<Widget>(
                            (team) {
                              return _buildTeamAttendanceCard(
                                team,
                              );
                            },
                          ).toList(),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PERSON ATTENDANCE SUMMARY CARD
  // ---------------------------------------------------------------------------

  Widget _buildPersonSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff2563eb),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Staff Attendance Summary",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selectedMemberName.isEmpty
                          ? "Selected Staff"
                          : selectedMemberName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.date_range_outlined,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "$formattedStartDate  to  $formattedEndDate",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // -------------------------------------------------------------------
          // PRESENT + ABSENT
          // -------------------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: _buildPersonSummaryTile(
                  title: "Present",
                  value: personPresentDays,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPersonSummaryTile(
                  title: "Absent",
                  value: personAbsentDays,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // -------------------------------------------------------------------
          // HALF DAY + TOTAL WORKING DAYS
          // -------------------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: _buildPersonSummaryTile(
                  title: "Half Day",
                  value: personHalfDayDays,
                  icon: Icons.timelapse_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPersonSummaryTile(
                  title: "Total Working Days",
                  value: personTotalWorkingDays,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonSummaryTile({
    required String title,
    required int value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
          const SizedBox(height: 6),
          Text(
            "$value",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER CARD
  // ---------------------------------------------------------------------------

  Widget _buildFilterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                color: Color(0xff2563eb),
              ),
              SizedBox(width: 8),
              Text(
                "Filter Attendance",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // -------------------------------------------------------------------
          // DEPARTMENT
          // -------------------------------------------------------------------

          const Text(
            "Department",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xff475569),
            ),
          ),

          const SizedBox(height: 6),

          DropdownButtonFormField<String>(
            value: selectedTeamId,
            isExpanded: true,
            decoration:
                _filterInputDecoration(
              "Select Department",
              Icons.groups_outlined,
            ),
            items:
                filterTeams.map((team) {
              return DropdownMenuItem<String>(
                value:
                    team['id']?.toString(),
                child: Text(
                  team['team_name']
                          ?.toString() ??
                      '',
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedTeamId = value;

                selectedMemberId = null;
              });
            },
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // STAFF
          // -------------------------------------------------------------------

          const Text(
            "Staff",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xff475569),
            ),
          ),

          const SizedBox(height: 6),

          DropdownButtonFormField<String>(
            value: selectedMemberId,
            isExpanded: true,
            decoration:
                _filterInputDecoration(
              selectedTeamId == null
                  ? "Select Department First"
                  : "Select Staff",
              Icons.person_outline,
            ),
            items:
                filteredMembers.map((member) {
              return DropdownMenuItem<String>(
                value: member['member']
                    ?.toString(),
                child: Text(
                  member['member_name']
                          ?.toString() ??
                      '',
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged:
                selectedTeamId == null
                    ? null
                    : (value) {
                        setState(() {
                          selectedMemberId =
                              value;
                        });
                      },
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // DATE RANGE
          // -------------------------------------------------------------------

          LayoutBuilder(
            builder:
                (context, constraints) {
              if (constraints.maxWidth <
                  560) {
                return Column(
                  children: [
                    _buildDateField(
                      title: "Start Date",
                      value:
                          formattedStartDate,
                      hint:
                          "Select Start Date",
                      onTap:
                          pickStartDate,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    _buildDateField(
                      title: "End Date",
                      value:
                          formattedEndDate,
                      hint:
                          "Select End Date",
                      onTap:
                          pickEndDate,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child:
                        _buildDateField(
                      title:
                          "Start Date",
                      value:
                          formattedStartDate,
                      hint:
                          "Select Start Date",
                      onTap:
                          pickStartDate,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child:
                        _buildDateField(
                      title: "End Date",
                      value:
                          formattedEndDate,
                      hint:
                          "Select End Date",
                      onTap:
                          pickEndDate,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // -------------------------------------------------------------------
          // BUTTONS
          // -------------------------------------------------------------------

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      isFilterLoading
                          ? null
                          : resetFilter,
                  icon: const Icon(
                    Icons.restart_alt,
                  ),
                  label: const Text(
                    "Reset",
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    minimumSize:
                        const Size(
                      double.infinity,
                      48,
                    ),
                    foregroundColor:
                        const Color(
                      0xff475569,
                    ),
                    side: const BorderSide(
                      color:
                          Color(
                        0xffcbd5e1,
                      ),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 2,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      isFilterLoading
                          ? null
                          : applyFilter,
                  icon: isFilterLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.search,
                        ),
                  label: Text(
                    isFilterLoading
                        ? "Loading..."
                        : "Apply Filter",
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    minimumSize:
                        const Size(
                      double.infinity,
                      48,
                    ),
                    backgroundColor:
                        const Color(
                      0xff2563eb,
                    ),
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
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
  // FILTER INPUT DECORATION
  // ---------------------------------------------------------------------------

  InputDecoration _filterInputDecoration(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xff94a3b8),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: const Color(0xff64748b),
      ),
      filled: true,
      fillColor: const Color(0xfff8fafc),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xffe2e8f0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xffe2e8f0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xff2563eb),
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xffe2e8f0),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DATE FIELD
  // ---------------------------------------------------------------------------

  Widget _buildDateField({
    required String title,
    required String value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xff475569),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(12),
          child: Container(
            height: 50,
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color:
                  const Color(0xfff8fafc),
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color:
                    const Color(
                  0xffe2e8f0,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .calendar_today_outlined,
                  size: 19,
                  color:
                      Color(0xff64748b),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value.isEmpty
                        ? hint
                        : value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                      color: value.isEmpty
                          ? const Color(
                              0xff94a3b8,
                            )
                          : const Color(
                              0xff111827,
                            ),
                    ),
                  ),
                ),
                if (value.isNotEmpty)
                  const Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                    color:
                        Color(0xff94a3b8),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY CARD
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff2563eb),
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            "Attendance Summary",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(
                Icons.date_range_outlined,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                startDate != null ||
                        endDate != null
                    ? "${formattedStartDate.isEmpty ? '-' : formattedStartDate} to ${formattedEndDate.isEmpty ? '-' : formattedEndDate}"
                    : "All Dates",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  "Marked",
                  "$totalMarked",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  "Present",
                  "$totalPresent",
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  "Absent",
                  "$totalAbsent",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  "Half Day",
                  "$totalHalfDay",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY TILE
  // ---------------------------------------------------------------------------

  Widget _buildSummaryTile(
    String title,
    String value,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.14),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              Colors.white.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEAM ATTENDANCE CARD
  // ---------------------------------------------------------------------------

  Widget _buildTeamAttendanceCard(
    Map<String, dynamic> team,
  ) {
    final List dateWiseAttendance =
        List.from(
      team['date_wise_attendance'] ?? [],
    );

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // TEAM HEADER
          // -------------------------------------------------------------------

          Row(
            children: [
              const CircleAvatar(
                backgroundColor:
                    Color(0xffeff6ff),
                child: Icon(
                  Icons.groups_outlined,
                  color:
                      Color(0xff2563eb),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  team['team_name']
                          ?.toString() ??
                      '',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        Color(0xff111827),
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(
                    0xffdbeafe,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  "${team['members_count'] ?? 0} Members",
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xff1d4ed8,
                    ),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // -------------------------------------------------------------------
          // LEADER
          // -------------------------------------------------------------------

          Container(
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  const Color(0xfff8fafc),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_pin_outlined,
                  size: 18,
                  color:
                      Color(0xff64748b),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Leader: ${team['team_leader_name'] ?? ''}",
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xff334155,
                      ),
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // DATE RANGE RESULT
          // -------------------------------------------------------------------

          dateWiseAttendance.isEmpty
              ? const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  child: Text(
                    "No attendance found for selected filters",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                )
              : Column(
                  children:
                      dateWiseAttendance
                          .map<Widget>(
                    (dateAttendance) {
                      return _buildDateAttendanceSection(
                        dateAttendance,
                      );
                    },
                  ).toList(),
                ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ONE DATE ATTENDANCE SECTION
  // ---------------------------------------------------------------------------

  Widget _buildDateAttendanceSection(
    dynamic dateAttendance,
  ) {
    final List attendanceList =
        List.from(
      dateAttendance['attendance'] ?? [],
    );

    final int presentCount =
        int.tryParse(
              '${dateAttendance['present_count'] ?? 0}',
            ) ??
            0;

    final int absentCount =
        int.tryParse(
              '${dateAttendance['absent_count'] ?? 0}',
            ) ??
            0;

    final int halfDayCount =
        int.tryParse(
              '${dateAttendance['half_day_count'] ?? 0}',
            ) ??
            0;

    final int totalCount =
        int.tryParse(
              '${dateAttendance['total_count'] ?? 0}',
            ) ??
            0;

    final String attendanceDate =
        dateAttendance['attendance_date']
                ?.toString() ??
            '-';

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffafcff),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffe5e7eb),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // DATE
          // -------------------------------------------------------------------

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 17,
                color: Color(0xff2563eb),
              ),
              const SizedBox(width: 7),
              Text(
                attendanceDate,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      Color(0xff111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // -------------------------------------------------------------------
          // COUNTS
          // -------------------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: _buildCountChip(
                  "Present",
                  presentCount,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCountChip(
                  "Absent",
                  absentCount,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCountChip(
                  "Half",
                  halfDayCount,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCountChip(
                  "Total",
                  totalCount,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Text(
            "Members Attendance",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xff111827),
            ),
          ),

          const SizedBox(height: 8),

          attendanceList.isEmpty
              ? const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  child: Text(
                    "No attendance found",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                )
              : Column(
                  children:
                      attendanceList
                          .map<Widget>(
                    (attendance) {
                      return _buildMemberAttendanceTile(
                        Map<String, dynamic>.from(
                          attendance,
                        ),
                      );
                    },
                  ).toList(),
                ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COUNT CHIP
  // ---------------------------------------------------------------------------

  Widget _buildCountChip(
    String title,
    int count,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffe5e7eb),
        ),
      ),
      child: Column(
        children: [
          Text(
            "$count",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xff111827),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xff64748b),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MEMBER ATTENDANCE TILE
  // ---------------------------------------------------------------------------

  Widget _buildMemberAttendanceTile(
    Map<String, dynamic> attendance,
  ) {
    final String status =
        attendance['status']
                ?.toString() ??
            '';

    final String approvalStatus =
        attendance['approval_status']
                ?.toString() ??
            'pending';

    return Container(
      margin:
          const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffe5e7eb),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor:
                Color(0xffeff6ff),
            child: Icon(
              Icons.person_outline,
              size: 18,
              color: Color(0xff2563eb),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  attendance['staff_name']
                          ?.toString() ??
                      '',
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Time: ${attendance['attendance_time'] ?? '-'}",
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xff64748b),
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              // ---------------------------------------------------------------
              // STATUS
              // ---------------------------------------------------------------

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      getStatusColor(status)
                          .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  getStatusLabel(status),
                  style: TextStyle(
                    color:
                        getStatusColor(
                      status,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // ---------------------------------------------------------------
              // APPROVAL STATUS
              // ---------------------------------------------------------------

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      getApprovalColor(
                    approvalStatus,
                  ).withOpacity(
                    0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  border: Border.all(
                    color:
                        getApprovalColor(
                      approvalStatus,
                    ).withOpacity(
                      0.35,
                    ),
                  ),
                ),
                child: Text(
                  getApprovalLabel(
                    approvalStatus,
                  ),
                  style: TextStyle(
                    color:
                        getApprovalColor(
                      approvalStatus,
                    ),
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w900,
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
  // EMPTY CARD
  // ---------------------------------------------------------------------------

  Widget _buildEmptyCard(
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            color: Colors.grey,
            size: 46,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}