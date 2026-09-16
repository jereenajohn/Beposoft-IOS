import 'dart:convert';
import 'dart:io';


import 'package:beposoft/pages/api.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffMonthlySalaryReportPage extends StatefulWidget {
  const StaffMonthlySalaryReportPage({super.key});

  @override
  State<StaffMonthlySalaryReportPage> createState() =>
      _StaffMonthlySalaryReportPageState();
}

class _StaffMonthlySalaryReportPageState
    extends State<StaffMonthlySalaryReportPage> {
  // ============================================================
  // REACT PAGE STATE EQUIVALENTS
  // ============================================================

  List<Map<String, dynamic>> salaryList = [];
  List<Map<String, dynamic>> staffList = [];

  bool loading = false;
  bool staffLoading = false;
  bool excelExporting = false;
  bool pdfExporting = false;

  String error = '';

  late int selectedYear;
  late int selectedMonth;
  int? selectedStaffId;

  late final List<int> years;

  final List<Map<String, dynamic>> months = const [
    {'value': 1, 'label': 'January'},
    {'value': 2, 'label': 'February'},
    {'value': 3, 'label': 'March'},
    {'value': 4, 'label': 'April'},
    {'value': 5, 'label': 'May'},
    {'value': 6, 'label': 'June'},
    {'value': 7, 'label': 'July'},
    {'value': 8, 'label': 'August'},
    {'value': 9, 'label': 'September'},
    {'value': 10, 'label': 'October'},
    {'value': 11, 'label': 'November'},
    {'value': 12, 'label': 'December'},
  ];

  // Horizontal controller is useful for the React-equivalent wide table.
  final ScrollController _tableHorizontalController = ScrollController();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedYear = now.year;
    selectedMonth = now.month;

    // React:
    // for (year = currentYear - 10; year <= currentYear + 1; year++)
    years = List.generate(
      12,
      (index) => now.year - 10 + index,
    );

    _initialLoad();
  }

  Future<void> _initialLoad() async {
    // React performs both requests on mount.
    await Future.wait([
      fetchStaff(),
      fetchMonthlySalary(),
    ]);
  }

  // ============================================================
  // AUTH
  // ============================================================

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    debugPrint(
      'AUTH TOKEN: ${token == null || token.isEmpty ? 'MISSING' : 'AVAILABLE'}',
    );

    return token;
  }

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // ============================================================
  // STAFF API
  // React: GET `${baseUrl}staffs/`
  // Response: response.data.data
  // ============================================================

  Future<void> fetchStaff() async {
    if (mounted) {
      setState(() {
        staffLoading = true;
      });
    }

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found.');
      }

      final uri = Uri.parse('${api}/api/staffs/');

      debugPrint('========== FETCH STAFF ==========');
      debugPrint('GET $uri');

      final response = await http.get(
        uri,
        headers: _headers(token),
      );

      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('BODY: ${response.body}');
      debugPrint('=================================');

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractMessage(
            decoded,
            fallback: 'Failed to fetch staff list.',
          ),
        );
      }

      final rawData = decoded is Map ? decoded['data'] : null;

      final parsedStaff = <Map<String, dynamic>>[];

      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map) {
            parsedStaff.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (!mounted) return;

      setState(() {
        staffList = parsedStaff;

        // If selected staff disappears from the latest staff response,
        // clear the local filter rather than retaining an invalid ID.
        if (selectedStaffId != null &&
            !staffList.any(
              (staff) => _toInt(staff['id']) == selectedStaffId,
            )) {
          selectedStaffId = null;
        }
      });
    } catch (e, stackTrace) {
      debugPrint('STAFF FETCH ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        staffList = [];
        selectedStaffId = null;
      });

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          staffLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MONTHLY SALARY API
  // React:
  // GET staff/monthly/salary/?year=<year>&month=<month>
  // ============================================================

  Future<void> fetchMonthlySalary() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = '';
      });
    }

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found.');
      }

      final uri = Uri.parse(
        '${api}/api/staff/monthly/salary/',
      ).replace(
        queryParameters: {
          'year': selectedYear.toString(),
          'month': selectedMonth.toString(),
        },
      );

      debugPrint('======= FETCH MONTHLY SALARY =======');
      debugPrint('GET $uri');

      final response = await http.get(
        uri,
        headers: _headers(token),
      );

      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('BODY: ${response.body}');
      debugPrint('====================================');

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractMessage(
            decoded,
            fallback: 'Failed to fetch monthly salary data.',
          ),
        );
      }

      if (decoded is! Map ||
          decoded['status']?.toString().toLowerCase() != 'success') {
        throw Exception(
          _extractMessage(
            decoded,
            fallback: 'Failed to fetch monthly salary data.',
          ),
        );
      }

      final rawData = decoded['data'];

      final parsedSalary = <Map<String, dynamic>>[];

      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map) {
            parsedSalary.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (!mounted) return;

      setState(() {
        salaryList = parsedSalary;
        error = '';
      });
    } catch (e, stackTrace) {
      debugPrint('MONTHLY SALARY FETCH ERROR: $e');
      debugPrint('$stackTrace');

      final message = e.toString().replaceFirst('Exception: ', '');

      if (!mounted) return;

      setState(() {
        salaryList = [];
        error = message;
      });

      _showMessage(
        message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // REACT useMemo: filteredSalaryList
  // Staff filtering is intentionally local, exactly like React.
  // Changing staff does NOT call monthly salary API.
  // ============================================================

  List<Map<String, dynamic>> get filteredSalaryList {
    if (selectedStaffId == null) {
      return salaryList;
    }

    return salaryList.where((item) {
      return item['staff']?.toString() == selectedStaffId.toString();
    }).toList();
  }

  // ============================================================
  // REACT useMemo: summary
  // ============================================================

  SalaryReportSummary get summary {
    final result = SalaryReportSummary();

    for (final item in filteredSalaryList) {
      result.totalStaff += 1;
      result.totalBaseSalary += _toDouble(item['monthly_salary']);
      result.totalBonus += _toDouble(item['bonus']);
      result.totalIncentives += _toDouble(item['incentives']);
      result.totalFines += _toDouble(item['fines']);
      result.totalLateDeduction +=
          _toDouble(item['late_come_deduction']);
      result.totalFinalSalary += _toDouble(item['final_salary']);
    }

    return result;
  }

  // ============================================================
  // SELECTED STAFF
  // ============================================================

  Map<String, dynamic>? get selectedStaff {
    if (selectedStaffId == null) return null;

    for (final staff in staffList) {
      if (_toInt(staff['id']) == selectedStaffId) {
        return staff;
      }
    }

    return null;
  }

  // ============================================================
  // FORMATTERS - EXACT REACT SEMANTICS
  // ============================================================

  String formatCurrency(dynamic value) {
    final number = _toDouble(value);

    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: 2,
    ).format(number).trim();
  }

  String formatNumber(dynamic value) {
    final number = _toDouble(value);

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(1);
  }

  String getMonthName(dynamic monthNumber) {
    final number = _toInt(monthNumber);

    if (number == null) return '-';

    for (final month in months) {
      if (month['value'] == number) {
        return month['label'].toString();
      }
    }

    return '-';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  String _extractMessage(
    dynamic decoded, {
    required String fallback,
  }) {
    if (decoded is Map) {
      return decoded['message']?.toString() ??
          decoded['detail']?.toString() ??
          decoded['error']?.toString() ??
          fallback;
    }

    return fallback;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? Colors.red : Colors.green,
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // STAFF SEARCH / SELECT
  // React react-select searches:
  // name, staff_id, eid, department_name, designation
  // and is clearable.
  // ============================================================

  Future<void> _openStaffSelector() async {
    if (staffLoading || loading) return;

    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _StaffSearchSheet(
          staffList: staffList,
          selectedStaffId: selectedStaffId,
        );
      },
    );

    if (!mounted) return;

    // null means the sheet was dismissed without a selection.
    // -1 is our explicit "clear staff" value.
    if (result == -1) {
      setState(() {
        selectedStaffId = null;
      });
      return;
    }

    if (result != null) {
      setState(() {
        selectedStaffId = result;
      });
    }
  }

  // ============================================================
  // FILTER CHANGE
  // React refetches monthly salary automatically whenever
  // year/month changes.
  // ============================================================

  Future<void> _changeYear(int? value) async {
    if (value == null || value == selectedYear) return;

    setState(() {
      selectedYear = value;
    });

    await fetchMonthlySalary();
  }

  Future<void> _changeMonth(int? value) async {
    if (value == null || value == selectedMonth) return;

    setState(() {
      selectedMonth = value;
    });

    await fetchMonthlySalary();
  }

  // ============================================================
  // PROFESSIONAL EXCEL / PDF EXPORT
  // Uses the currently visible/filtered salary records.
  // Files are created inside the app documents directory and then
  // handed to the native Android/iOS share sheet.
  // ============================================================

  String _safeFilePart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return cleaned.isEmpty ? 'Report' : cleaned;
  }

  String _reportBaseFileName() {
    final month = getMonthName(selectedMonth);
    final staffName = selectedStaff?['name']?.toString().trim();

    if (staffName != null && staffName.isNotEmpty) {
      return 'Monthly_Salary_Report_'
          '${_safeFilePart(staffName)}_'
          '${_safeFilePart(month)}_$selectedYear';
    }

    return 'Monthly_Salary_Report_'
        '${_safeFilePart(month)}_$selectedYear';
  }

  String _reportPeriodText() {
    return '${getMonthName(selectedMonth)} $selectedYear';
  }

  String _reportStaffText() {
    final staff = selectedStaff;

    if (staff == null) {
      return 'All Staff';
    }

    final name = staff['name']?.toString().trim();
    final staffCode =
        staff['staff_id']?.toString().trim() ??
        staff['eid']?.toString().trim();

    if (name != null &&
        name.isNotEmpty &&
        staffCode != null &&
        staffCode.isNotEmpty) {
      return '$name ($staffCode)';
    }

    return name == null || name.isEmpty ? 'Selected Staff' : name;
  }

  String _generatedAtText() {
    return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
  }

  Future<Directory> _getExportDirectory() async {
    // ApplicationDocumentsDirectory is sandbox-safe on both Android and iOS.
    // The generated file is exposed through the native share/save sheet.
    return getApplicationDocumentsDirectory();
  }

  Future<void> _shareExportedFile({
    required File file,
    required String mimeType,
    required String subject,
  }) async {
    final box = context.findRenderObject() as RenderBox?;

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: mimeType,
          name: file.uri.pathSegments.last,
        ),
      ],
      subject: subject,
      text: subject,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _exportExcel() async {
    if (filteredSalaryList.isEmpty) {
      _showMessage(
        'No salary data available to export.',
        isError: true,
      );
      return;
    }

    if (excelExporting || pdfExporting) return;

    setState(() {
      excelExporting = true;
    });

    try {
      final List<Map<String, dynamic>> rows =
          List<Map<String, dynamic>>.from(filteredSalaryList);
      final SalaryReportSummary reportSummary = summary;

      final ex.Excel excel = ex.Excel.createExcel();

      final String? defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final ex.Sheet sheet = excel['Salary Report'];

      final ex.Border thinBorder = ex.Border(
        borderStyle: ex.BorderStyle.Thin,
      );

      final ex.CellStyle titleStyle = ex.CellStyle(
        backgroundColorHex: '#17365D',
        fontColorHex: '#FFFFFF',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 18,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle subtitleStyle = ex.CellStyle(
        backgroundColorHex: '#DDEBF7',
        fontColorHex: '#17365D',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 11,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle metaLabelStyle = ex.CellStyle(
        backgroundColorHex: '#EAF3F8',
        fontColorHex: '#17365D',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Left,
        verticalAlign: ex.VerticalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle metaValueStyle = ex.CellStyle(
        backgroundColorHex: '#FFFFFF',
        fontColorHex: '#1F2937',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Left,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle summaryLabelStyle = ex.CellStyle(
        backgroundColorHex: '#F2F2F2',
        fontColorHex: '#17365D',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle summaryValueStyle = ex.CellStyle(
        backgroundColorHex: '#DDEBF7',
        fontColorHex: '#17365D',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle headerStyle = ex.CellStyle(
        backgroundColorHex: '#17365D',
        fontColorHex: '#FFFFFF',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle bodyTextStyle = ex.CellStyle(
        backgroundColorHex: '#FFFFFF',
        fontColorHex: '#1F2937',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Left,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle bodyCenterStyle = ex.CellStyle(
        backgroundColorHex: '#FFFFFF',
        fontColorHex: '#1F2937',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle bodyAmountStyle = ex.CellStyle(
        backgroundColorHex: '#FFFFFF',
        fontColorHex: '#1F2937',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Right,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle positiveAmountStyle = ex.CellStyle(
        backgroundColorHex: '#E2F0D9',
        fontColorHex: '#137333',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Right,
        verticalAlign: ex.VerticalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle negativeAmountStyle = ex.CellStyle(
        backgroundColorHex: '#FCE4D6',
        fontColorHex: '#B42318',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Right,
        verticalAlign: ex.VerticalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle totalLabelStyle = ex.CellStyle(
        backgroundColorHex: '#17365D',
        fontColorHex: '#FFFFFF',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 11,
        horizontalAlign: ex.HorizontalAlign.Right,
        verticalAlign: ex.VerticalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final ex.CellStyle totalValueStyle = ex.CellStyle(
        backgroundColorHex: '#DDEBF7',
        fontColorHex: '#17365D',
        fontFamily: ex.getFontFamily(ex.FontFamily.Calibri),
        bold: true,
        fontSize: 10,
        horizontalAlign: ex.HorizontalAlign.Right,
        verticalAlign: ex.VerticalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        topBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      final Map<int, int> columnWidths = {};

      void updateColumnWidth(int column, String text) {
        final int length = text.length;
        if (!columnWidths.containsKey(column) ||
            length > columnWidths[column]!) {
          columnWidths[column] = length;
        }
      }

      void setCell(
        int column,
        int row,
        dynamic value,
        ex.CellStyle style,
      ) {
        final String text = value?.toString() ?? '';

        final cell = sheet.cell(
          ex.CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: row,
          ),
        );

        // IMPORTANT:
        // This matches Approve BDO Call Duration and is compatible with
        // the Excel package version already used in this project.
        cell.value = text;
        cell.cellStyle = style;

        updateColumnWidth(column, text);
      }

      // =========================================================
      // REPORT TITLE
      // =========================================================

      sheet.merge(
        ex.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: 0,
        ),
        ex.CellIndex.indexByColumnRow(
          columnIndex: 17,
          rowIndex: 0,
        ),
      );

      setCell(
        0,
        0,
        'MONTHLY SALARY REPORT',
        titleStyle,
      );

      sheet.merge(
        ex.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: 1,
        ),
        ex.CellIndex.indexByColumnRow(
          columnIndex: 17,
          rowIndex: 1,
        ),
      );

      setCell(
        0,
        1,
        'Professional Payroll & Attendance Statement',
        subtitleStyle,
      );

      // =========================================================
      // REPORT INFORMATION
      // =========================================================

      setCell(0, 3, 'Report Period', metaLabelStyle);

      sheet.merge(
        ex.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: 3,
        ),
        ex.CellIndex.indexByColumnRow(
          columnIndex: 3,
          rowIndex: 3,
        ),
      );

      setCell(
        1,
        3,
        _reportPeriodText(),
        metaValueStyle,
      );

      setCell(5, 3, 'Staff Filter', metaLabelStyle);

      sheet.merge(
        ex.CellIndex.indexByColumnRow(
          columnIndex: 6,
          rowIndex: 3,
        ),
        ex.CellIndex.indexByColumnRow(
          columnIndex: 10,
          rowIndex: 3,
        ),
      );

      setCell(
        6,
        3,
        _reportStaffText(),
        metaValueStyle,
      );

      setCell(12, 3, 'Generated', metaLabelStyle);

      sheet.merge(
        ex.CellIndex.indexByColumnRow(
          columnIndex: 13,
          rowIndex: 3,
        ),
        ex.CellIndex.indexByColumnRow(
          columnIndex: 17,
          rowIndex: 3,
        ),
      );

      setCell(
        13,
        3,
        _generatedAtText(),
        metaValueStyle,
      );

      // =========================================================
      // SUMMARY
      // =========================================================

      final List<Map<String, String>> summaryItems = [
        {
          'label': 'Total Staff',
          'value': reportSummary.totalStaff.toString(),
        },
        {
          'label': 'Base Salary',
          'value':
              'INR ${formatCurrency(reportSummary.totalBaseSalary)}',
        },
        {
          'label': 'Bonus',
          'value': 'INR ${formatCurrency(reportSummary.totalBonus)}',
        },
        {
          'label': 'Incentives',
          'value':
              'INR ${formatCurrency(reportSummary.totalIncentives)}',
        },
        {
          'label': 'Fines',
          'value': 'INR ${formatCurrency(reportSummary.totalFines)}',
        },
        {
          'label': 'Late Deduction',
          'value':
              'INR ${formatCurrency(reportSummary.totalLateDeduction)}',
        },
        {
          'label': 'Final Salary',
          'value':
              'INR ${formatCurrency(reportSummary.totalFinalSalary)}',
        },
      ];

      for (int i = 0; i < summaryItems.length; i++) {
        final int column = i * 2;

        setCell(
          column,
          5,
          summaryItems[i]['label'],
          summaryLabelStyle,
        );

        setCell(
          column,
          6,
          summaryItems[i]['value'],
          summaryValueStyle,
        );
      }

      // =========================================================
      // TABLE HEADER
      // =========================================================

      final List<String> headers = [
        'SL',
        'STAFF ID',
        'STAFF NAME',
        'PRESENT',
        'ABSENT',
        'HALF DAY',
        'PAID LEAVE',
        'MONTHLY SALARY',
        'PER DAY',
        'ATTENDANCE PAYABLE',
        'BONUS',
        'INCENTIVES',
        'LATE COMES',
        'LATE LEAVE',
        'LATE DEDUCTION',
        'FINES',
        'FINAL SALARY',
        'NOTE',
      ];

      const int headerRow = 8;

      for (int i = 0; i < headers.length; i++) {
        setCell(
          i,
          headerRow,
          headers[i],
          headerStyle,
        );
      }

      // =========================================================
      // TABLE DATA
      // =========================================================

      int excelRow = headerRow + 1;

      for (int i = 0; i < rows.length; i++) {
        final Map<String, dynamic> item = rows[i];

        setCell(
          0,
          excelRow,
          (i + 1).toString(),
          bodyCenterStyle,
        );

        setCell(
          1,
          excelRow,
          item['staff_id']?.toString() ?? '-',
          bodyCenterStyle,
        );

        setCell(
          2,
          excelRow,
          item['staff_name']?.toString() ?? '-',
          bodyTextStyle,
        );

        setCell(
          3,
          excelRow,
          formatNumber(item['present']),
          bodyCenterStyle,
        );

        setCell(
          4,
          excelRow,
          formatNumber(item['absent']),
          bodyCenterStyle,
        );

        setCell(
          5,
          excelRow,
          formatNumber(item['half_day']),
          bodyCenterStyle,
        );

        setCell(
          6,
          excelRow,
          formatNumber(item['paid_leaves']),
          bodyCenterStyle,
        );

        setCell(
          7,
          excelRow,
          formatCurrency(item['monthly_salary']),
          bodyAmountStyle,
        );

        setCell(
          8,
          excelRow,
          formatCurrency(item['per_day_salary']),
          bodyAmountStyle,
        );

        setCell(
          9,
          excelRow,
          formatCurrency(item['attendance_payable_salary']),
          bodyAmountStyle,
        );

        setCell(
          10,
          excelRow,
          formatCurrency(item['bonus']),
          positiveAmountStyle,
        );

        setCell(
          11,
          excelRow,
          formatCurrency(item['incentives']),
          positiveAmountStyle,
        );

        setCell(
          12,
          excelRow,
          item['late_comes']?.toString() ?? '0',
          bodyCenterStyle,
        );

        setCell(
          13,
          excelRow,
          formatNumber(item['late_leave_days']),
          bodyCenterStyle,
        );

        setCell(
          14,
          excelRow,
          formatCurrency(item['late_come_deduction']),
          negativeAmountStyle,
        );

        setCell(
          15,
          excelRow,
          formatCurrency(item['fines']),
          negativeAmountStyle,
        );

        setCell(
          16,
          excelRow,
          formatCurrency(item['final_salary']),
          positiveAmountStyle,
        );

        final String note = item['note']?.toString().trim() ?? '';

        setCell(
          17,
          excelRow,
          note.isEmpty ? '-' : note,
          bodyTextStyle,
        );

        excelRow++;
      }

      // =========================================================
      // TOTAL ROW
      // =========================================================

      sheet.merge(
        ex.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: excelRow,
        ),
        ex.CellIndex.indexByColumnRow(
          columnIndex: 6,
          rowIndex: excelRow,
        ),
      );

      setCell(
        0,
        excelRow,
        'TOTAL',
        totalLabelStyle,
      );

      setCell(
        7,
        excelRow,
        formatCurrency(reportSummary.totalBaseSalary),
        totalValueStyle,
      );

      setCell(8, excelRow, '', totalValueStyle);
      setCell(9, excelRow, '', totalValueStyle);

      setCell(
        10,
        excelRow,
        formatCurrency(reportSummary.totalBonus),
        totalValueStyle,
      );

      setCell(
        11,
        excelRow,
        formatCurrency(reportSummary.totalIncentives),
        totalValueStyle,
      );

      setCell(12, excelRow, '', totalValueStyle);
      setCell(13, excelRow, '', totalValueStyle);

      setCell(
        14,
        excelRow,
        formatCurrency(reportSummary.totalLateDeduction),
        totalValueStyle,
      );

      setCell(
        15,
        excelRow,
        formatCurrency(reportSummary.totalFines),
        totalValueStyle,
      );

      setCell(
        16,
        excelRow,
        formatCurrency(reportSummary.totalFinalSalary),
        totalValueStyle,
      );

      setCell(17, excelRow, '', totalValueStyle);

      // =========================================================
      // COLUMN WIDTHS
      // Approve BDO Call Duration uses setColWidth(), not
      // setColumnWidth().
      // =========================================================

      final Map<int, double> minimumWidths = {
        0: 7.0,
        1: 14.0,
        2: 24.0,
        3: 10.0,
        4: 10.0,
        5: 11.0,
        6: 12.0,
        7: 17.0,
        8: 14.0,
        9: 20.0,
        10: 14.0,
        11: 14.0,
        12: 12.0,
        13: 12.0,
        14: 18.0,
        15: 14.0,
        16: 18.0,
        17: 32.0,
      };

      for (int column = 0; column < headers.length; column++) {
        double width =
            ((columnWidths[column] ?? headers[column].length) + 2)
                .toDouble();

        final double minimumWidth =
            minimumWidths[column] ?? 10.0;

        if (width < minimumWidth) {
          width = minimumWidth;
        }

        if (column == 17) {
          if (width > 45.0) width = 45.0;
        } else {
          if (width > 28.0) width = 28.0;
        }

        sheet.setColWidth(column, width);
      }

      // =========================================================
      // CREATE FILE
      // =========================================================

      final List<int>? fileBytes = excel.encode();

      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file.');
      }

      final Directory directory =
          await getApplicationDocumentsDirectory();

      final String filePath =
          '${directory.path}/${_reportBaseFileName()}.xlsx';

      final File file = File(filePath);

      await file.writeAsBytes(
        fileBytes,
        flush: true,
      );

      debugPrint('EXCEL EXPORTED: ${file.path}');

      if (!mounted) return;

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text:
            'Monthly Salary Report - ${_reportPeriodText()}',
      );
    } catch (e, stackTrace) {
      debugPrint('EXCEL EXPORT ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _showMessage(
        'Excel export failed: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          excelExporting = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    final rows = List<Map<String, dynamic>>.from(filteredSalaryList);

    if (rows.isEmpty) {
      _showMessage(
        'No salary data available to export.',
        isError: true,
      );
      return;
    }

    if (pdfExporting || excelExporting) return;

    setState(() {
      pdfExporting = true;
    });

    try {
      final reportSummary = summary;
      final document = pw.Document(
        title: 'Monthly Salary Report',
        author: 'Beposoft',
        subject: _reportPeriodText(),
        creator: 'Beposoft',
      );

      final darkBlue = PdfColor.fromHex('#17365D');
      final lightBlue = PdfColor.fromHex('#D9EAF7');
      final veryLightBlue = PdfColor.fromHex('#F3F8FC');
      final lightGray = PdfColor.fromHex('#F4F6F8');
      final darkText = PdfColor.fromHex('#1F2937');
      final mutedText = PdfColor.fromHex('#667085');
      final green = PdfColor.fromHex('#137333');
      final red = PdfColor.fromHex('#B42318');
      final borderColor = PdfColor.fromHex('#D0D5DD');

      pw.Widget moneyText(
        dynamic value, {
        PdfColor? color,
        bool bold = false,
        String prefix = '',
      }) {
        return pw.Text(
          '$prefix INR ${formatCurrency(value)}',
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            color: color ?? darkText,
            fontSize: 5.5,
            fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        );
      }

      pw.Widget summaryBox(
        String label,
        String value, {
        PdfColor? valueColor,
      }) {
        return pw.Container(
          width: 103,
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 7,
          ),
          decoration: pw.BoxDecoration(
            color: veryLightBlue,
            border: pw.Border.all(
              color: borderColor,
              width: 0.5,
            ),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: mutedText,
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                value,
                style: pw.TextStyle(
                  color: valueColor ?? darkBlue,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }

      final tableHeaders = <String>[
        'SL',
        'Staff ID',
        'Staff Name',
        'Present',
        'Absent',
        'Half Day',
        'Paid Leave',
        'Monthly Salary',
        'Per Day',
        'Attendance Payable',
        'Bonus',
        'Incentives',
        'Late Comes',
        'Late Leave',
        'Late Deduction',
        'Fines',
        'Final Salary',
        'Note',
      ];

      final tableData = <List<dynamic>>[
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return <dynamic>[
            '${index + 1}',
            item['staff_id']?.toString() ?? '-',
            item['staff_name']?.toString() ?? '-',
            formatNumber(item['present']),
            formatNumber(item['absent']),
            formatNumber(item['half_day']),
            formatNumber(item['paid_leaves']),
            formatCurrency(item['monthly_salary']),
            formatCurrency(item['per_day_salary']),
            formatCurrency(item['attendance_payable_salary']),
            formatCurrency(item['bonus']),
            formatCurrency(item['incentives']),
            item['late_comes']?.toString() ?? '0',
            formatNumber(item['late_leave_days']),
            formatCurrency(item['late_come_deduction']),
            formatCurrency(item['fines']),
            formatCurrency(item['final_salary']),
            item['note']?.toString().trim().isNotEmpty == true
                ? item['note'].toString()
                : '-',
          ];
        }),
        <dynamic>[
          '',
          '',
          'TOTAL',
          '',
          '',
          '',
          '',
          formatCurrency(reportSummary.totalBaseSalary),
          '',
          '',
          formatCurrency(reportSummary.totalBonus),
          formatCurrency(reportSummary.totalIncentives),
          '',
          '',
          formatCurrency(reportSummary.totalLateDeduction),
          formatCurrency(reportSummary.totalFines),
          formatCurrency(reportSummary.totalFinalSalary),
          '',
        ],
      ];

      document.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a3.landscape,
            margin: const pw.EdgeInsets.fromLTRB(
              22,
              22,
              22,
              24,
            ),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          header: (context) {
            if (context.pageNumber == 1) {
              return pw.SizedBox();
            }

            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 7),
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: borderColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'MONTHLY SALARY REPORT',
                    style: pw.TextStyle(
                      color: darkBlue,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_reportPeriodText()} | ${_reportStaffText()}',
                    style: pw.TextStyle(
                      color: mutedText,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(top: 7),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(
                    color: borderColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by Beposoft | ${_generatedAtText()}',
                    style: pw.TextStyle(
                      color: mutedText,
                      fontSize: 6.5,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      color: mutedText,
                      fontSize: 6.5,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (context) {
            return [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: darkBlue,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MONTHLY SALARY REPORT',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Payroll, Attendance & Salary Statement',
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Text(
                      _reportPeriodText(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: lightBlue,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Period: ',
                              style: pw.TextStyle(
                                color: darkBlue,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(
                              text: _reportPeriodText(),
                              style: pw.TextStyle(
                                color: darkText,
                                fontSize: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Staff: ',
                              style: pw.TextStyle(
                                color: darkBlue,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(
                              text: _reportStaffText(),
                              style: pw.TextStyle(
                                color: darkText,
                                fontSize: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Records: ${rows.length}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          color: darkText,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  summaryBox(
                    'Total Staff',
                    reportSummary.totalStaff.toString(),
                  ),
                  summaryBox(
                    'Base Salary',
                    'INR ${formatCurrency(reportSummary.totalBaseSalary)}',
                  ),
                  summaryBox(
                    'Bonus',
                    'INR ${formatCurrency(reportSummary.totalBonus)}',
                    valueColor: green,
                  ),
                  summaryBox(
                    'Incentives',
                    'INR ${formatCurrency(reportSummary.totalIncentives)}',
                    valueColor: green,
                  ),
                  summaryBox(
                    'Fines',
                    'INR ${formatCurrency(reportSummary.totalFines)}',
                    valueColor: red,
                  ),
                  summaryBox(
                    'Late Deduction',
                    'INR ${formatCurrency(reportSummary.totalLateDeduction)}',
                    valueColor: red,
                  ),
                  summaryBox(
                    'Final Salary',
                    'INR ${formatCurrency(reportSummary.totalFinalSalary)}',
                    valueColor: green,
                  ),
                ],
              ),

              pw.SizedBox(height: 14),

              pw.Text(
                'STAFF SALARY DETAILS',
                style: pw.TextStyle(
                  color: darkBlue,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.TableHelper.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                border: pw.TableBorder.all(
                  color: borderColor,
                  width: 0.35,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: darkBlue,
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 5.2,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(
                  color: darkText,
                  fontSize: 5.2,
                ),
                cellAlignment: pw.Alignment.centerRight,
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 4,
                ),
                oddRowDecoration: pw.BoxDecoration(
                  color: PdfColors.white,
                ),
                rowDecoration: pw.BoxDecoration(
                  color: lightGray,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(20),
                  1: const pw.FixedColumnWidth(48),
                  2: const pw.FixedColumnWidth(92),
                  3: const pw.FixedColumnWidth(36),
                  4: const pw.FixedColumnWidth(36),
                  5: const pw.FixedColumnWidth(40),
                  6: const pw.FixedColumnWidth(44),
                  7: const pw.FixedColumnWidth(63),
                  8: const pw.FixedColumnWidth(54),
                  9: const pw.FixedColumnWidth(75),
                  10: const pw.FixedColumnWidth(52),
                  11: const pw.FixedColumnWidth(55),
                  12: const pw.FixedColumnWidth(44),
                  13: const pw.FixedColumnWidth(44),
                  14: const pw.FixedColumnWidth(64),
                  15: const pw.FixedColumnWidth(50),
                  16: const pw.FixedColumnWidth(66),
                  17: const pw.FixedColumnWidth(115),
                },
                cellBuilder: (
                  int columnIndex,
                  dynamic cell,
                  int rowIndex,
                ) {
                  final isTotalRow =
                      rowIndex == tableData.length - 1;

                  if (isTotalRow) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 4,
                      ),
                      color: lightBlue,
                      child: pw.Text(
                        cell?.toString() ?? '',
                        textAlign: columnIndex == 2
                            ? pw.TextAlign.right
                            : pw.TextAlign.right,
                        style: pw.TextStyle(
                          color: darkBlue,
                          fontSize: 5.4,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  if (columnIndex == 2 || columnIndex == 17) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 4,
                      ),
                      child: pw.Text(
                        cell?.toString() ?? '',
                        textAlign: pw.TextAlign.left,
                        style: pw.TextStyle(
                          color: darkText,
                          fontSize: 5.2,
                        ),
                      ),
                    );
                  }

                  if (columnIndex == 10 ||
                      columnIndex == 11 ||
                      columnIndex == 16) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 4,
                      ),
                      child: pw.Text(
                        cell?.toString() ?? '',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          color: green,
                          fontSize: 5.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  if (columnIndex == 14 || columnIndex == 15) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 4,
                      ),
                      child: pw.Text(
                        cell?.toString() ?? '',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          color: red,
                          fontSize: 5.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    child: pw.Text(
                      cell?.toString() ?? '',
                      textAlign: columnIndex <= 6 ||
                              columnIndex == 12 ||
                              columnIndex == 13
                          ? pw.TextAlign.center
                          : pw.TextAlign.right,
                      style: pw.TextStyle(
                        color: darkText,
                        fontSize: 5.2,
                      ),
                    ),
                  );
                },
              ),

              pw.SizedBox(height: 10),

              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: borderColor,
                    width: 0.5,
                  ),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Final Salary',
                      style: pw.TextStyle(
                        color: darkBlue,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    moneyText(
                      reportSummary.totalFinalSalary,
                      color: green,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await document.save();
      final directory = await _getExportDirectory();
      final file = File(
        '${directory.path}/${_reportBaseFileName()}.pdf',
      );

      await file.writeAsBytes(bytes, flush: true);

      debugPrint('PDF EXPORTED: ${file.path}');

      if (!mounted) return;

      await _shareExportedFile(
        file: file,
        mimeType: 'application/pdf',
        subject:
            'Monthly Salary Report - ${_reportPeriodText()}',
      );
    } catch (e, stackTrace) {
      debugPrint('PDF EXPORT ERROR: $e');
      debugPrint('$stackTrace');

      _showMessage(
        'PDF export failed: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          pdfExporting = false;
        });
      }
    }
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final reportSummary = summary;
    final visibleSalaryList = filteredSalaryList;
    final selected = selectedStaff;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Salary Report',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Staff / Monthly Salary Report',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Download Excel',
            onPressed: loading ||
                    filteredSalaryList.isEmpty ||
                    excelExporting ||
                    pdfExporting
                ? null
                : _exportExcel,
            icon: excelExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.table_view_outlined,
                    color: Colors.green,
                  ),
          ),
          IconButton(
            tooltip: 'Download PDF',
            onPressed: loading ||
                    filteredSalaryList.isEmpty ||
                    pdfExporting ||
                    excelExporting
                ? null
                : _exportPdf,
            icon: pdfExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Colors.redAccent,
                  ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading || excelExporting || pdfExporting
                ? null
                : () async {
                    await Future.wait([
                      fetchStaff(),
                      fetchMonthlySalary(),
                    ]);
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            fetchStaff(),
            fetchMonthlySalary(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildFilterCard(selected),
            const SizedBox(height: 16),

            if (loading)
              _buildLoadingCard()
            else if (error.isNotEmpty)
              _buildErrorCard()
            else ...[
              _buildSummarySection(reportSummary),
              const SizedBox(height: 16),
              _buildSalaryDetailsCard(visibleSalaryList, selected),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTER CARD
  // ============================================================

  Widget _buildFilterCard(Map<String, dynamic>? selected) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Salary Report',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 190,
                      child: _buildYearField(),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 220,
                      child: _buildMonthField(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStaffField(selected),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildYearField()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMonthField()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildStaffField(selected),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Showing salary records for ',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                ),
              ),
              Text(
                '${getMonthName(selectedMonth)} $selectedYear',
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (selected != null) ...[
                const Text(
                  ' | Staff: ',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                Text(
                  selected['name']?.toString() ?? '-',
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Year',
          style: TextStyle(
            color: Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _inputDecoration(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedYear,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: years
                  .map(
                    (year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    ),
                  )
                  .toList(),
              onChanged: loading ? null : _changeYear,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month',
          style: TextStyle(
            color: Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _inputDecoration(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedMonth,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: months
                  .map(
                    (month) => DropdownMenuItem<int>(
                      value: month['value'] as int,
                      child: Text(month['label'].toString()),
                    ),
                  )
                  .toList(),
              onChanged: loading ? null : _changeMonth,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffField(Map<String, dynamic>? selected) {
    final staffLabel = selected == null
        ? (staffLoading ? 'Loading Staff...' : 'Search or Select Staff')
        : '${selected['name'] ?? '-'} - '
            '${selected['staff_id'] ?? selected['eid'] ?? 'ID ${selected['id']}'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Staff',
          style: TextStyle(
            color: Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: staffLoading || loading ? null : _openStaffSelector,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: _inputDecoration(),
              child: Row(
                children: [
                  if (staffLoading) ...[
                    const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Expanded(
                    child: Text(
                      staffLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected == null
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF1F2937),
                        fontSize: 13,
                        fontWeight: selected == null
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selected != null && !staffLoading && !loading)
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedStaffId = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6B7280),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _inputDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFFCED4DA),
      ),
    );
  }

  // ============================================================
  // LOADING / ERROR
  // ============================================================

  Widget _buildLoadingCard() {
    return _card(
      child: const SizedBox(
        height: 200,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 12),
              Text(
                'Loading monthly salary data...',
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8D7DA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF5C2C7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFF842029),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Color(0xFF842029),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry',
            onPressed: loading ? null : fetchMonthlySalary,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF842029),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARDS
  // Exact React totals:
  // totalStaff, totalBaseSalary, totalBonus, totalIncentives,
  // totalFines, totalLateDeduction, totalFinalSalary
  // ============================================================

  Widget _buildSummarySection(SalaryReportSummary reportSummary) {
    final items = <_SummaryCardData>[
      _SummaryCardData(
        title: 'Total Staff',
        value: reportSummary.totalStaff.toString(),
        icon: Icons.groups_2_outlined,
      ),
      _SummaryCardData(
        title: 'Total Base Salary',
        value: '₹${formatCurrency(reportSummary.totalBaseSalary)}',
        icon: Icons.account_balance_wallet_outlined,
      ),
      _SummaryCardData(
        title: 'Total Bonus',
        value: '₹${formatCurrency(reportSummary.totalBonus)}',
        icon: Icons.add_circle_outline_rounded,
        valueColor: Colors.green,
      ),
      _SummaryCardData(
        title: 'Total Incentives',
        value: '₹${formatCurrency(reportSummary.totalIncentives)}',
        icon: Icons.trending_up_rounded,
        valueColor: Colors.green,
      ),
      _SummaryCardData(
        title: 'Total Fines',
        value: '₹${formatCurrency(reportSummary.totalFines)}',
        icon: Icons.remove_circle_outline_rounded,
        valueColor: Colors.red,
      ),
      _SummaryCardData(
        title: 'Late Come Deduction',
        value: '₹${formatCurrency(reportSummary.totalLateDeduction)}',
        icon: Icons.schedule_rounded,
        valueColor: Colors.red,
      ),
      _SummaryCardData(
        title: 'Total Final Salary',
        value: '₹${formatCurrency(reportSummary.totalFinalSalary)}',
        icon: Icons.payments_outlined,
        valueColor: Colors.green,
        featured: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns;
        if (width >= 1050) {
          columns = 4;
        } else if (width >= 650) {
          columns = 2;
        } else {
          columns = 2;
        }

        final spacing = 12.0;
        final itemWidth =
            (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            // On desktop the React final salary card spans 2 columns.
            final effectiveWidth = item.featured && width >= 1050
                ? (itemWidth * 2) + spacing
                : itemWidth;

            return SizedBox(
              width: effectiveWidth,
              child: _buildSummaryCard(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSummaryCard(_SummaryCardData data) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              data.icon,
              color: const Color(0xFF475569),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    maxLines: 1,
                    style: TextStyle(
                      color:
                          data.valueColor ?? const Color(0xFF1F2937),
                      fontSize: data.featured ? 23 : 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SALARY DETAILS CARD
  // ============================================================

  Widget _buildSalaryDetailsCard(
    List<Map<String, dynamic>> visibleSalaryList,
    Map<String, dynamic>? selected,
  ) {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Staff Salary Details',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${visibleSalaryList.length} '
                  'Record${visibleSalaryList.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (visibleSalaryList.isEmpty)
            _buildEmptySalaryState(selected)
          else
            _buildSalaryTable(visibleSalaryList),
        ],
      ),
    );
  }

  Widget _buildEmptySalaryState(Map<String, dynamic>? selected) {
    final staffText = selected == null
        ? ''
        : '${selected['name'] ?? 'selected staff'} in ';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 50,
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              'No monthly salary records found for '
              '$staffText${getMonthName(selectedMonth)} $selectedYear.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REACT TABLE
  // All 18 columns are retained.
  // ============================================================

  Widget _buildSalaryTable(
    List<Map<String, dynamic>> visibleSalaryList,
  ) {
    final reportSummary = summary;

    return Scrollbar(
      controller: _tableHorizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _tableHorizontalController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFF8F9FA),
          ),
          dataRowMinHeight: 58,
          dataRowMaxHeight: 82,
          headingRowHeight: 58,
          horizontalMargin: 14,
          columnSpacing: 22,
          border: TableBorder.all(
            color: const Color(0xFFDEE2E6),
            width: 0.8,
          ),
          columns: const [
            DataColumn(label: _TableHeader('SL')),
            DataColumn(label: _TableHeader('Staff ID')),
            DataColumn(label: _TableHeader('Staff Name')),
            DataColumn(
              numeric: true,
              label: _TableHeader('Present'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Absent'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Half Day'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Paid Leave'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Monthly Salary'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Per Day'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Attendance Payable'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Bonus'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Incentives'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Late Comes'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Late Leave'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Late Deduction'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Fines'),
            ),
            DataColumn(
              numeric: true,
              label: _TableHeader('Final Salary'),
            ),
            DataColumn(label: _TableHeader('Note')),
          ],
          rows: [
            ...visibleSalaryList.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final item = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(
                      Text(
                        item['staff_id']?.toString() ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['staff_name']?.toString() ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${getMonthName(item['month'])} '
                              '${item['year'] ?? '-'}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      _coloredNumber(
                        formatNumber(item['present']),
                        Colors.green,
                      ),
                    ),
                    DataCell(
                      _coloredNumber(
                        formatNumber(item['absent']),
                        Colors.red,
                      ),
                    ),
                    DataCell(
                      _coloredNumber(
                        formatNumber(item['half_day']),
                        Colors.orange,
                      ),
                    ),
                    DataCell(
                      Text(formatNumber(item['paid_leaves'])),
                    ),
                    DataCell(
                      _moneyCell(item['monthly_salary']),
                    ),
                    DataCell(
                      _moneyCell(item['per_day_salary']),
                    ),
                    DataCell(
                      _moneyCell(
                        item['attendance_payable_salary'],
                      ),
                    ),
                    DataCell(
                      _signedMoneyCell(
                        item['bonus'],
                        prefix: '+ ',
                        color: Colors.green,
                        bold: true,
                      ),
                    ),
                    DataCell(
                      _signedMoneyCell(
                        item['incentives'],
                        prefix: '+ ',
                        color: Colors.green,
                        bold: true,
                      ),
                    ),
                    DataCell(
                      Text(
                        item['late_comes']?.toString() ?? '0',
                      ),
                    ),
                    DataCell(
                      Text(
                        formatNumber(item['late_leave_days']),
                      ),
                    ),
                    DataCell(
                      _signedMoneyCell(
                        item['late_come_deduction'],
                        prefix: '- ',
                        color: Colors.red,
                      ),
                    ),
                    DataCell(
                      _signedMoneyCell(
                        item['fines'],
                        prefix: '- ',
                        color: Colors.red,
                      ),
                    ),
                    DataCell(
                      _signedMoneyCell(
                        item['final_salary'],
                        prefix: '',
                        color: Colors.green,
                        bold: true,
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          item['note']?.toString().trim().isNotEmpty == true
                              ? item['note'].toString()
                              : '-',
                          softWrap: true,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // React tfoot TOTAL row.
            DataRow(
              color: WidgetStateProperty.all(
                const Color(0xFFF8F9FA),
              ),
              cells: [
                const DataCell(
                  SizedBox(
                    width: 28,
                    child: Text(''),
                  ),
                ),
                const DataCell(Text('')),
                const DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(
                  _moneyCell(
                    reportSummary.totalBaseSalary,
                    bold: true,
                  ),
                ),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(
                  _signedMoneyCell(
                    reportSummary.totalBonus,
                    prefix: '+ ',
                    color: Colors.green,
                    bold: true,
                  ),
                ),
                DataCell(
                  _signedMoneyCell(
                    reportSummary.totalIncentives,
                    prefix: '+ ',
                    color: Colors.green,
                    bold: true,
                  ),
                ),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(
                  _signedMoneyCell(
                    reportSummary.totalLateDeduction,
                    prefix: '- ',
                    color: Colors.red,
                    bold: true,
                  ),
                ),
                DataCell(
                  _signedMoneyCell(
                    reportSummary.totalFines,
                    prefix: '- ',
                    color: Colors.red,
                    bold: true,
                  ),
                ),
                DataCell(
                  _signedMoneyCell(
                    reportSummary.totalFinalSalary,
                    prefix: '',
                    color: Colors.green,
                    bold: true,
                  ),
                ),
                const DataCell(Text('')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _coloredNumber(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _moneyCell(
    dynamic value, {
    bool bold = false,
  }) {
    return Text(
      '₹${formatCurrency(value)}',
      style: TextStyle(
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    );
  }

  Widget _signedMoneyCell(
    dynamic value, {
    required String prefix,
    required Color color,
    bool bold = false,
  }) {
    return Text(
      '$prefix₹${formatCurrency(value)}',
      style: TextStyle(
        color: color,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }

  // ============================================================
  // COMMON CARD
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    super.dispose();
  }
}

// ============================================================
// SUMMARY MODEL
// ============================================================

class SalaryReportSummary {
  int totalStaff = 0;
  double totalBaseSalary = 0;
  double totalBonus = 0;
  double totalIncentives = 0;
  double totalFines = 0;
  double totalLateDeduction = 0;
  double totalFinalSalary = 0;
}

class _SummaryCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool featured;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
    this.featured = false,
  });
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF374151),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ============================================================
// SEARCHABLE STAFF SELECTOR
// Exact searchable fields from React:
// name, staff_id, eid, department_name, designation
// ============================================================

class _StaffSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> staffList;
  final int? selectedStaffId;

  const _StaffSearchSheet({
    required this.staffList,
    required this.selectedStaffId,
  });

  @override
  State<_StaffSearchSheet> createState() => _StaffSearchSheetState();
}

class _StaffSearchSheetState extends State<_StaffSearchSheet> {
  final TextEditingController _searchController = TextEditingController();

  String search = '';

  List<Map<String, dynamic>> get filteredStaff {
    final query = search.toLowerCase().trim();

    if (query.isEmpty) {
      return widget.staffList;
    }

    return widget.staffList.where((staffItem) {
      final searchableText = [
        staffItem['name'],
        staffItem['staff_id'],
        staffItem['eid'],
        staffItem['department_name'],
        staffItem['designation'],
      ]
          .where(
            (value) =>
                value != null && value.toString().trim().isNotEmpty,
          )
          .map((value) => value.toString())
          .join(' ')
          .toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Search Staff',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.selectedStaffId != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, -1);
                      },
                      child: const Text('Clear'),
                    ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    search = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search or Select Staff',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              search = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFCED4DA),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFCED4DA),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF86B7FE),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredStaff.isEmpty
                  ? const Center(
                      child: Text(
                        'No staff found',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      itemCount: filteredStaff.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final staff = filteredStaff[index];
                        final id = _staffId(staff['id']);

                        final isSelected =
                            id != null && id == widget.selectedStaffId;

                        final label =
                            '${staff['name'] ?? '-'} - '
                            '${staff['staff_id'] ?? staff['eid'] ?? 'ID ${staff['id']}'}';

                        final secondary = [
                          staff['designation'],
                          staff['department_name'],
                        ]
                            .where(
                              (value) =>
                                  value != null &&
                                  value.toString().trim().isNotEmpty,
                            )
                            .map((value) => value.toString())
                            .join(' • ');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEAF2FF),
                            child: Text(
                              _initials(staff['name']?.toString() ?? '-'),
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: secondary.isEmpty
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    secondary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.blue,
                                )
                              : null,
                          onTap: id == null
                              ? null
                              : () {
                                  Navigator.pop(context, id);
                                },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static int? _staffId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';

    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }

    return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'
        .toUpperCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
