import 'dart:convert';

import 'dart:io';

import 'package:beposoft/loginpage.dart';

import 'package:beposoft/pages/ACCOUNTS/add_attribute.dart';

import 'package:beposoft/pages/ACCOUNTS/add_bank.dart';

import 'package:beposoft/pages/ACCOUNTS/add_company.dart';

import 'package:beposoft/pages/ACCOUNTS/add_department.dart';

import 'package:beposoft/pages/ACCOUNTS/add_family.dart';

import 'package:beposoft/pages/ACCOUNTS/add_services.dart';

import 'package:beposoft/pages/ACCOUNTS/add_state.dart';

import 'package:beposoft/pages/ACCOUNTS/add_supervisor.dart';

import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';

import 'package:beposoft/pages/ACCOUNTS/customer.dart';

import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';

import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';

import 'package:beposoft/pages/ACCOUNTS/methods.dart';

import 'package:beposoft/pages/ACCOUNTS/order.review.dart';
import 'package:beposoft/pages/ADMIN/Operation_executive_dashboard.dart';

import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';

import 'package:beposoft/pages/BDM/bdm_dshboard.dart';

import 'package:beposoft/pages/BDO/bdo_dashboard.dart';

import 'package:beposoft/pages/HR/hr_dashboard.dart';

import 'package:beposoft/pages/MARKETING/marketing_dashboard.dart';

import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';

import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';

import 'package:beposoft/pages/WAREHOUSE/warehouse_order_view.dart';

import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'package:pdf/pdf.dart';

import 'package:printing/printing.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:excel/excel.dart' hide Border;

import 'package:open_filex/open_filex.dart';

class OrderList extends StatefulWidget {
  var status;

  OrderList({super.key, required this.status});

