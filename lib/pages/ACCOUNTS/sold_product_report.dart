import 'dart:convert';
import 'dart:io';
import 'package:beposoft/pages/ACCOUNTS/add_attribute.dart';
import 'package:beposoft/pages/ACCOUNTS/add_bank.dart';
import 'package:beposoft/pages/ACCOUNTS/add_company.dart';
import 'package:beposoft/pages/ACCOUNTS/add_department.dart';
import 'package:beposoft/pages/ACCOUNTS/add_family.dart';
import 'package:beposoft/pages/ACCOUNTS/add_services.dart';
import 'package:beposoft/pages/ACCOUNTS/add_state.dart';
import 'package:beposoft/pages/ACCOUNTS/add_supervisor.dart';
import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/methods.dart';
import 'package:beposoft/pages/ADMIN/admin_dashboard.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_order_view.dart';
import 'package:beposoft/pages/api.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Sold_pro_report extends StatefulWidget {
  const Sold_pro_report({super.key});

  @override
  State<Sold_pro_report> createState() => _Sold_pro_reportState();
}

class _Sold_pro_reportState extends State<Sold_pro_report> {
  List<Map<String, dynamic>> groupedData = [];
  List<Map<String, dynamic>> filteredProducts = [];
  TextEditingController searchController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  String? selectedstaff;
  List<Map<String, dynamic>> sta = [];

  int currentPage = 1;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMoreData = true;
  final ScrollController scrollController = ScrollController();

  String? selectedState;
  List<Map<String, dynamic>> states = [];

