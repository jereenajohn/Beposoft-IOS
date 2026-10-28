import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:beposoft/pages/ADMIN/Operation_executive_dashboard.dart';
import 'package:share_plus/share_plus.dart';
import 'package:beposoft/loginpage.dart';

import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';

import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';

import 'package:beposoft/pages/ACCOUNTS/dgm.dart';

import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';

import 'package:beposoft/pages/ACCOUNTS/profilepage.dart';

import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';

import 'package:beposoft/pages/BDM/bdm_dshboard.dart';

import 'package:beposoft/pages/BDO/bdo_dashboard.dart';

import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';

import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';

import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:intl/intl.dart';

class daily_goods_movement extends StatefulWidget {
  @override
  _dailygoodspageState createState() => _dailygoodspageState();
}

class _dailygoodspageState extends State<daily_goods_movement> {
  List<Map<String, dynamic>> goods = [];

  List<Map<String, dynamic>> filteredOrders = [];

  List<Map<String, dynamic>> overallTopProducts = [];

  bool showAllTopProducts = false;

  bool isExporting = false;

  int currentPage = 1;

  int totalCount = 0;

  String? nextPageUrl;

  String? previousPageUrl;

  bool isPaginationLoading = false;

  bool isLoading = true;

  String? errorMessage;

  DateTime? selectedDate; // For single date filter

  DateTime? startDate; // For date range filter

  DateTime? endDate; // For date range filter

// //dateselection

//    DateTime selectedDate = DateTime.now();

//   Future<void> _selectDate(BuildContext context) async {

//

//     final DateTime? picked = await showDatePicker(

//       context: context,

//       initialDate: selectedDate,

//       firstDate: DateTime(2000),

//       lastDate: DateTime(2101),

//     );

//     if (picked != null && picked != selectedDate) {

//       setState(() {

//         selectedDate = picked;

//

//       });

//     }

//   }

  Future<void> getgoodsdetails({
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
  }) async {
    setState(() {
      isLoading = true;

      isPaginationLoading = true;

      errorMessage = null;
    });

    try {
      final token = await getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;

          isPaginationLoading = false;

          errorMessage = "Token not found. Please login again.";
        });

