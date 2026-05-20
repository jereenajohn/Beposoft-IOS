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
import 'package:beposoft/pages/ACCOUNTS/customer.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/methods.dart';
import 'package:beposoft/pages/ACCOUNTS/order.review.dart';
import 'package:beposoft/pages/ACCOUNTS/sales_report.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
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
import 'package:excel/excel.dart';
import 'package:open_filex/open_filex.dart';

class InvoiceReportStaffwise extends StatefulWidget {
  var id;
  var date;

  InvoiceReportStaffwise({
    super.key,
    required this.id,
    required this.date,
  });

  @override
  State<InvoiceReportStaffwise> createState() => _InvoiceReportStaffwiseState();
}

class _InvoiceReportStaffwiseState extends State<InvoiceReportStaffwise> {
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> filteredOrders = [];
  String searchQuery = '';

  DateTime? selectedDate;
  DateTime? startDate;
  DateTime? endDate;

  bool isLoading = false;

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
            d.navigateToSelectedPage(context, option);
          },
        );
      }).toList(),
    );
  }

  @override
  void initState() {
    super.initState();
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

  String _formatApiDate(dynamic value) {
    if (value == null) return "";

    String rawDate = value.toString();

    try {
      DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(rawDate);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      try {
        DateTime parsedDate = DateTime.parse(rawDate);
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        return rawDate;
      }
    }
  }

  Future<void> fetchOrderData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final token = await getTokenFromPrefs();

      if (token == null || token.isEmpty) {
        setState(() {
          orders = [];
          filteredOrders = [];
          isLoading = false;
        });
        return;
      }

      final jwt = JWT.decode(token);
      var name = jwt.payload['name'];

      print("JWT NAME: $name");
      print("WIDGET ID: ${widget.id}");
      print("WIDGET DATE: ${widget.date}");

      String url = '$api/api/orders/';
      List<Map<String, dynamic>> orderList = [];

      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print("ORDER STATUS CODE: ${response.statusCode}");
      print("ORDER BODY: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        List ordersData = [];

        if (responseData['results'] is Map &&
            responseData['results']['results'] is List) {
          ordersData = responseData['results']['results'];
        } else if (responseData['results'] is List) {
          ordersData = responseData['results'];
        }

        List<Map<String, dynamic>> newOrders = [];

        String selectedDateString = _formatApiDate(widget.date);
        String selectedStaffString = widget.id?.toString() ?? "";

        for (var orderData in ordersData) {
          if (orderData is! Map<String, dynamic>) {
            continue;
          }

          String rawOrderDate = orderData['order_date'] ?? "";
          String formattedOrderDate = _formatApiDate(rawOrderDate);

          String orderStaffName = orderData['manage_staff']?.toString() ?? "";
          String orderStaffID = orderData['staffID']?.toString() ?? "";

          bool staffMatched = orderStaffName == selectedStaffString ||
              orderStaffID == selectedStaffString;

          bool dateMatched = formattedOrderDate == selectedDateString;

          print(
              "CHECK ORDER ${orderData['id']} STAFF NAME: $orderStaffName STAFF ID: $orderStaffID SELECTED: $selectedStaffString DATE: $formattedOrderDate SELECTED DATE: $selectedDateString STAFF MATCH: $staffMatched DATE MATCH: $dateMatched");

          if (orderData['status'] != "Order Request by Warehouse") {
            if (staffMatched && dateMatched) {
              Map<String, dynamic> customerMap = {};
              Map<String, dynamic> billingAddressMap = {};
              Map<String, dynamic> bankMap = {};

              if (orderData['customer'] is Map<String, dynamic>) {
                customerMap = orderData['customer'];
              }

              if (orderData['billing_address'] is Map<String, dynamic>) {
                billingAddressMap = orderData['billing_address'];
              }

              if (orderData['bank'] is Map<String, dynamic>) {
                bankMap = orderData['bank'];
              }

              newOrders.add({
                'id': orderData['id'],
                'invoice': orderData['invoice'],
                'manage_staff': orderData['manage_staff'],
                'staffID': orderData['staffID'],
                'customer': {
                  'id': customerMap['id'] ?? orderData['customerID'],
                  'name': customerMap['name'] ??
                      billingAddressMap['name'] ??
                      '',
                  'phone': billingAddressMap['phone'] ?? '',
                  'email': billingAddressMap['email'] ?? '',
                  'address': billingAddressMap['address'] ?? '',
                },
                'billing_address': {
                  'name': billingAddressMap['name'] ?? '',
                  'email': billingAddressMap['email'] ?? '',
                  'zipcode': billingAddressMap['zipcode'] ?? '',
                  'address': billingAddressMap['address'] ?? '',
                  'phone': billingAddressMap['phone'] ?? '',
                  'city': billingAddressMap['city'] ?? '',
                  'state': billingAddressMap['state'] ?? '',
                },
                'bank': {
                  'name': bankMap['name'] ?? '',
                  'account_number': bankMap['account_number'] ?? '',
                  'ifsc_code': bankMap['ifsc_code'] ?? '',
                  'branch': bankMap['branch'] ?? '',
                },
                'items': orderData['items'] != null && orderData['items'] is List
                    ? orderData['items'].map((item) {
                        if (item is Map<String, dynamic>) {
                          return {
                            'id': item['id'],
                            'name': item['name'],
                            'quantity': item['quantity'],
                            'price': item['price'],
                            'tax': item['tax'],
                            'discount': item['discount'],
                            'images': item['images'],
                          };
                        }
                        return null;
                      }).where((item) => item != null).toList()
                    : [],
                'status': orderData['status'],
                'total_amount': orderData['total_amount'],
                'order_date': formattedOrderDate,
                'payment_status': orderData['payment_status'],
                'payment_method': orderData['payment_method'],
                'shipping_mode': orderData['shipping_mode'],
                'shipping_charge': orderData['shipping_charge'],
                'parcel_service_note': orderData['parcel_service_note'],
                'state': orderData['state'],
                'company': orderData['company'],
                'family': orderData['family'],
                'family_id': orderData['family_id'],
                'family_name': orderData['family_name'],
              });
            }
          }
        }

        print("FINAL FILTERED ORDER COUNT: ${newOrders.length}");

        setState(() {
          orders = newOrders;
          filteredOrders = newOrders;
          isLoading = false;
        });
      } else {
        setState(() {
          orders = [];
          filteredOrders = [];
          isLoading = false;
        });

        throw Exception("Failed to load order data");
      }
    } catch (error) {
      print("FETCH ORDER DATA ERROR: $error");

      setState(() {
        orders = [];
        filteredOrders = [];
        isLoading = false;
      });
    }
  }

  void _filterOrders(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredOrders = orders;
      } else {
        filteredOrders = orders.where((order) {
          final customerName =
              order['customer']?['name']?.toString().toLowerCase() ?? '';
          final customerPhone =
              order['customer']?['phone']?.toString().toLowerCase() ?? '';
          final invoice = order['invoice']?.toString().toLowerCase() ?? '';
          final manageStaff =
              order['manage_staff']?.toString().toLowerCase() ?? '';
          final staffID = order['staffID']?.toString().toLowerCase() ?? '';
          final totalAmount =
              order['total_amount']?.toString().toLowerCase() ?? '';
          final status = order['status']?.toString().toLowerCase() ?? '';

          return customerName.contains(query.toLowerCase()) ||
              customerPhone.contains(query.toLowerCase()) ||
              invoice.contains(query.toLowerCase()) ||
              manageStaff.contains(query.toLowerCase()) ||
              staffID.contains(query.toLowerCase()) ||
              totalAmount.contains(query.toLowerCase()) ||
              status.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _filterOrdersBySingleDate() {
    if (selectedDate != null) {
      setState(() {
        filteredOrders = orders.where((order) {
          final orderDate = DateTime.parse(order['order_date']);
          return orderDate.year == selectedDate!.year &&
              orderDate.month == selectedDate!.month &&
              orderDate.day == selectedDate!.day;
        }).toList();
      });
    }
  }

  void _filterOrdersByDateRange() {
    if (startDate != null && endDate != null) {
      setState(() {
        filteredOrders = orders.where((order) {
          final orderDate = DateTime.parse(order['order_date']);
          return (orderDate.isAtSameMomentAs(startDate!) ||
              orderDate.isAtSameMomentAs(endDate!) ||
              (orderDate.isAfter(startDate!) && orderDate.isBefore(endDate!)));
        }).toList();
      });
    }
  }

  Future<void> _selectSingleDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
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

    await Future.delayed(Duration(seconds: 2));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => login()),
    );
  }

  Future<void> exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Order List'];

    // Add header row
    sheetObject.appendRow([
      'Invoice',
      'Manager',
      'Customer Name',
      'Customer Phone',
      'Customer Email',
      'Customer Address',
      'Billing Name',
      'Billing Email',
      'Billing Phone',
      'Billing Address',
      'Billing City',
      'Billing State',
      'Billing Zipcode',
      'Bank Name',
      'Bank Account Number',
      'Bank IFSC Code',
      'Bank Branch',
      'Item Name',
      'Item Quantity',
      'Item Price',
      'Item Tax',
      'Item Discount',
      'Order Status',
      'Total Amount',
      'Order Date',
    ]);

    // Populate rows with data
    for (var order in filteredOrders) {
      // Iterate through items to create separate rows for each item
      for (var item in order['items']) {
        sheetObject.appendRow([
          order['invoice'] ?? '',
          order['manage_staff'] ?? '',
          order['customer']['name'] ?? '',
          order['customer']['phone'] ?? '',
          order['customer']['email'] ?? '',
          order['customer']['address'] ?? '',
          order['billing_address']['name'] ?? '',
          order['billing_address']['email'] ?? '',
          order['billing_address']['phone'] ?? '',
          order['billing_address']['address'] ?? '',
          order['billing_address']['city'] ?? '',
          order['billing_address']['state'] ?? '',
          order['billing_address']['zipcode'] ?? '',
          order['bank']['name'] ?? '',
          order['bank']['account_number'] ?? '',
          order['bank']['ifsc_code'] ?? '',
          order['bank']['branch'] ?? '',
          item['name'] ?? '',
          item['quantity'] ?? '',
          item['price'] ?? '',
          item['tax'] ?? '',
          item['discount'] ?? '',
          order['status'] ?? '',
          order['total_amount'] ?? '',
          order['order_date'] ?? '',
        ]);
      }
    }

    // Save the Excel file
    final tempDir = await getTemporaryDirectory();
    final tempPath = "${tempDir.path}/order_list.xlsx";
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(await excel.encode()!);

    // Open the file
    await OpenFilex.open(tempPath);
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
                  pw.Text('Status: ${order['status'] ?? ''}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Order List",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final dep = await getdepFromPrefs();

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Sales_Report()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchOrderData();
            },
          ),
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectSingleDate(context),
          ),
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'Option 1':
                  exportToExcel();
                  break;
                case 'Option 2':
                  downloadPdf();
                  break;

                default:
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
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                  )
                : filteredOrders.isEmpty
                    ? Center(
                        child: Text(
                          selectedDate != null ||
                                  (startDate != null && endDate != null)
                              ? 'No orders available in this date range'
                              : 'No orders available',
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color.fromARGB(255, 2, 65, 96),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchOrderData,
                        color: Colors.blue,
                        child: ListView.builder(
                          itemCount: filteredOrders.length,
                          padding: const EdgeInsets.only(right: 10, left: 10),
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3.0),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrderReview(
                                        id: order['id'],
                                        customer: order['customer']['id'],
                                      ),
                                    ),
                                  );
                                },
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  color: Colors.white,
                                  elevation: 4,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                            Expanded(
                                              child: Text(
                                                '#${order['invoice'] ?? ''}',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              order['order_date'] != null &&
                                                      order['order_date']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? DateFormat('dd MMM yy')
                                                      .format(DateTime.parse(
                                                          order['order_date']))
                                                  : '',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Customer: ${order['customer']['name'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 4.0),
                                            Text(
                                              'Staff: ${order['manage_staff'] ?? ''}',
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
                                                Expanded(
                                                  child: Text(
                                                    '${order['status'] ?? ''}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8.0),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Billing Amount:',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  '₹${order['total_amount'] ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
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
    );
  }
}