  @override
  void initState() {
    super.initState();

    getSoldReport(isRefresh: true);
    getstaff();
    getStates();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          hasMoreData) {
        getSoldReport();
      }
    });
  }

  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> getstaff() async {
    try {
      final token = await getTokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/staffs/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      List<Map<String, dynamic>> stafflist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        for (var productData in productsData) {
          stafflist.add({
            'id': productData['id'],
            'name': productData['name'],
          });
        }
        setState(() {
          sta = stafflist;
        });
      }
    } catch (error) {}
  }

  Future<void> getStates() async {
    final token = await getTokenFromPrefs();

    final response = await http.get(
      Uri.parse('$api/api/states/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);

      setState(() {
        states = List<Map<String, dynamic>>.from(parsed['data']);
      });
    }
  }

  Future<void> getSoldReport({bool isRefresh = false}) async {
    if (isLoading || isLoadingMore) return;

    try {
      final token = await getTokenFromPrefs();

      if (isRefresh) {
        currentPage = 1;
        hasMoreData = true;
        groupedData.clear();
        filteredProducts.clear();
        isLoading = true;
      } else {
        isLoadingMore = true;
      }

      setState(() {});

      final uri = Uri.parse('$api/api/sold/products/').replace(
        queryParameters: {
          'page': currentPage.toString(),
          if (searchController.text.trim().isNotEmpty)
            'search': searchController.text.trim(),
          if (selectedstaff != null && selectedstaff!.isNotEmpty)
            'staff_id': selectedstaff!,
          if (startDateController.text.trim().isNotEmpty)
            'start_date': startDateController.text.trim(),
          if (endDateController.text.trim().isNotEmpty)
            'end_date': endDateController.text.trim(),
          if (selectedState != null && selectedState!.isNotEmpty)
            'state_id': selectedState!,
        },
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
        final List<dynamic> soldProducts = parsed['results']?['data'] ?? [];

        final orderList = soldProducts.map<Map<String, dynamic>>((item) {
          return {
            'date': item['date'] ?? '',
            'product': item['product'] ?? '',
            'order': item['order'] ?? '',
            'manage_staff': item['manage_staff'] ?? '',
            'family': item['family'] ?? '',
            'customer': item['customer'] ?? '',
            'state': item['state'] ?? '',
            'status': item['status'] ?? '',
            'total_sold': item['total_sold'] ?? 0,
            'total_amount': item['total_amount'] ?? 0,
            'stock': item['stock'] ?? 0,
          };
        }).toList();

        setState(() {
          groupedData.addAll(orderList);
          filteredProducts = groupedData;

          hasMoreData = parsed['next'] != null;
          if (hasMoreData) currentPage++;
        });
      } else {
        debugPrint('Sold report error: ${response.statusCode}');
        debugPrint(response.body);
      }
    } catch (error) {
      debugPrint('Sold report exception: $error');
    } finally {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<void> exportSoldProductsToExcel() async {
    if (filteredProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    final workbook = excel.Excel.createExcel();
    final sheet = workbook['Sold Product Report'];

    final titleStyle = excel.CellStyle(
      bold: true,
      fontColorHex: '#FFFFFF',
      backgroundColorHex: '#0F172A',
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    final infoLabelStyle = excel.CellStyle(
      bold: true,
      fontColorHex: '#334155',
      backgroundColorHex: '#EAF2FF',
    );

    final infoValueStyle = excel.CellStyle(
      fontColorHex: '#0F172A',
      backgroundColorHex: '#F8FAFC',
    );

    final headerStyle = excel.CellStyle(
      bold: true,
      fontColorHex: '#FFFFFF',
      backgroundColorHex: '#2563EB',
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    final normalStyle = excel.CellStyle(
      fontColorHex: '#0F172A',
      backgroundColorHex: '#FFFFFF',
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    final alternateStyle = excel.CellStyle(
      fontColorHex: '#0F172A',
      backgroundColorHex: '#F8FAFC',
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    final amountStyle = excel.CellStyle(
      fontColorHex: '#0F172A',
      backgroundColorHex: '#FFFFFF',
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    void setCell(int col, int row, dynamic value, {excel.CellStyle? style}) {
      final cell = sheet.cell(
        excel.CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: row,
        ),
      );

      cell.value = value?.toString() ?? '';

      if (style != null) {
        cell.cellStyle = style;
      }
    }

    String selectedStaffName() {
      if (selectedstaff == null || selectedstaff!.isEmpty) return 'All';
      final item =
          sta.where((e) => e['id'].toString() == selectedstaff).toList();
      return item.isEmpty ? 'Selected' : item.first['name'].toString();
    }

    String selectedStateName() {
      if (selectedState == null || selectedState!.isEmpty) return 'All';
      final item =
          states.where((e) => e['id'].toString() == selectedState).toList();
      return item.isEmpty ? 'Selected' : item.first['name'].toString();
    }

    double totalAmount = 0;
    int totalSold = 0;

    for (final item in filteredProducts) {
      totalAmount += double.tryParse(item['total_amount'].toString()) ?? 0;
      totalSold += int.tryParse(item['total_sold'].toString()) ?? 0;
    }

    sheet.merge(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      excel.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 0),
    );

    setCell(0, 0, 'SOLD PRODUCT REPORT', style: titleStyle);

    setCell(0, 2, 'Generated At', style: infoLabelStyle);
    setCell(
      1,
      2,
      DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      style: infoValueStyle,
    );
    setCell(2, 2, 'Total Rows', style: infoLabelStyle);
    setCell(3, 2, filteredProducts.length, style: infoValueStyle);
    setCell(4, 2, 'Total Sold', style: infoLabelStyle);
    setCell(5, 2, totalSold, style: infoValueStyle);
    setCell(6, 2, 'Total Amount', style: infoLabelStyle);
    setCell(7, 2, totalAmount.toStringAsFixed(2), style: infoValueStyle);

    setCell(0, 3, 'Search', style: infoLabelStyle);
    setCell(
      1,
      3,
      searchController.text.trim().isEmpty
          ? 'All'
          : searchController.text.trim(),
      style: infoValueStyle,
    );
    setCell(2, 3, 'Staff', style: infoLabelStyle);
    setCell(3, 3, selectedStaffName(), style: infoValueStyle);
    setCell(4, 3, 'State', style: infoLabelStyle);
    setCell(5, 3, selectedStateName(), style: infoValueStyle);
    setCell(6, 3, 'Date Range', style: infoLabelStyle);
    setCell(
      7,
      3,
      '${startDateController.text.isEmpty ? 'All' : startDateController.text} to ${endDateController.text.isEmpty ? 'All' : endDateController.text}',
      style: infoValueStyle,
    );

    final headers = [
      'Sl No',
      'Date',
      'Order',
      'Product',
      'Staff',
      'Family',
      'Customer',
      'State',
      'Status',
      'Total Sold',
      'Amount',
      'Stock',
    ];

    for (int i = 0; i < headers.length; i++) {
      setCell(i, 5, headers[i], style: headerStyle);
    }

    for (int i = 0; i < filteredProducts.length; i++) {
      final item = filteredProducts[i];
      final row = i + 6;
      final rowStyle = i.isOdd ? alternateStyle : normalStyle;

      setCell(0, row, i + 1, style: rowStyle);
      setCell(1, row, item['date'], style: rowStyle);
      setCell(2, row, item['order'], style: rowStyle);
      setCell(3, row, item['product'], style: rowStyle);
      setCell(4, row, item['manage_staff'], style: rowStyle);
      setCell(5, row, item['family'], style: rowStyle);
      setCell(6, row, item['customer'], style: rowStyle);
      setCell(7, row, item['state'], style: rowStyle);
      setCell(8, row, item['status'], style: rowStyle);
      setCell(9, row, item['total_sold'], style: rowStyle);
      setCell(10, row, item['total_amount'], style: amountStyle);
      setCell(11, row, item['stock'], style: rowStyle);
    }

    final totalRow = filteredProducts.length + 7;

    setCell(0, totalRow, 'TOTAL', style: titleStyle);
    setCell(1, totalRow, '', style: titleStyle);
    setCell(2, totalRow, '', style: titleStyle);
    setCell(3, totalRow, '', style: titleStyle);
    setCell(4, totalRow, '', style: titleStyle);
    setCell(5, totalRow, '', style: titleStyle);
    setCell(6, totalRow, '', style: titleStyle);
    setCell(7, totalRow, '', style: titleStyle);
    setCell(8, totalRow, '', style: titleStyle);
    setCell(9, totalRow, totalSold, style: titleStyle);
    setCell(10, totalRow, totalAmount.toStringAsFixed(2), style: titleStyle);
    setCell(11, totalRow, '', style: titleStyle);

    sheet.setColWidth(0, 8);
    sheet.setColWidth(1, 14);
    sheet.setColWidth(2, 15);
    sheet.setColWidth(3, 42);
    sheet.setColWidth(4, 24);
    sheet.setColWidth(5, 16);
    sheet.setColWidth(6, 28);
    sheet.setColWidth(7, 24);
    sheet.setColWidth(8, 14);
    sheet.setColWidth(9, 16);
    sheet.setColWidth(10, 12);
    sheet.setColWidth(11, 12);

    final bytes = workbook.encode();

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate Excel')),
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/Sold_Product_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx',
    );

    await file.writeAsBytes(bytes);
    debugPrint(file.path);
    debugPrint(await file.length().toString());
    final result = await OpenFilex.open(file.path);
    debugPrint("Excel Open Result: ${result.type}");
    debugPrint("Message: ${result.message}");
  }

  void _filterProducts(String query) {
    if (query.isEmpty &&
        selectedstaff == null &&
        startDateController.text.isEmpty &&
        endDateController.text.isEmpty) {
      setState(() {
        filteredProducts =
            groupedData; // Reset to all products when no filters are applied
      });
    } else {
      setState(() {
        filteredProducts = groupedData.where((order) {
          bool matchesProduct =
              order['product'].toLowerCase().contains(query.toLowerCase());
          bool matchesStaff = selectedstaff == null ||
              order['manage_staff']
                  .toLowerCase()
                  .contains(selectedstaff!.toLowerCase());

          // Date filtering logic
          bool matchesDate = true;
          if (startDateController.text.isNotEmpty &&
              endDateController.text.isNotEmpty) {
            DateTime startDate = DateTime.parse(startDateController.text);
            DateTime endDate = DateTime.parse(endDateController.text);
            DateTime orderDate = DateTime.parse(order['date']);
            matchesDate =
                orderDate.isAfter(startDate.subtract(Duration(days: 1))) &&
                    orderDate.isBefore(endDate.add(Duration(days: 1)));
          } else if (startDateController.text.isNotEmpty) {
            DateTime startDate = DateTime.parse(startDateController.text);
            DateTime orderDate = DateTime.parse(order['date']);
            matchesDate =
                orderDate.isAfter(startDate.subtract(Duration(days: 1)));
          } else if (endDateController.text.isNotEmpty) {
            DateTime endDate = DateTime.parse(endDateController.text);
            DateTime orderDate = DateTime.parse(order['date']);
            matchesDate = orderDate.isBefore(endDate.add(Duration(days: 1)));
          }

          return matchesProduct && matchesStaff && matchesDate;
        }).toList();
      });
    }
  }

  // This function will be triggered when the user pulls to refresh
  // Future<void> _refreshData() async {
  //   await getSoldReport(); // Reload the data by fetching it again
  //   setState(() {
  //     filteredProducts = groupedData; // Ensure the data is refreshed
  //   });
  // }

  Future<void> _refreshData() async {
    await getSoldReport(isRefresh: true);
  }

  // Date range picker function
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now().add(Duration(days: 7)),
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedRange != null) {
      setState(() {
        startDateController.text =
            "${pickedRange.start.toLocal()}".split(' ')[0];
        endDateController.text = "${pickedRange.end.toLocal()}".split(' ')[0];
      });
      getSoldReport(
          isRefresh: true); // Apply filters after selecting the date range
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
    } else if (dep == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    }
    else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => cso_dashboard()),
      );
    }else if (dep == "BDM") {
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
    }
    else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                cso_dashboard()), // Replace AnotherPage with your target page
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
        // Prevent the swipe-back gesture (and back button)
        _navigateBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Sold Product Report",
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
              }
              
                else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                cso_dashboard()), // Replace AnotherPage with your target page
      );
    }  else if (dep == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    }
    else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => cso_dashboard()),
      );
    }else if (dep == "BDM") {
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
              } else if (dep == "Warehouse Admin") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          WarehouseAdmin()), // Replace AnotherPage with your target page
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
              tooltip: 'Export Excel',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: exportSoldProductsToExcel,
            ),
            IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: () async {
                await _selectDateRange(
                    context); // Select date range when clicked
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search products...",
                  prefixIcon: Icon(Icons.search),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: Colors.blue,
                      width: 2.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: Colors.grey,
                      width: 1.0,
                    ),
                  ),
                ),
                onChanged: (query) {
                  getSoldReport(isRefresh: true);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 59,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: DropdownButton<String>(
                        value: selectedstaff,
                        isExpanded: true,
                        hint: const Text("Select Staff"),
                        underline: Container(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedstaff = newValue;
                          });
                          getSoldReport(isRefresh: true);
                        },
                        items: sta.map<DropdownMenuItem<String>>((staff) {
                          return DropdownMenuItem<String>(
                            value: staff['id'].toString(),
                            child: Text(
                              staff['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 59,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: DropdownButton<String>(
                        value: selectedState,
                        isExpanded: true,
                        hint: const Text("Select State"),
                        underline: Container(),
                        onChanged: (value) {
                          setState(() {
                            selectedState = value;
                          });
                          getSoldReport(isRefresh: true);
                        },
                        items: states.map<DropdownMenuItem<String>>((state) {
                          return DropdownMenuItem<String>(
                            value: state['id'].toString(),
                            child: Text(
                              state['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData, // Trigger the refresh
                child: filteredProducts.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount:
                            filteredProducts.length + (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredProducts.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          var order = filteredProducts[index];
                          String date = order['date'];
                          int stock = order['stock'];
                          return Card(
                            color: Colors.white,
                            margin: EdgeInsets.all(8),
                            elevation: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$date  (${order['product']})',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Stock: $stock',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color.fromARGB(
                                          255, 164, 164, 164),
                                    ),
                                  ),
                                  Card(
                                    color: Colors.white,
                                    margin: EdgeInsets.symmetric(vertical: 5),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Order: ${order['order']}',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Divider(),
                                                Text(
                                                  'Staff: ${order['manage_staff']}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Divider(),
                                                Text(
                                                  'Product: ${order['product']}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                    'Total Sold: ${order['total_sold']}'),
                                                Text(
                                                    'Amount: ${order['total_amount']}'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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

  @override
  void dispose() {
    scrollController.dispose();
    searchController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }
}