        return;
      }

      final Map<String, String> queryParams = {
        'page': page.toString(),
      };

      if (fromDate != null && toDate != null) {
        queryParams['from_date'] = DateFormat('yyyy-MM-dd').format(fromDate);

        queryParams['to_date'] = DateFormat('yyyy-MM-dd').format(toDate);
      }

      final uri = Uri.parse(
        '$api/api/pagenated/warehouse/box/detail/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final productsData = jsonDecode(response.body);

        if (productsData is! Map<String, dynamic>) {
          setState(() {
            goods = [];

            filteredOrders = [];

            overallTopProducts = [];

            isLoading = false;

            isPaginationLoading = false;

            errorMessage = "Invalid API response format.";
          });

          return;
        }

        final results = productsData['results'];

        if (results is! Map<String, dynamic>) {
          setState(() {
            goods = [];

            filteredOrders = [];

            overallTopProducts = [];

            isLoading = false;

            isPaginationLoading = false;

            errorMessage = "Invalid results format.";
          });

          return;
        }

        final summary = results['summary'];

        final data = results['data'];

        if (data is! List) {
          setState(() {
            goods = [];

            filteredOrders = [];

            overallTopProducts = [];

            isLoading = false;

            isPaginationLoading = false;

            errorMessage = "Invalid data format.";
          });

          return;
        }

        final List<Map<String, dynamic>> goodsList = [];

        final List<Map<String, dynamic>> topProductsList = [];

        if (summary is Map<String, dynamic>) {
          final topProducts = summary['top_5_products'];

          if (topProducts is List) {
            for (var product in topProducts) {
              if (product is Map<String, dynamic>) {
                topProductsList.add({
                  'product_id': product['product_id'],
                  'product_name': product['product_name'] ?? '',
                  'display_name':
                      product['display_name'] ?? product['product_name'] ?? '',
                  'total_quantity': product['total_quantity'] ?? 0,
                  'total_amount': product['total_amount'] ?? 0,
                });
              }
            }
          }
        }

        for (var productData in data) {
          if (productData is! Map<String, dynamic>) {
            continue;
          }

          final totalWeightRaw = productData['total_weight'] ?? 0;

          final totalWeight = double.tryParse(totalWeightRaw.toString()) ?? 0.0;

          final List<Map<String, dynamic>> dateWiseTopProducts = [];

          final topProducts = productData['top_5_products'];

          if (topProducts is List) {
            for (var product in topProducts) {
              if (product is Map<String, dynamic>) {
                dateWiseTopProducts.add({
                  'product_id': product['product_id'],
                  'product_name': product['product_name'] ?? '',
                  'variant_id': product['variant_id'],
                  'variant_name': product['variant_name'],
                  'display_name':
                      product['display_name'] ?? product['product_name'] ?? '',
                  'total_quantity': product['total_quantity'] ?? 0,
                  'total_amount': product['total_amount'] ?? 0,
                });
              }
            }
          }

          goodsList.add({
            'shipped_date': productData['shipped_date'] ?? '',
            'total_weight': (totalWeight / 1000).toStringAsFixed(2),
            'total_boxes': productData['total_boxes'] ?? 0,
            'total_volume_weight': productData['total_volume_weight'] ?? 0,
            'total_shipping_charge': productData['total_shipping_charge'] ?? 0,
            'total_actual_weight': productData['total_actual_weight'] ?? 0,
            'total_parcel_amount': productData['total_parcel_amount'] ?? 0,
            'total_invoice_count': productData['total_invoice_count'] ?? 0,
            'total_order_amount': productData['total_order_amount'] ?? 0,
            'top_5_products': dateWiseTopProducts,
          });
        }

        setState(() {
          currentPage = page;

          totalCount = productsData['count'] ?? 0;

          nextPageUrl = productsData['next'];

          previousPageUrl = productsData['previous'];

          goods = goodsList;

          filteredOrders = goodsList;

          overallTopProducts = topProductsList;

          showAllTopProducts = false;

          isLoading = false;

          isPaginationLoading = false;
        });
      } else {
        setState(() {
          goods = [];

          filteredOrders = [];

          overallTopProducts = [];

          isLoading = false;

          isPaginationLoading = false;

          errorMessage =
              "Failed to fetch data. Status code: ${response.statusCode}";
        });
      }
    } catch (error) {
      setState(() {
        goods = [];

        filteredOrders = [];

        overallTopProducts = [];

        isLoading = false;

        isPaginationLoading = false;

        errorMessage = "Something went wrong: $error";
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllGoodsForExcel() async {
    final token = await getTokenFromPrefs();

    if (token == null || token.isEmpty) {
      throw Exception('Token not found. Please login again.');
    }

    final List<Map<String, dynamic>> exportRows = [];
    int page = 1;
    bool hasNextPage = true;

    while (hasNextPage) {
      final Map<String, String> queryParams = {
        'page': page.toString(),
      };

      if (startDate != null && endDate != null) {
        queryParams['from_date'] = DateFormat('yyyy-MM-dd').format(startDate!);
        queryParams['to_date'] = DateFormat('yyyy-MM-dd').format(endDate!);
      }

      final uri = Uri.parse(
        '$api/api/pagenated/warehouse/box/detail/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch export data. Status code: ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid export response format.');
      }

      final results = decoded['results'];
      if (results is! Map<String, dynamic>) {
        throw Exception('Invalid export results format.');
      }

      final data = results['data'];
      if (data is! List) {
        throw Exception('Invalid export data format.');
      }

      for (var productData in data) {
        if (productData is! Map<String, dynamic>) {
          continue;
        }

        final totalWeightRaw = productData['total_weight'] ?? 0;
        final totalWeight = double.tryParse(totalWeightRaw.toString()) ?? 0.0;

        exportRows.add({
          'shipped_date': productData['shipped_date'] ?? '',
          'total_boxes': productData['total_boxes'] ?? 0,
          'total_weight': totalWeight / 1000,
          'total_volume_weight': productData['total_volume_weight'] ?? 0,
          'total_shipping_charge': productData['total_shipping_charge'] ?? 0,
          'total_actual_weight': productData['total_actual_weight'] ?? 0,
          'total_parcel_amount': productData['total_parcel_amount'] ?? 0,
          'total_invoice_count': productData['total_invoice_count'] ?? 0,
          'total_order_amount': productData['total_order_amount'] ?? 0,
        });
      }

      final next = decoded['next'];
      hasNextPage = next != null && next.toString().trim().isNotEmpty;
      page++;

      if (page > 1000) {
        throw Exception(
            'Export stopped because pagination exceeded 1000 pages.');
      }
    }

    return exportRows;
  }

  String _xmlEscape(dynamic value) {
    return value
        .toString()
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _excelColumnName(int columnNumber) {
    int number = columnNumber;
    String result = '';

    while (number > 0) {
      number--;
      result = String.fromCharCode(65 + (number % 26)) + result;
      number ~/= 26;
    }

    return result;
  }

  double _toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  Uint8List _buildExcelBytes(List<Map<String, dynamic>> rows) {
    final headers = <String>[
      'Shipped Date',
      'Total Boxes',
      'Total A/W (kg)',
      'Volume Weight',
      'Shipping Charge',
      'Total Actual Weight',
      'Total Parcel Amount',
      'Total Invoices',
      'Total Order Amount',
    ];

    final columnWidths = <double>[
      16,
      14,
      16,
      18,
      18,
      21,
      20,
      16,
      21,
    ];

    final sheetRows = StringBuffer();

    sheetRows.write('<row r="1">');
    for (int i = 0; i < headers.length; i++) {
      final cellRef = '${_excelColumnName(i + 1)}1';
      sheetRows.write(
        '<c r="$cellRef" t="inlineStr" s="1"><is><t>${_xmlEscape(headers[i])}</t></is></c>',
      );
    }
    sheetRows.write('</row>');

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final item = rows[rowIndex];
      final excelRow = rowIndex + 2;

      final values = <dynamic>[
        item['shipped_date'] ?? '',
        _toDouble(item['total_boxes']),
        _toDouble(item['total_weight']),
        _toDouble(item['total_volume_weight']),
        _toDouble(item['total_shipping_charge']),
        _toDouble(item['total_actual_weight']),
        _toDouble(item['total_parcel_amount']),
        _toDouble(item['total_invoice_count']),
        _toDouble(item['total_order_amount']),
      ];

      sheetRows.write('<row r="$excelRow">');

      for (int columnIndex = 0; columnIndex < values.length; columnIndex++) {
        final cellRef = '${_excelColumnName(columnIndex + 1)}$excelRow';
        final value = values[columnIndex];

        if (columnIndex == 0) {
          sheetRows.write(
            '<c r="$cellRef" t="inlineStr" s="2"><is><t>${_xmlEscape(value)}</t></is></c>',
          );
        } else {
          sheetRows.write(
            '<c r="$cellRef" s="2"><v>${_toDouble(value)}</v></c>',
          );
        }
      }

      sheetRows.write('</row>');
    }

    final cols = StringBuffer();
    cols.write('<cols>');
    for (int i = 0; i < columnWidths.length; i++) {
      final column = i + 1;
      cols.write(
        '<col min="$column" max="$column" width="${columnWidths[i]}" customWidth="1"/>',
      );
    }
    cols.write('</cols>');

    final lastRow = rows.length + 1;

    final worksheetXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetViews>
    <sheetView workbookViewId="0">
      <pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>
    </sheetView>
  </sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  ${cols.toString()}
  <sheetData>${sheetRows.toString()}</sheetData>
  <autoFilter ref="A1:I$lastRow"/>
</worksheet>''';

    const contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';

    const relationshipsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

    const workbookXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Daily Goods Movement" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

    const workbookRelationshipsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/><name val="Calibri"/><family val="2"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1976D2"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border>
      <left style="thin"><color rgb="FFD9E2F3"/></left>
      <right style="thin"><color rgb="FFD9E2F3"/></right>
      <top style="thin"><color rgb="FFD9E2F3"/></top>
      <bottom style="thin"><color rgb="FFD9E2F3"/></bottom>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="3">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';

    final archive = Archive();

    void addTextFile(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addTextFile('[Content_Types].xml', contentTypesXml);
    addTextFile('_rels/.rels', relationshipsXml);
    addTextFile('xl/workbook.xml', workbookXml);
    addTextFile('xl/_rels/workbook.xml.rels', workbookRelationshipsXml);
    addTextFile('xl/styles.xml', stylesXml);
    addTextFile('xl/worksheets/sheet1.xml', worksheetXml);

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('Failed to generate Excel file.');
    }

    return Uint8List.fromList(encoded);
  }

  Future<void> _exportToExcel() async {
    if (isExporting) {
      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final exportRows = await _fetchAllGoodsForExcel();

      if (exportRows.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data available to export.'),
          ),
        );
        return;
      }

      final Uint8List excelBytes = _buildExcelBytes(exportRows);

      final String fileName =
          'Daily_Goods_Movement_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      if (!mounted) return;

      final RenderBox? box = context.findRenderObject() as RenderBox?;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              excelBytes,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          fileNameOverrides: [fileName],
          title: 'Daily Goods Movement',
          subject: 'Daily Goods Movement Excel Report',
          sharePositionOrigin: box != null && box.hasSize
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel export failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getString('token');
  }

  drower d = drower();

  Widget _buildDropdownTile(
      BuildContext context, String title, List<String> options) {
    return ExpansionTile(
      title: Text(title),
      children: options.map((option) {
        return ListTile(
          title: Text(option),
          onTap: () {
            Navigator.pop(context);

            d.navigateToSelectedPage(
                context, option); // Navigate to selected page
          },
        );
      }).toList(),
    );
  }

  Future<void> _clearDateFilter() async {
    setState(() {
      startDate = null;

      endDate = null;

      currentPage = 1;

      nextPageUrl = null;

      previousPageUrl = null;
    });

    await getgoodsdetails(page: 1);
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove('userId');

    await prefs.remove('token');

    // Show a snackbar with the logout success message

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logout successfully'),

        duration: Duration(
            seconds: 2), // Optional: Set how long the snackbar will be visible
      ),
    );

    // Navigate to the HomePage

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => login()),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;

        endDate = picked.end;
      });

      await getgoodsdetails(
        fromDate: picked.start,
        toDate: picked.end,
        page: 1,
      );
    }
  }

  @override
  void initState() {
    super.initState();

    getgoodsdetails();
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getString('department');
  }

  Future<void> _navigateBack() async {
    final dep = await getdepFromPrefs();

    if (dep == "BDO") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                bdo_dashbord()), // Replace AnotherPage with your target page
      );
    } else if (dep == "OPERATIONS") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OperationsExecutiveDashboard()),
      );
    } else if (dep == "BDM") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                bdm_dashbord()), // Replace AnotherPage with your target page
      );
    } else if (dep == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    } else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => cso_dashboard()),
      );
    } else if (dep == "warehouse") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                WarehouseDashboard()), // Replace AnotherPage with your target page
      );
    } else if (dep == "CEO") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                ceo_dashboard()), // Replace AnotherPage with your target page
      );
    } else if (dep == "COO") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                ceo_dashboard()), // Replace AnotherPage with your target page
      );
    } else if (dep == "Warehouse Admin") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                WarehouseAdmin()), // Replace AnotherPage with your target page
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => dashboard()),
      );
    }
  }

  Widget _buildPaginationControls() {
    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Page $currentPage  •  Total $totalCount",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: previousPageUrl == null || isPaginationLoading
                ? null
                : () {
                    getgoodsdetails(
                      fromDate: startDate,
                      toDate: endDate,
                      page: currentPage - 1,
                    );
                  },
            icon: const Icon(Icons.arrow_back_ios, size: 13),
            label: const Text(
              "Previous",
              style: TextStyle(fontSize: 11),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: nextPageUrl == null || isPaginationLoading
                ? null
                : () {
                    getgoodsdetails(
                      fromDate: startDate,
                      toDate: endDate,
                      page: currentPage + 1,
                    );
                  },
            icon: const Icon(Icons.arrow_forward_ios, size: 13),
            label: const Text(
              "Next",
              style: TextStyle(fontSize: 11),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallTopProducts() {
    if (overallTopProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    String title = "Top 10 Products";

    if (startDate != null && endDate != null) {
      title =
          "Top 10 Products (${DateFormat('dd-MM-yyyy').format(startDate!)} to ${DateFormat('dd-MM-yyyy').format(endDate!)})";
    }

    final List<Map<String, dynamic>> visibleProducts = showAllTopProducts
        ? overallTopProducts
        : overallTopProducts.take(2).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade400,
                width: 0.8,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowHeight: 34,
                    headingRowColor: MaterialStateColor.resolveWith(
                      (states) => Colors.blue,
                    ),
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        width: 0.5,
                        color: Colors.grey.shade400,
                      ),
                      verticalInside: BorderSide(
                        width: 0.5,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    columnSpacing: 10,
                    columns: const [
                      DataColumn(
                        label: SizedBox(
                          width: 55,
                          child: Text(
                            "Sl No",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 230,
                          child: Text(
                            "Product",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 70,
                          child: Text(
                            "Qty",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 100,
                          child: Text(
                            "Amount",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: List<DataRow>.generate(
                      visibleProducts.length,
                      (index) {
                        final product = visibleProducts[index];

                        final String productName =
                            product['display_name']?.toString().isNotEmpty ==
                                    true
                                ? product['display_name'].toString()
                                : product['product_name']?.toString() ?? '-';

                        final String quantity =
                            product['total_quantity']?.toString() ?? '0';

                        final double amount = double.tryParse(
                              product['total_amount']?.toString() ?? '0',
                            ) ??
                            0.0;

                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 55,
                                child: Text(
                                  "${index + 1}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 230,
                                child: Text(
                                  productName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 70,
                                child: Text(
                                  quantity,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  amount.toStringAsFixed(2),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                if (overallTopProducts.length > 2)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade400,
                          width: 0.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          showAllTopProducts = !showAllTopProducts;
                        });
                      },
                      icon: Icon(
                        showAllTopProducts
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.blue,
                      ),
                      label: Text(
                        showAllTopProducts ? "See Less" : "See More",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent the swipe-back gesture (and back button)

        _navigateBack();

        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Daily Goods Movement",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back), // Custom back arrow

            onPressed: () async {
              final dep = await getdepFromPrefs();

              if (dep == "BDO") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          bdo_dashbord()), // Replace AnotherPage with your target page
                );
              } else if (dep == "BDM") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          bdm_dashbord()), // Replace AnotherPage with your target page
                );
              } else if (dep == "OPERATIONS") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OperationsExecutiveDashboard()),
                );
              } else if (dep == "warehouse") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          WarehouseDashboard()), // Replace AnotherPage with your target page
                );
              } else if (dep == "COO") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ceo_dashboard()),
                );
              } else if (dep == "CSO") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => cso_dashboard()),
                );
              } else if (dep == "CEO") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          ceo_dashboard()), // Replace AnotherPage with your target page
                );
              } else if (dep == "COO") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          ceo_dashboard()), // Replace AnotherPage with your target page
                );
              } else if (dep == "Warehouse Admin") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          WarehouseAdmin()), // Replace AnotherPage with your target page
                );
              } else {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          dashboard()), // Replace AnotherPage with your target page
                );
              }
            },
          ),
          actions: [
            isExporting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Export Excel',
                    onPressed: _exportToExcel,
                    icon: const Icon(
                      Icons.download,
                      color: Colors.green,
                    ),
                  ),
            IconButton(
              icon: Image.asset('lib/assets/profile.png'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditProfileScreen()));
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Padding(

            //   padding: const EdgeInsets.all(10),

            //   child: Container(

            //           height: 46,

            //           decoration: BoxDecoration(

            //             border: Border.all(

            //   color: Colors.blue,

            //   width: 1.0,

            //             ),

            //             borderRadius: BorderRadius.circular(8.0),

            //           ),

            //           child: Row(

            //             children: [

            //   SizedBox(width: 25,),

            //   Text(

            //     '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',

            //     style: TextStyle(fontSize:12,color:Color.fromARGB(255, 116, 116, 116)),

            //   ),

            //   SizedBox(width: 162,),

            //   GestureDetector(

            //     onTap: () {

            //     _selectDate(context);

            //

            //     },

            //     child: Container(

            //       padding: const EdgeInsets.only(left: 55),

            //       child: Icon(Icons.date_range)),

            //   ),

            //             ],

            //           ),

            //         ),

            // ),

            SizedBox(
              height: 10,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              startDate != null && endDate != null
                                  ? "${DateFormat('dd-MM-yyyy').format(startDate!)} to ${DateFormat('dd-MM-yyyy').format(endDate!)}"
                                  : "All dates",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _selectDateRange(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    child: const Text(
                      'Filter',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _clearDateFilter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            _buildOverallTopProducts(),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : filteredOrders.isEmpty
                          ? const Center(
                              child: Text(
                                "No goods movement data found",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(5.0),
                              itemCount: filteredOrders.length,
                              itemBuilder: (context, index) {
                                final item = filteredOrders[index];

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Dgm(
                                          shipped_date: item['shipped_date'],
                                          topFiveProducts:
                                              List<Map<String, dynamic>>.from(
                                            item['top_5_products'] ?? [],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 15),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade100,
                                          Colors.blue.shade300,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Shipped Date: ${item['shipped_date']}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color.fromARGB(
                                                      255, 32, 0, 0),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.add_box,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Total Boxes: ${item['total_boxes']}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.fitness_center,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Total A/W: ${item['total_weight']} kg",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.fitness_center_sharp,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Volume Weight: ${item['total_volume_weight']} kg",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.attach_money,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Shipping Charge: ₹${item['total_shipping_charge']}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.receipt_long,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Total Invoices: ${item['total_invoice_count']}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.currency_rupee,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Total Order Amount: ₹${item['total_order_amount']}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            _buildPaginationControls(),
          ],
        ),
      ),
    );
  }
}
