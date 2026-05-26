import 'dart:convert';
import 'dart:io';

import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ADMIN/admin_dashboard.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GSTReportPage extends StatefulWidget {
  const GSTReportPage({super.key});

  @override
  State<GSTReportPage> createState() => _GSTReportPageState();
}

class _GSTReportPageState extends State<GSTReportPage> {
  final String apiBase = 'https://bepocart.in/api/';

  final int pageSize = 100;

  int currentPage = 1;
  int totalCount = 0;

  bool loading = false;
  bool exportingB2B = false;
  bool exportingB2C = false;
  bool exportingB2CDetailed = false;
  bool exportingHSN = false;
  bool companyLoading = false;

  DateTime? startDate;
  DateTime? endDate;

  String selectedCompany = '';

  List<Map<String, dynamic>> gstData = [];
  List<Map<String, dynamic>> companyList = [];

  final Map<String, String> stateCodes = const {
    "Jammu Kashmir": "01",
    "Jammu & Kashmir": "01",
    "Himachal Pradesh": "02",
    "Punjab": "03",
    "Chandigarh": "04",
    "Uttarakhand": "05",
    "Haryana": "06",
    "Delhi": "07",
    "Rajasthan": "08",
    "Uttar Pradesh": "09",
    "Bihar": "10",
    "Sikkim": "11",
    "Arunachal Pradesh": "12",
    "Nagaland": "13",
    "Manipur": "14",
    "Mizoram": "15",
    "Tripura": "16",
    "Meghalaya": "17",
    "Assam": "18",
    "West Bengal": "19",
    "Jharkhand": "20",
    "Odisha": "21",
    "Chhattisgarh": "22",
    "Madhya Pradesh": "23",
    "Gujarat": "24",
    "Daman & Diu": "25",
    "Dadra & Nagar Haveli": "26",
    "Maharashtra": "27",
    "Karnataka": "29",
    "Goa": "30",
    "Lakshadweep": "31",
    "Kerala": "32",
    "Tamil Nadu": "33",
    "Pondicherry": "34",
    "Puducherry": "34",
    "Andaman & Nicobar Islands": "35",
    "Telangana": "36",
    "Andhra Pradesh": "37",
    "Ladakh": "38",
  };

  @override
  void initState() {
    super.initState();
    fetchCompanies();
  }