  @override
  State<OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<OrderList> {
  final ScrollController _orderScrollController = ScrollController();

  int _orderRequestVersion = 0;

  bool _exportingExcel = false;

  void _loadNextOrders() {
    if (!_orderScrollController.hasClients || isLoadingMore || !hasNextPage)
      return;

    if (_orderScrollController.position.extentAfter < 300) {
      fetchOrderData(loadMore: true);
    }
  }

  @override
  void dispose() {
    _orderRequestVersion++;

    _orderScrollController.dispose();

    super.dispose();
  }

  List<Map<String, dynamic>> orders = [];

  List<Map<String, dynamic>> filteredOrders = [];

  String searchQuery = '';

  int currentPage = 1;

  bool isLoadingMore = false;

  bool hasNextPage = true;

  int totalPages = 1;

  int pageSize = 20; // DRF default page size

  DateTime? selectedDate; // For single date filter

  DateTime? startDate; // For date range filter

  DateTime? endDate; // For date range filter

  List<String> orderStatuses = [
    'All',

    'Invoice Created',

    'Invoice Approved',

    'Waiting For Confirmation',

    'Packing under progress',

    'Pending For Packing',

    // 'Packing',

    'Packed',

    'Ready to ship',

    'Return From Delivery',

    'To Print',

    'Shipped',

    'Invoice Rejected',

    // Add other statuses as needed
  ];

  String selectedStatus = 'All'; // Default value

  void _filterOrdersByStatus(String status) {
    if (status == 'All') {
      setState(() {
        filteredOrders = orders;
      });
    } else {
      setState(() {
        filteredOrders = orders.where((order) {
          return order['status'] == status;
        }).toList();
      });
    }
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

  @override
  void initState() {
    super.initState();

    _orderScrollController.addListener(_loadNextOrders);

    fetchOrderData();
  }

  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getString('token');
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getString('department');
  }

  String getDisplayStatus(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().trim();

    switch (status) {
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

  Future<void> fetchOrderData({bool loadMore = false}) async {
    if (loadMore && (isLoadingMore || !hasNextPage)) return;

    final requestVersion =
        loadMore ? _orderRequestVersion : ++_orderRequestVersion;

    final requestedPage = loadMore ? currentPage + 1 : 1;

    bool loadedSuccessfully = false;

    if (!mounted) return;

    setState(() {
      isLoadingMore = true;

      if (!loadMore) {
        currentPage = 1;

        hasNextPage = true;
      }
    });

    try {
      final token = await getTokenFromPrefs();

      Uri uri = Uri.parse("$api/api/orders/").replace(
        queryParameters: {
          'page': requestedPage.toString(),
          'search': searchQuery.isNotEmpty ? searchQuery : null,
          'status': selectedStatus != 'All' ? selectedStatus : null,
          'start_date': startDate != null
              ? DateFormat('yyyy-MM-dd').format(startDate!)
              : null,
          'end_date': endDate != null
              ? DateFormat('yyyy-MM-dd').format(endDate!)
              : null,
        }..removeWhere((key, value) => value == null || value.isEmpty),
      );

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted || requestVersion != _orderRequestVersion) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        int totalCount = responseData['count'] ?? 0;

        totalPages = (totalCount / pageSize).ceil();

        hasNextPage = responseData['next'] != null;

        final List ordersData = responseData['results']['results'];

        List<Map<String, dynamic>> newOrders = [];

        for (var orderData in ordersData) {
          if (widget.status == null || widget.status == orderData['status']) {
            newOrders.add({
              'id': orderData['id'],
              'invoice': orderData['invoice'],
              'manage_staff': orderData['manage_staff'],
              'customer': orderData['customer'],
              'warehouse': orderData['warehouse_data'],
              'status': orderData['status'],
              'total_amount': orderData['total_amount'],
              'order_date': orderData['order_date'],
              'items': orderData['items'] ?? [],
              'billing_address': orderData['billing_address'] ?? {},
              'bank': orderData['bank'] ?? {},
            });
          }
        }

        loadedSuccessfully = true;

        setState(() {
          currentPage = requestedPage;

          if (loadMore) {
            final ids = orders.map((order) => order['id']).toSet();

            orders = <Map<String, dynamic>>[
              ...orders,
              ...newOrders.where((order) => ids.add(order['id'])),
            ];
          } else {
            orders = newOrders;
          }

          filteredOrders = List<Map<String, dynamic>>.from(orders);
        });
      } else {
        print("Order fetch failed: ${response.body}");
      }
    } catch (e) {
      print("Error fetching orders: $e");
    } finally {
      if (mounted && requestVersion == _orderRequestVersion) {
        setState(() => isLoadingMore = false);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && loadedSuccessfully) {
            if (filteredOrders.isEmpty && hasNextPage) {
              fetchOrderData(loadMore: true);
            } else {
              _loadNextOrders();
            }
          }
        });
      }
    }
  }

  void applyFilters() {
    setState(() {
      filteredOrders = orders;
    });
  }

  void _filterOrders(String query) {
    setState(() {
      searchQuery = query;

      currentPage = 1;
    });

    fetchOrderData();
  }

  // Method to filter orders by single date

  void _filterOrdersBySingleDate() {
    if (selectedDate != null) {
      setState(() {
        startDate = selectedDate;

        endDate = selectedDate;

        currentPage = 1;
      });

      fetchOrderData();
    }
  }

  // Method to filter orders between two dates

  // Method to filter orders between two dates, inclusive of start and end dates

  void _filterOrdersByDateRange() {
    if (startDate != null && endDate != null) {
      setState(() {
        currentPage = 1;
      });

      fetchOrderData();
    }
  }

  Future<void> _selectSingleDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });

      _filterOrdersBySingleDate();
    }
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

      _filterOrdersByDateRange();
    }
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove('userId');

    await prefs.remove('token');

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

  String _excelText(dynamic value) {
    if (value == null) return '';

    if (value is Map) {
      for (final key in [
        'name',
        'company_name',
        'staff_name',
        'family_name',
        'payment_method',
        'username'
      ]) {
        if (value[key] != null) return value[key].toString();
      }

      return '';
    }

    return value.toString();
  }

  String _excelStatus(dynamic value) {
    final status = (value ?? '').toString().trim();

    if (status == 'Return From Delivery') return 'Return From Delivery (RFD)';

    return getDisplayStatus(status);
  }

  double _excelAmount(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse((value ?? '').toString()) ?? 0;

  Future<List<Map<String, dynamic>>> _fetchExcelOrders() async {
    final token = await getTokenFromPrefs();

    final parameters = <String, String>{
      if (searchQuery.isNotEmpty) 'search': searchQuery,
      if (selectedStatus != 'All') 'status': selectedStatus,
      if (startDate != null)
        'start_date': DateFormat('yyyy-MM-dd').format(startDate!),
      if (endDate != null)
        'end_date': DateFormat('yyyy-MM-dd').format(endDate!),
    };

    final pageStatus = widget.status;

    final result = <Map<String, dynamic>>[];

    final seenPages = <String>{};

    final seenIds = <String>{};

    Uri? next = Uri.parse('$api/api/orders/')
        .replace(queryParameters: {...parameters, 'page': '1'});

    while (next != null) {
      if (!mounted) throw Exception('Page closed');

      if (!seenPages.add(next.toString()))
        throw Exception('Repeated export page');

      final response = await http.get(next, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Unable to fetch orders (${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);

      dynamic data = decoded;

      if (data is Map) data = data['results'] ?? data['data'];

      if (data is Map) data = data['results'] ?? data['data'];

      if (data is! List) throw Exception('Unexpected order response');

      for (final entry in data) {
        if (entry is Map &&
            (pageStatus == null || pageStatus == entry['status'])) {
          final id = entry['id'];

          if (id == null || seenIds.add(id.toString())) {
            result.add(Map<String, dynamic>.from(entry));
          }
        }
      }

      final nextValue = decoded is Map ? decoded['next'] : null;

      if (nextValue == null || nextValue.toString().isEmpty) {
        next = null;
      } else {
        final resolved = next.resolve(nextValue.toString());

        next = Uri.parse('$api/api/orders/').replace(queryParameters: {
          ...resolved.queryParameters,
          ...parameters,
        });
      }
    }

    return result;
  }

  void _styleExcelRow(Sheet sheet, int row, int columns,
      {String background = '#FFFFFF',
      String foreground = '#203040',
      bool bold = false}) {
    for (var column = 0; column < columns; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
          .cellStyle = CellStyle(
        backgroundColorHex: background,
        fontColorHex: foreground,
        bold: bold,
        verticalAlign: VerticalAlign.Center,
        horizontalAlign:
            column == 0 ? HorizontalAlign.Center : HorizontalAlign.Left,
        textWrapping: TextWrapping.WrapText,
      );
    }
  }

  Future<void> exportToExcel() async {
    if (_exportingExcel || !mounted) return;

    _exportingExcel = true;

    final messenger = ScaffoldMessenger.of(context);

    final progress = messenger.showSnackBar(const SnackBar(
        content: Text('Preparing Excel export…'), duration: Duration(days: 1)));

    try {
      final data = await _fetchExcelOrders();

      if (!mounted) return;

      if (data.isEmpty) throw Exception('No orders match the selected filters');

      final excel = Excel.createExcel();

      // Keep the package's default sheet: rename/delete mutates
      // the archive's unmodifiable file list in older Excel versions.

      final summary = excel['Status Summary'];

      final details = excel['Orders'];

      excel.setDefaultSheet('Status Summary');

      final statusColors = <String, String>{
        'Waiting For Approval': '#DCEBFF',
        'Invoice Approved': '#D9EAD3',
        'Pre Booked': '#E4E0FF',
        'Waiting For Confirmation': '#FFF2CC',
        'Delivery Order (DO)': '#D9EAF7',
        'Printed': '#EADCF8',
        'Pending For Packing': '#FFE5CC',
        'Packed For Delivery (PFD)': '#D9EAD3',
        'Return From Delivery (RFD)': '#FCE4D6',
        'Out For Delivery (OFD)': '#D9EAF7',
        'Shipped': '#C6EFCE',
        'Invoice Rejected': '#FFC7CE',
      };

      final counts = <String, int>{
        for (final status in statusColors.keys) status: 0
      };

      double total = 0;

      for (final order in data) {
        final status = _excelStatus(order['status']);

        counts[status] = (counts[status] ?? 0) + 1;

        total += _excelAmount(order['total_amount']);
      }

      summary.appendRow(['BEPOSOFT - ORDER STATUS REPORT', '']);

      summary.merge(
          CellIndex.indexByString('A1'), CellIndex.indexByString('B1'));

      summary.appendRow([
        'Generated: ${DateFormat('dd/MM/yyyy, hh:mm:ss a').format(DateTime.now())}',
        ''
      ]);

      summary.merge(
          CellIndex.indexByString('A2'), CellIndex.indexByString('B2'));

      summary.appendRow([]);

      summary.appendRow(['TOTAL ORDERS', data.length]);

      summary.appendRow(
          ['TOTAL ORDER AMOUNT', double.parse(total.toStringAsFixed(2))]);

      summary.appendRow([]);

      summary.appendRow(['ORDER STATUS', 'COUNT']);

      _styleExcelRow(summary, 0, 2,
          background: '#17365D', foreground: '#FFFFFF', bold: true);

      _styleExcelRow(summary, 3, 2,
          background: '#198754', foreground: '#FFFFFF', bold: true);

      _styleExcelRow(summary, 6, 2,
          background: '#17365D', foreground: '#FFFFFF', bold: true);

      var summaryRow = 7;

      for (final entry in counts.entries) {
        summary.appendRow([entry.key, entry.value]);

        _styleExcelRow(summary, summaryRow++, 2,
            background: statusColors[entry.key] ?? '#FFFFFF', bold: true);
      }

      summary.setColWidth(0, 38);

      summary.setColWidth(1, 22);

      const headers = [
        'Order #',
        'Invoice No',
        'Company Name',
        'Order Date',
        'Status',
        'Customer Name',
        'Staff',
        'Family',
        'Total Amount',
        'Payment Method'
      ];

      details.appendRow(List<dynamic>.from(headers));

      _styleExcelRow(details, 0, 10,
          background: '#17365D', foreground: '#FFFFFF', bold: true);

      const widths = [
        12.0,
        19.0,
        48.0,
        18.0,
        32.0,
        35.0,
        25.0,
        20.0,
        20.0,
        28.0
      ];

      for (var column = 0; column < widths.length; column++) {
        details.setColWidth(column, widths[column]);
      }

      for (var index = 0; index < data.length; index++) {
        final order = data[index];

        final customer =
            order['customer'] is Map ? order['customer'] as Map : {};

        final status = _excelStatus(order['status']);

        details.appendRow([
          index + 1,
          _excelText(order['invoice']),
          _excelText(order['company_name'] ?? order['company']),
          _excelText(order['order_date']),
          status,
          _excelText(
              customer['name'] ?? order['customer_name'] ?? order['customer']),
          _excelText(order['manage_staff_name'] ??
              order['staff_name'] ??
              order['manage_staff']),
          _excelText(order['family_name'] ?? order['family']),
          double.parse(_excelAmount(order['total_amount']).toStringAsFixed(2)),
          _excelText(order['payment_method']),
        ]);

        _styleExcelRow(details, index + 1, 10,
            background: index.isEven ? '#FFFFFF' : '#F2F6FC');

        details
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 4, rowIndex: index + 1))
                .cellStyle =
            CellStyle(
                backgroundColorHex: statusColors[status] ?? '#FFFFFF',
                fontColorHex: '#203040',
                bold: true,
                textWrapping: TextWrapping.WrapText);

        details
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 8, rowIndex: index + 1))
                .cellStyle =
            CellStyle(
                backgroundColorHex: index.isEven ? '#FFFFFF' : '#F2F6FC',
                fontColorHex: '#198754',
                bold: true,
                horizontalAlign: HorizontalAlign.Right);
      }

      details.appendRow([
        '',
        'GRAND TOTAL',
        '',
        '',
        '',
        '',
        '',
        '',
        double.parse(total.toStringAsFixed(2)),
        ''
      ]);

      _styleExcelRow(details, data.length + 1, 10,
          background: '#17365D', foreground: '#FFFFFF', bold: true);

      final bytes = excel.encode();

      if (bytes == null || bytes.isEmpty)
        throw Exception('Unable to encode Excel file');

      final directory = await getApplicationDocumentsDirectory();

      final filePath =
          '${directory.path}/Beposoft_Orders_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';

      await File(filePath).writeAsBytes(bytes, flush: true);

      progress.close();

      if (!mounted) return;

      messenger.showSnackBar(
          const SnackBar(content: Text('Excel exported successfully')));

      final opened = await OpenFilex.open(filePath);

      if (opened.type != ResultType.done && mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text(
                'Excel saved at $filePath. Unable to open: ${opened.message}')));
      }
    } catch (error) {
      progress.close();

      if (mounted)
        messenger.showSnackBar(
            SnackBar(content: Text('Excel export failed: $error')));
    } finally {
      progress.close();

      _exportingExcel = false;
    }
  }

  Future<pw.Document> createPdf() async {
    final pdf = pw.Document();

    // Iterate through each order and add a new page for it

    for (var order in filteredOrders) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Title Section

                  pw.Center(
                    child: pw.Text(
                      'Order Details',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  // Invoice and Manager

                  pw.Text(
                    'Invoice: ${order['invoice']}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),

                  pw.Text('Manager: ${order['manage_staff'] ?? ''}'),

                  pw.SizedBox(height: 10),

                  // Customer Details

                  pw.Text(
                    'Customer Details',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),

                  pw.Text('Name: ${order['customer']['name'] ?? ''}'),

                  pw.Text('Phone: ${order['customer']['phone'] ?? ''}'),

                  pw.Text('Email: ${order['customer']['email'] ?? ''}'),

                  pw.Text('Address: ${order['customer']['address'] ?? ''}'),

                  pw.SizedBox(height: 10),

                  // Billing Address

                  pw.Text(
                    'Billing Address',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),

                  pw.Text('Name: ${order['billing_address']['name'] ?? ''}'),

                  pw.Text('Email: ${order['billing_address']['email'] ?? ''}'),

                  pw.Text('Phone: ${order['billing_address']['phone'] ?? ''}'),

                  pw.Text(
                      'Address: ${order['billing_address']['address'] ?? ''}'),

                  pw.Text('City: ${order['billing_address']['city'] ?? ''}'),

                  pw.Text('State: ${order['billing_address']['state'] ?? ''}'),

                  pw.Text(
                      'Zipcode: ${order['billing_address']['zipcode'] ?? ''}'),

                  pw.SizedBox(height: 10),

                  // Bank Details

                  pw.Text(
                    'Bank Details',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),

                  pw.Text('Name: ${order['bank']['name'] ?? ''}'),

                  pw.Text(
                      'Account Number: ${order['bank']['account_number'] ?? ''}'),

                  pw.Text('IFSC Code: ${order['bank']['ifsc_code'] ?? ''}'),

                  pw.Text('Branch: ${order['bank']['branch'] ?? ''}'),

                  pw.SizedBox(height: 10),

                  // Items Table

                  pw.Text(
                    'Items',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),

                  pw.Table.fromTextArray(
                    headers: ['Name', 'Quantity', 'Price', 'Tax', 'Discount'],
                    data: [
                      for (var item in order['items'])
                        [
                          item['name'] ?? '',
                          item['quantity'].toString(),
                          item['price'].toString(),
                          item['tax'].toString(),
                          item['discount'].toString(),
                        ],
                    ],
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                    cellStyle: pw.TextStyle(
                      fontSize: 8,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    rowDecoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  // Order Summary

                  pw.Text(
                    'Order Summary',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),

                  pw.Text(
                    'Status: ${getDisplayStatus(order['status'])}',
                  ),

                  pw.Text('Total Amount: ${order['total_amount'].toString()}'),

                  pw.Text('Order Date: ${order['order_date'] ?? ''}'),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf;
  }

  Future<void> downloadPdf() async {
    final pdf = await createPdf();

    final output = await getTemporaryDirectory();

    final file = File("${output.path}/order_list.pdf");

    await file.writeAsBytes(await pdf.save());

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'order_list.pdf');
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
    } else if (dep == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    }
     else if (dep == "OPERATIONS") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OperationsExecutiveDashboard()),
      );
    } else if (dep == "HR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HrDashboard(),
        ),
      );
    } else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => cso_dashboard()),
      );
    } else if (dep == "BDM") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                bdm_dashbord()), // Replace AnotherPage with your target page
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
    } else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                cso_dashboard()), // Replace AnotherPage with your target page
      );
    } else if (dep == "Marketing") {
      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
            builder: (context) =>
                marketing_dashboard()), // Replace AnotherPage with your target page
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Trigger the navigation logic when the back swipe occurs

        _navigateBack();

        return false; // Prevent the default back navigation behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Order List",
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
              }  else if (dep == "OPERATIONS") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OperationsExecutiveDashboard()),
      );
    }else if (dep == "HR") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HrDashboard(),
                  ),
                );
              } else if (dep == "BDM") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          bdm_dashbord()), // Replace AnotherPage with your target page
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
              } else if (dep == "CSO") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          cso_dashboard()), // Replace AnotherPage with your target page
                );
              } else if (dep == "Marketing") {
                Navigator.pushReplacement(
                  context,

                  MaterialPageRoute(
                      builder: (context) =>
                          marketing_dashboard()), // Replace AnotherPage with your target page
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
            IconButton(
              icon: Icon(Icons.calendar_today), // Calendar icon

              onPressed: () => _selectSingleDate(
                  context), // Call the method to select start date
            ),

            // Icon button to open date range picker

            IconButton(
              icon: Icon(Icons.date_range), // Date range icon

              onPressed: () => _selectDateRange(
                  context), // Call the method to select date range
            ),

            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert), // 3-dot icon

              onSelected: (value) {
                // Handle menu item selection

                switch (value) {
                  case 'Option 1':
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) exportToExcel();
                    });

                    break;

                  case 'Option 2':
                    downloadPdf();

                    break;

                  default:

                    // Handle default case

                    break;
                }
              },

              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem<String>(
                    value: 'Option 1',
                    child: Text('Export Excel'),
                  ),
                  PopupMenuItem<String>(
                    value: 'Option 2',
                    child: Text('Download Pdf'),
                  ),
                ];
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: "Filter by Status",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value!;

                    currentPage = 1;
                  });

                  fetchOrderData();
                },
                items: orderStatuses.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(getDisplayStatus(status)),
                  );
                }).toList(),
              ),
            ),

            // Search Bar

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _filterOrders,
              ),
            ),

            SizedBox(height: 10),

            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Text(
                        selectedDate != null ||
                                (startDate != null && endDate != null)
                            ? 'No orders available in this date range'
                            : 'No orders available',
                        style: TextStyle(
                            fontSize: 16,
                            color: const Color.fromARGB(255, 2, 65, 96)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => fetchOrderData(),
                      child: ListView.builder(
                        controller: _orderScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount:
                            filteredOrders.length + (isLoadingMore ? 1 : 0),
                        padding: const EdgeInsets.only(right: 10, left: 10),
                        itemBuilder: (context, index) {
                          if (index == filteredOrders.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final order = filteredOrders[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => OrderReview(
                                            id: order['id'],
                                            customer: order['customer']
                                                ['id'])));
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                color: Colors.white,
                                elevation: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header section with Invoice and Order Date

                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(15.0),
                                          topRight: Radius.circular(15.0),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '#${order['invoice']}',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            DateFormat('dd MMM yy').format(
                                                DateTime.parse(
                                                    order['order_date'])),
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Order details section

                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Customer: ${order['customer']['name']}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          SizedBox(height: 4.0),
                                          Text(
                                            'Staff: ${order['manage_staff']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          SizedBox(height: 4.0),
                                          Row(
                                            children: [
                                              Text(
                                                'Status: ',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                getDisplayStatus(
                                                  order['status'],
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4.0),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Billing Amount:',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                '${(order['total_amount'] as num).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (order['warehouse'] != null &&
                                              (order['warehouse'] as List)
                                                  .isNotEmpty) ...[
                                            SizedBox(height: 5.0),
                                            Text(
                                              'Warehouse Info:',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                decoration:
                                                    TextDecoration.underline,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                            SizedBox(height: 4.0),
                                            Table(
                                              border: TableBorder.symmetric(
                                                inside: BorderSide(
                                                    color:
                                                        Colors.grey.shade300),
                                                outside: BorderSide(
                                                    color: Colors.grey.shade400,
                                                    width: 1),
                                              ),
                                              columnWidths: {
                                                0: FlexColumnWidth(1),
                                                1: FlexColumnWidth(2),
                                                2: FlexColumnWidth(3),
                                              },
                                              defaultVerticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              children: [
                                                // Header Row

                                                TableRow(
                                                  decoration: BoxDecoration(
                                                      color:
                                                          Colors.blue.shade50),
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 8.0,
                                                              horizontal: 6.0),
                                                      child: Text(
                                                        'Box',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .blue.shade900,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 8.0,
                                                              horizontal: 6.0),
                                                      child: Text(
                                                        'Tracking ID',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .blue.shade900,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Data Rows

                                                ...(order['warehouse'] as List)
                                                    .map<TableRow>((wh) {
                                                  return TableRow(
                                                    decoration: BoxDecoration(
                                                        color: Colors.white),
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.all(8.0),
                                                        child: Text(
                                                          wh['box'] ?? 'N/A',
                                                          style: TextStyle(
                                                              fontSize: 12),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: SelectableText(
                                                          wh['tracking_id'] ??
                                                              'N/A',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          ] else
                                            Text(
                                              'No warehouse data available',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