  Future<String?> getdepFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
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
    } else if (dep == "ADMIN") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => admin_dashboard()),
      );
    } else if (dep == "CEO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    } else if (dep == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
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

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  String _apiDate(DateTime? value) {
    if (value == null) return '';
    return DateFormat('yyyy-MM-dd').format(value);
  }

  String _invoiceDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '';

    try {
      final date = DateTime.parse(value.toString());
      return DateFormat('dd-MMM-yy').format(date).toUpperCase();
    } catch (_) {
      return '';
    }
  }

  String _monthYear(DateTime? value) {
    if (value == null) return '';
    return DateFormat('MMM yyyy').format(value).toUpperCase();
  }

  String _placeOfSupply(dynamic address) {
    final state = address?.toString().trim() ?? '';

    if (state.isEmpty) return '';

    final code = stateCodes[state];

    if (code == null) return state;

    return '$code-$state';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int get totalPages {
    if (totalCount <= 0) return 1;
    return (totalCount / pageSize).ceil();
  }

  List<Map<String, dynamic>> get paginatedGSTData {
    final startIndex = (currentPage - 1) * pageSize;
    final endIndex = startIndex + pageSize;

    if (startIndex >= gstData.length) return [];

    return gstData.sublist(
      startIndex,
      endIndex > gstData.length ? gstData.length : endIndex,
    );
  }

  List<Map<String, dynamic>> normalizeCompanyList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return [];
  }

  String getCompanyName(Map<String, dynamic> company) {
    return company['name']?.toString() ??
        company['company_name']?.toString() ??
        company['companyName']?.toString() ??
        company['title']?.toString() ??
        'Company ${company['id'] ?? ''}';
  }

  String get selectedCompanyName {
    if (selectedCompany.isEmpty) return 'All Companies';

    final company = companyList.where((c) {
      return c['id']?.toString() == selectedCompany;
    }).toList();

    if (company.isEmpty) return 'Company $selectedCompany';

    return getCompanyName(company.first);
  }

  String getExportFileBaseName() {
    final cleanCompanyName = selectedCompanyName.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );

    return '${cleanCompanyName}_${_apiDate(startDate).isEmpty ? "start" : _apiDate(startDate)}_to_${_apiDate(endDate).isEmpty ? "end" : _apiDate(endDate)}';
  }

  Future<void> fetchCompanies() async {
    if (companyLoading) return;

    setState(() {
      companyLoading = true;
    });

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        _showMessage('Token missing. Please login again.', isError: true);
        return;
      }

      final uri = Uri.parse('${apiBase}company/data/');
      final response = await http.get(uri, headers: _headers(token));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          companyList = normalizeCompanyList(decoded);
        });
      } else {
        _showMessage('Error fetching companies', isError: true);

        if (!mounted) return;

        setState(() {
          companyList = [];
        });
      }
    } catch (_) {
      _showMessage('Error fetching companies', isError: true);

      if (!mounted) return;

      setState(() {
        companyList = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          companyLoading = false;
        });
      }
    }
  }

  Future<void> fetchGSTReport() async {
    if (loading) return;

    if (startDate == null) {
      _showMessage('Please select start date', isError: true);
      return;
    }

    if (endDate == null) {
      _showMessage('Please select end date', isError: true);
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      _showMessage('Start date cannot be greater than end date', isError: true);
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        _showMessage('Token missing. Please login again.', isError: true);
        return;
      }

      final params = <String, String>{};

      if (selectedCompany.isNotEmpty) {
        params['company'] = selectedCompany;
      }

      final uri = Uri.parse(
        '${apiBase}gst/orders/report/${_apiDate(startDate)}/${_apiDate(endDate)}/',
      ).replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri, headers: _headers(token));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final results = decoded['results'];

        if (!mounted) return;

        setState(() {
          gstData = results is List
              ? results
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [];

          totalCount = gstData.length;
          currentPage = 1;
        });
      } else {
        _showMessage('Error fetching GST report', isError: true);

        if (!mounted) return;

        setState(() {
          gstData = [];
          totalCount = 0;
          currentPage = 1;
        });
      }
    } catch (_) {
      _showMessage('Error fetching GST report', isError: true);

      if (!mounted) return;

      setState(() {
        gstData = [];
        totalCount = 0;
        currentPage = 1;
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void clearFilter() {
    setState(() {
      startDate = null;
      endDate = null;
      selectedCompany = '';
      gstData = [];
      totalCount = 0;
      currentPage = 1;
    });
  }

  List<Map<String, dynamic>> tableRows() {
    final rows = <Map<String, dynamic>>[];

    for (int idx = 0; idx < paginatedGSTData.length; idx++) {
      final row = paginatedGSTData[idx];
      final items = row['items'];

      final Map<String, List<Map<String, dynamic>>> grouped = {};

      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            final mappedItem = Map<String, dynamic>.from(item);
            final taxKey = mappedItem['tax']?.toString() ?? '0';

            grouped.putIfAbsent(taxKey, () => []);
            grouped[taxKey]!.add(mappedItem);
          }
        }
      }

      grouped.forEach((taxRate, itemList) {
        final numericTaxRate = _toDouble(taxRate);

        double invoiceValue = 0.0;

        for (final item in itemList) {
          final rate = _toDouble(item['rate']);
          final quantity = _toDouble(item['quantity']);

          invoiceValue += rate * quantity;
        }

        final taxableValue = numericTaxRate > 0
            ? invoiceValue / (1 + numericTaxRate / 100)
            : invoiceValue;

        final gstConfirm =
            (row['gst_confirm'] ?? '').toString().trim().toUpperCase();

        rows.add({
          'key': '${row['id']}-$taxRate-${rows.length}',
          'index': ((currentPage - 1) * pageSize) + idx + 1,
          'gst': row['gst']?.toString() ?? '',
          'receiver': row['customerName']?.toString() ?? '',
          'invoice': row['invoice']?.toString() ?? '',
          'date': _invoiceDate(row['order_date']),

          // Same as React: Math.round(invoiceValue)
          'total_amount': invoiceValue.round().toString(),

          'placeOfSupply': _placeOfSupply(row['address']),
          'taxRate': '$taxRate%',
          'taxableValue': taxableValue.toStringAsFixed(2),
          'invoiceType': gstConfirm == 'YES' ? 'Regular B2B' : 'Regular B2C',
        });
      });
    }

    return rows;
  }

  List<String> get b2bB2CHeaders => const [
        'GSTIN/UIN of Recipient',
        'Receiver Name',
        'Invoice Number',
        'Invoice date',
        'Invoice Value',
        'Place Of Supply',
        'Reverse Charge',
        'Applicable % of Tax Rate',
        'Invoice Type',
        'E-Commerce GSTIN',
        'Rate',
        'Taxable Value',
        'Cess Amount',
      ];

  List<String> get b2cSummaryHeaders => const [
        'Type',
        'Place Of Supply',
        'Applicable % of Tax Rate',
        'Rate',
        'Taxable Value',
        'Cess Amount',
        'E-Commerce GSTIN',
      ];

  List<String> get hsnHeaders => const [
        'Description',
        'HSN',
        'Measurement',
        'Total Quantity',
        'Tax Rate',
        'Total Taxable Value',
        'IGST',
        'Central Tax',
        'State Tax',
        'Cess',
        'TOTAL',
      ];

  Map<String, List<Map<String, dynamic>>> buildB2BB2CRows() {
    final b2bRows = <Map<String, dynamic>>[];
    final b2cRows = <Map<String, dynamic>>[];

    for (final row in gstData) {
      final gstConfirm =
          (row['gst_confirm'] ?? '').toString().trim().toUpperCase();

      final items = row['items'];
      final Map<String, List<Map<String, dynamic>>> groupedByTax = {};

      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            final mappedItem = Map<String, dynamic>.from(item);
            final taxKey = mappedItem['tax']?.toString() ?? '0';

            groupedByTax.putIfAbsent(taxKey, () => []);
            groupedByTax[taxKey]!.add(mappedItem);
          }
        }
      }

      groupedByTax.forEach((taxRate, itemList) {
        final numericTaxRate = _toDouble(taxRate);

        double invoiceValue = 0.0;

        for (final item in itemList) {
          final rate = _toDouble(item['rate']);
          final quantity = _toDouble(item['quantity']);

          invoiceValue += rate * quantity;
        }

        final taxableValue = numericTaxRate > 0
            ? invoiceValue / (1 + numericTaxRate / 100)
            : invoiceValue;

        final baseRow = <String, dynamic>{
          'GSTIN/UIN of Recipient': row['gst']?.toString() ?? '',
          'Receiver Name': row['customerName']?.toString() ?? '',
          'Invoice Number': row['invoice']?.toString() ?? '',
          'Invoice date': _invoiceDate(row['order_date']),

          // Same as React: Math.round(invoiceValue)
          'Invoice Value': invoiceValue.round(),

          'Place Of Supply': _placeOfSupply(row['address']),
          'Reverse Charge': 'N',
          'Applicable % of Tax Rate': '',
          'Invoice Type': '',
          'E-Commerce GSTIN': '',
          'Rate': taxRate,
          'Taxable Value': double.parse(taxableValue.toStringAsFixed(4)),
          'Cess Amount': '',
        };

        if (gstConfirm == 'YES') {
          b2bRows.add({
            ...baseRow,
            'Invoice Type': 'Regular B2B',
          });
        } else if (gstConfirm == 'NO GST') {
          b2cRows.add({
            ...baseRow,
            'Invoice Type': 'Regular B2C',
          });
        } else {
          final gst = row['gst']?.toString() ?? '';

          if (gst.isNotEmpty) {
            b2bRows.add({
              ...baseRow,
              'Invoice Type': 'Regular B2B',
            });
          } else {
            b2cRows.add({
              ...baseRow,
              'Invoice Type': 'Regular B2C',
            });
          }
        }
      });
    }

    return {
      'b2bRows': b2bRows,
      'b2cRows': b2cRows,
    };
  }

  List<Map<String, dynamic>> buildB2CSummaryRows() {
    final rows = buildB2BB2CRows()['b2cRows'] ?? [];
    final summaryMap = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final placeOfSupply = row['Place Of Supply']?.toString() ?? '';
      final rate = row['Rate']?.toString() ?? '0';
      final taxableValue = _toDouble(row['Taxable Value']);

      final key = '$placeOfSupply-$rate';

      summaryMap.putIfAbsent(key, () {
        return {
          'Type': 'OE',
          'Place Of Supply': placeOfSupply,
          'Applicable % of Tax Rate': '',
          'Rate': rate,
          'Taxable Value': 0.0,
          'Cess Amount': '',
          'E-Commerce GSTIN': '',
        };
      });

      summaryMap[key]!['Taxable Value'] =
          _toDouble(summaryMap[key]!['Taxable Value']) + taxableValue;
    }

    final summaryRows = summaryMap.values.map((row) {
      return {
        ...row,
        'Taxable Value': double.parse(
          _toDouble(row['Taxable Value']).toStringAsFixed(4),
        ),
      };
    }).toList();

    summaryRows.sort((a, b) {
      final placeA = (a['Place Of Supply'] ?? '').toString().toLowerCase();
      final placeB = (b['Place Of Supply'] ?? '').toString().toLowerCase();

      final placeCompare = placeA.compareTo(placeB);

      if (placeCompare != 0) return placeCompare;

      final rateA = _toDouble(a['Rate']);
      final rateB = _toDouble(b['Rate']);

      return rateA.compareTo(rateB);
    });

    return summaryRows;
  }

  List<Map<String, dynamic>> buildHSNRows() {
    final summaryMap = <String, Map<String, dynamic>>{};

    for (final row in gstData) {
      final items = row['items'];

      if (items is! List) continue;

      for (final item in items) {
        if (item is! Map) continue;

        final mappedItem = Map<String, dynamic>.from(item);

        final key =
            '${mappedItem['name']}-${mappedItem['product']}-${mappedItem['hsn']}-${mappedItem['tax']}';

        summaryMap.putIfAbsent(key, () {
          return {
            'Description': mappedItem['name']?.toString() ?? '',
            'HSN': mappedItem['hsn']?.toString() ?? '',
            'Measurement': mappedItem['unit']?.toString() ?? 'PCS',
            'Total Quantity': 0.0,
            'Tax Rate': _toDouble(mappedItem['tax']),
            'Total Taxable Value': 0.0,
            'IGST': 0.0,
            'Central Tax': 0.0,
            'State Tax': 0.0,
            'Cess': 0.0,
            'TOTAL': 0.0,
          };
        });

        final taxable = _toDouble(mappedItem['exclude_price']);
        final qty = _toDouble(mappedItem['quantity']);
        final rate = _toDouble(mappedItem['tax']);
        final taxableTotal = taxable * qty;
        final taxAmount = (taxableTotal * rate) / 100;

        summaryMap[key]!['Total Quantity'] =
            _toDouble(summaryMap[key]!['Total Quantity']) + qty;

        summaryMap[key]!['Total Taxable Value'] =
            _toDouble(summaryMap[key]!['Total Taxable Value']) + taxableTotal;

        final gst = row['gst']?.toString() ?? '';

        if (gst.isNotEmpty) {
          summaryMap[key]!['IGST'] =
              _toDouble(summaryMap[key]!['IGST']) + taxAmount;
        } else {
          summaryMap[key]!['Central Tax'] =
              _toDouble(summaryMap[key]!['Central Tax']) + (taxAmount / 2);

          summaryMap[key]!['State Tax'] =
              _toDouble(summaryMap[key]!['State Tax']) + (taxAmount / 2);
        }

        summaryMap[key]!['TOTAL'] =
            _toDouble(summaryMap[key]!['Total Taxable Value']) +
                _toDouble(summaryMap[key]!['IGST']) +
                _toDouble(summaryMap[key]!['Central Tax']) +
                _toDouble(summaryMap[key]!['State Tax']) +
                _toDouble(summaryMap[key]!['Cess']);
      }
    }

    return summaryMap.values.map((row) {
      return {
        ...row,
        'Total Quantity':
            double.parse(_toDouble(row['Total Quantity']).toStringAsFixed(2)),
        'Total Taxable Value': double.parse(
            _toDouble(row['Total Taxable Value']).toStringAsFixed(2)),
        'IGST': double.parse(_toDouble(row['IGST']).toStringAsFixed(2)),
        'Central Tax':
            double.parse(_toDouble(row['Central Tax']).toStringAsFixed(2)),
        'State Tax':
            double.parse(_toDouble(row['State Tax']).toStringAsFixed(2)),
        'Cess': double.parse(_toDouble(row['Cess']).toStringAsFixed(2)),
        'TOTAL': double.parse(_toDouble(row['TOTAL']).toStringAsFixed(2)),
      };
    }).toList();
  }

  void appendHeader(Sheet sheet, List<String> headers, {int rowIndex = 0}) {
    sheet.appendRow(headers);

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
      );

      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
  }

  void appendMapRows(
    Sheet sheet,
    List<String> headers,
    List<Map<String, dynamic>> rows,
  ) {
    for (final row in rows) {
      sheet.appendRow(
        headers.map((header) {
          final value = row[header];

          if (value is int) return value;
          if (value is double) return value;
          if (value is num) return value.toDouble();

          return value?.toString() ?? '';
        }).toList(),
      );
    }
  }

  Future<void> saveExcelFile({
    required Excel excel,
    required String fileName,
  }) async {
    final bytes = excel.encode();

    if (bytes == null) {
      _showMessage('Export failed', isError: true);
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    _showMessage('Excel exported successfully');
    await OpenFilex.open(filePath);
  }

  Future<void> exportB2BExcel() async {
    if (exportingB2B) return;

    if (gstData.isEmpty) {
      _showMessage('No data to export');
      return;
    }

    setState(() {
      exportingB2B = true;
    });

    try {
      final rows = buildB2BB2CRows()['b2bRows'] ?? [];

      if (rows.isEmpty) {
        _showMessage('No B2B data found');
        return;
      }

      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final sheet = excel['B2B'];
      appendHeader(sheet, b2bB2CHeaders);
      appendMapRows(sheet, b2bB2CHeaders, rows);

      await saveExcelFile(
        excel: excel,
        fileName: 'GST_B2B_${getExportFileBaseName()}.xlsx',
      );
    } catch (_) {
      _showMessage('B2B export failed', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          exportingB2B = false;
        });
      }
    }
  }

  Future<void> exportB2CDetailedExcel() async {
    if (exportingB2CDetailed) return;

    if (gstData.isEmpty) {
      _showMessage('No data to export');
      return;
    }

    setState(() {
      exportingB2CDetailed = true;
    });

    try {
      final rows = buildB2BB2CRows()['b2cRows'] ?? [];

      if (rows.isEmpty) {
        _showMessage('No B2C data found');
        return;
      }

      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final sheet = excel['B2C'];
      appendHeader(sheet, b2bB2CHeaders);
      appendMapRows(sheet, b2bB2CHeaders, rows);

      await saveExcelFile(
        excel: excel,
        fileName: 'GST_B2C_Detailed_${getExportFileBaseName()}.xlsx',
      );
    } catch (_) {
      _showMessage('B2C detailed export failed', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          exportingB2CDetailed = false;
        });
      }
    }
  }

  Future<void> exportB2CExcel() async {
    if (exportingB2C) return;

    if (gstData.isEmpty) {
      _showMessage('No data to export');
      return;
    }

    setState(() {
      exportingB2C = true;
    });

    try {
      final rows = buildB2CSummaryRows();

      if (rows.isEmpty) {
        _showMessage('No B2C data found');
        return;
      }

      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final sheet = excel['B2C'];

      final titleCompany = selectedCompany.isNotEmpty
          ? selectedCompanyName.toUpperCase()
          : 'BEPOSITIVE';

      final title = 'B2C $titleCompany ${_monthYear(startDate)}';

      sheet.appendRow([title]);
      sheet.appendRow(b2cSummaryHeaders);

      final titleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );

      titleCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      for (int i = 0; i < b2cSummaryHeaders.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
        );

        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      appendMapRows(sheet, b2cSummaryHeaders, rows);

      await saveExcelFile(
        excel: excel,
        fileName: 'GST_B2C_${getExportFileBaseName()}.xlsx',
      );
    } catch (_) {
      _showMessage('B2C export failed', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          exportingB2C = false;
        });
      }
    }
  }

  Future<void> exportHSNExcel() async {
    if (exportingHSN) return;

    if (gstData.isEmpty) {
      _showMessage('No data to export');
      return;
    }

    setState(() {
      exportingHSN = true;
    });

    try {
      final rows = buildHSNRows();

      if (rows.isEmpty) {
        _showMessage('No HSN data found');
        return;
      }

      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final sheet = excel['HSN Summary'];
      appendHeader(sheet, hsnHeaders);
      appendMapRows(sheet, hsnHeaders, rows);

      await saveExcelFile(
        excel: excel,
        fileName: 'GST_HSN_${getExportFileBaseName()}.xlsx',
      );
    } catch (_) {
      _showMessage('HSN export failed', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          exportingHSN = false;
        });
      }
    }
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        startDate = picked;
      });
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  Future<void> refreshPage() async {
    if (startDate != null && endDate != null) {
      await fetchGSTReport();
    } else {
      await fetchCompanies();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        content: Text(message),
      ),
    );
  }

  Widget dateBox({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? label : _apiDate(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value == null ? Colors.grey.shade600 : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget companyDropdown() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCompany,
          isExpanded: true,
          icon: companyLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_down),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('All Companies'),
            ),
            ...companyList.map((company) {
              return DropdownMenuItem<String>(
                value: company['id']?.toString() ?? '',
                child: Text(
                  getCompanyName(company),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: companyLoading
              ? null
              : (value) {
                  setState(() {
                    selectedCompany = value ?? '';
                  });
                },
        ),
      ),
    );
  }

  Widget actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool busy = false,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 17),
        label: Text(
          busy ? 'Please wait...' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade800.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GST Report: B2B, B2C',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedCompanyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Total: $totalCount',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;

              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      child: dateBox(
                        label: 'Start Date',
                        value: startDate,
                        onTap: pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: dateBox(
                        label: 'End Date',
                        value: endDate,
                        onTap: pickEndDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: companyDropdown()),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: actionButton(
                        label: 'Filter',
                        icon: Icons.filter_alt_outlined,
                        color: Colors.blue.shade700,
                        onTap: fetchGSTReport,
                        busy: loading,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : clearFilter,
                        icon: const Icon(Icons.close, size: 17),
                        label: const Text(
                          'Clear',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade800,
                          side: BorderSide(color: Colors.blueGrey.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: dateBox(
                          label: 'Start Date',
                          value: startDate,
                          onTap: pickStartDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: dateBox(
                          label: 'End Date',
                          value: endDate,
                          onTap: pickEndDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  companyDropdown(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: actionButton(
                          label: 'Filter',
                          icon: Icons.filter_alt_outlined,
                          color: Colors.blue.shade700,
                          onTap: fetchGSTReport,
                          busy: loading,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : clearFilter,
                            icon: const Icon(Icons.close, size: 17),
                            label: const Text(
                              'Clear',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueGrey.shade800,
                              side: BorderSide(color: Colors.blueGrey.shade200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildExportButtons() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: actionButton(
                  label: 'Export B2B Excel',
                  icon: Icons.file_download_outlined,
                  color: Colors.green.shade700,
                  onTap: totalCount == 0 ? null : exportB2BExcel,
                  busy: exportingB2B,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: actionButton(
                  label: 'Export B2C Excel',
                  icon: Icons.file_download_outlined,
                  color: Colors.blue.shade700,
                  onTap: totalCount == 0 ? null : exportB2CExcel,
                  busy: exportingB2C,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: actionButton(
                  label: 'Export B2C Detailed',
                  icon: Icons.file_download_outlined,
                  color: Colors.indigo.shade600,
                  onTap: totalCount == 0 ? null : exportB2CDetailedExcel,
                  busy: exportingB2CDetailed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: actionButton(
                  label: 'Export HSN Excel',
                  icon: Icons.file_download_outlined,
                  color: Colors.orange.shade700,
                  onTap: totalCount == 0 ? null : exportHSNExcel,
                  busy: exportingHSN,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildShowingCard() {
    final firstItem = totalCount == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
    final lastItem = currentPage * pageSize > totalCount
        ? totalCount
        : currentPage * pageSize;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fa),
        border: Border.all(color: const Color(0xffe5e7eb)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Showing $firstItem to $lastItem of $totalCount records',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget tableCell(
    String value, {
    bool bold = false,
    double width = 150,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: bold ? Colors.blueGrey.shade900 : Colors.black87,
        ),
      ),
    );
  }

  Widget buildTableHeader() {
    return Container(
      color: Colors.blue.shade50,
      child: Row(
        children: [
          tableCell('#', bold: true, width: 60, alignment: Alignment.center),
          tableCell('GSTIN/UIN Number', bold: true, width: 170),
          tableCell('Receiver Name', bold: true, width: 190),
          tableCell('Invoice Number', bold: true, width: 160),
          tableCell('Invoice Date', bold: true, width: 130),
          tableCell('Invoice Value', bold: true, width: 130),
          tableCell('Place of Supply', bold: true, width: 190),
          tableCell('Reverse Charge', bold: true, width: 140),
          tableCell('Applicable % of Tax', bold: true, width: 170),
          tableCell('Invoice Type', bold: true, width: 160),
          tableCell('E-Commerce GSTIN', bold: true, width: 170),
          tableCell('Rate', bold: true, width: 100),
          tableCell('Taxable Value', bold: true, width: 140),
          tableCell('Cess Amount', bold: true, width: 130),
        ],
      ),
    );
  }

  Widget buildTableRow(Map<String, dynamic> row, int index) {
    return Container(
      color: index.isEven ? Colors.white : Colors.grey.shade50,
      child: Row(
        children: [
          tableCell(
            row['index']?.toString() ?? '',
            width: 60,
            alignment: Alignment.center,
          ),
          tableCell(row['gst']?.toString() ?? '', width: 170),
          tableCell(row['receiver']?.toString() ?? '', width: 190),
          tableCell(row['invoice']?.toString() ?? '', width: 160),
          tableCell(row['date']?.toString() ?? '', width: 130),
          tableCell(row['total_amount']?.toString() ?? '', width: 130),
          tableCell(row['placeOfSupply']?.toString() ?? '', width: 190),
          tableCell('N', width: 140),
          tableCell('', width: 170),
          tableCell(row['invoiceType']?.toString() ?? '', width: 160),
          tableCell('', width: 170),
          tableCell(row['taxRate']?.toString() ?? '', width: 100),
          tableCell(row['taxableValue']?.toString() ?? '', width: 140),
          tableCell('', width: 130),
        ],
      ),
    );
  }

  Widget buildTable() {
    final rows = tableRows();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 2060,
          child: Column(
            children: [
              buildTableHeader(),
              if (loading)
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                )
              else if (rows.isEmpty)
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const Text(
                    'No records found',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(rows.length, (index) {
                    return buildTableRow(rows[index], index);
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Page $currentPage of $totalPages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: currentPage > 1 && !loading
                ? () {
                    setState(() {
                      currentPage--;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$currentPage / $totalPages',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: currentPage < totalPages && !loading
                ? () {
                    setState(() {
                      currentPage++;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
        title: const Text(
          'GST Report',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : refreshPage,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshPage,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            buildHeader(),
            const SizedBox(height: 16),
            buildFilters(),
            const SizedBox(height: 16),
            buildExportButtons(),
            const SizedBox(height: 16),
            buildShowingCard(),
            const SizedBox(height: 16),
            buildTable(),
            buildPagination(),
          ],
        ),
      ),
    );
  }
}
