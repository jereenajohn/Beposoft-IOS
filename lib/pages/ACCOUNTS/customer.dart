import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:beposoft/pages/ACCOUNTS/Customer_complete_report.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/add_address.dart';
import 'package:beposoft/pages/ACCOUNTS/add_attribute.dart';
import 'package:beposoft/pages/ACCOUNTS/add_bank.dart';
import 'package:beposoft/pages/ACCOUNTS/add_company.dart';
import 'package:beposoft/pages/ACCOUNTS/add_department.dart';
import 'package:beposoft/pages/ACCOUNTS/add_family.dart';
import 'package:beposoft/pages/ACCOUNTS/add_services.dart';
import 'package:beposoft/pages/ACCOUNTS/add_state.dart';
import 'package:beposoft/pages/ACCOUNTS/add_supervisor.dart';
import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/customer_ledger.dart';
import 'package:beposoft/pages/ACCOUNTS/customer_singleview.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/navigateback.dart';
import 'package:beposoft/pages/ACCOUNTS/view_customer.dart';
import 'package:beposoft/pages/ADMIN/admin_dashboard.dart';
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
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'package:beposoft/main.dart';
import 'package:beposoft/pages/ACCOUNTS/add_credit_note.dart';
import 'package:beposoft/pages/ACCOUNTS/customer.dart';
import 'package:beposoft/pages/ACCOUNTS/recipts_list.dart';
import 'package:beposoft/pages/ACCOUNTS/add_new_stock.dart';
import 'package:beposoft/pages/ACCOUNTS/credit_note_list.dart';
import 'package:beposoft/pages/ACCOUNTS/methods.dart';
import 'package:beposoft/pages/ACCOUNTS/new_product.dart';
import 'package:beposoft/pages/ACCOUNTS/order_request.dart';
import 'package:beposoft/pages/ACCOUNTS/purchases_request.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:beposoft/pages/ACCOUNTS/add_new_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class customer_list extends StatefulWidget {
  const customer_list({super.key});

  @override
  State<customer_list> createState() => _customer_listState();
}

class _customer_listState extends State<customer_list> {
  List<Map<String, dynamic>> fam = [];
  List<bool> _checkboxValues = [];
  String? _selectedFamily;
  TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> filteredProducts = [];
  List<Map<String, dynamic>> searchFiltered = [];
  List<Map<String, dynamic>> familyFiltered = [];
  List<Map<String, dynamic>> stateFiltered = [];
  List<Map<String, dynamic>> sta = [];
  List<Map<String, dynamic>> type = [];

  String? selectedFamilyFilter = "All";
  String? selectedStateFilter = "All";
  String? selectedStaffFilter = "All";
  String? selectedCustomerTypeFilter = "All";
  int currentPage = 1;
  int totalPages = 1;
  bool loadingPage = false;
  bool _exportingExcel = false;
  final ScrollController _customerScrollController = ScrollController();
  Timer? _searchDebounce;
  int _requestGeneration = 0;
  bool _hasMoreCustomers = true;
  String? _paginationError;

  List<String> categories = ["cycling", 'skating', 'fitness', 'bepocart'];
  String selectededu = "cycling";

  drower d = drower();

  List<Map<String, dynamic>> customer = [];
  List<Map<String, dynamic>> stat = [];

  @override
  void initState() {
    super.initState();
    _customerScrollController.addListener(_onCustomerScroll);
    getcustomer();
    getfamily();
    getstate();
    getstaff();
    getcustomertype();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _requestGeneration++;
    _customerScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

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

  Future<String?> gettokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  void _onCustomerScroll() {
    if (!_customerScrollController.hasClients ||
        loadingPage || !_hasMoreCustomers) return;
    if (_customerScrollController.position.extentAfter < 350) {
      getcustomer(page: currentPage + 1);
    }
  }

  Future<void> getcustomer({int page = 1}) async {
    if (!mounted) return;
    if (loadingPage && page != 1) return;
    final int generation = page == 1
        ? ++_requestGeneration
        : _requestGeneration;
    setState(() {
      loadingPage = true;
      _paginationError = null;
      if (page == 1) {
        currentPage = 0;
        totalPages = 1;
        _hasMoreCustomers = true;
        customer = [];
        filteredProducts = [];
      }
    });

    try {
      final token = await gettokenFromPrefs();
      if (token == null || token.isEmpty) {
        throw StateError('Authentication token not found');
      }
      final uri = Uri.parse('$api/api/customers/').replace(
        queryParameters: {
          'page': page.toString(),
          if (searchController.text.trim().isNotEmpty)
            'search': searchController.text.trim(),
          if (selectedStaffFilter != null && selectedStaffFilter != 'All')
            'manager': selectedStaffFilter!,
          if (selectedStateFilter != null && selectedStateFilter != 'All')
            'state': selectedStateFilter!,
          if (selectedFamilyFilter != null && selectedFamilyFilter != 'All')
            'family': selectedFamilyFilter!,
          if (selectedCustomerTypeFilter != null && selectedCustomerTypeFilter != 'All')
            'customer_type': selectedCustomerTypeFilter!,
        },
      );
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (response.statusCode != 200) {
        throw HttpException('Unable to load customers (${response.statusCode})');
      }
      final parsed = jsonDecode(response.body);
      if (parsed is! Map || parsed['results'] is! List) {
        throw const FormatException('Unexpected customer API response');
      }
      final List data = parsed['results'] as List;
      final int count = (parsed['count'] as num?)?.toInt() ?? 0;
      final newCustomers = data.whereType<Map>().map((item) => <String, dynamic>{
        'id': item['id'],
        'name': item['name'],
        'created_at': item['created_at'],
        'phone': item['phone'],
        'family': item['family'],
        'state_name': item['state_name'],
        'manager': item['manager'],
      }).toList();
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        currentPage = page;
        totalPages = count == 0 ? 1 : (count / (data.isEmpty ? 10 : data.length)).ceil();
        final seen = customer.map((e) => e['id']).toSet();
        for (final entry in newCustomers) {
          if (seen.add(entry['id'])) customer.add(entry);
        }
        _hasMoreCustomers = data.isNotEmpty && customer.length < count;
      });
      applyFilters();
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _paginationError = error.toString();
        if (page == 1) _hasMoreCustomers = false;
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => loadingPage = false);
      }
    }
  }

  // Staff List uses /api/get/staffs/ with results.data and pagination.
  // Resolve IDs only for the Excel Manager column; leave the UI unchanged.
  Future<Map<String, String>> _loadManagerNamesForExcel(
    List<Map<String, dynamic>> rows,
  ) async {
    final names = <String, String>{};
    for (final staff in sta) {
      final id = staff['id']?.toString().trim() ?? '';
      final name = staff['name']?.toString().trim() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) names[id] = name;
    }

    final requiredIds = rows
        .map((row) => row['manager']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty && !names.containsKey(id))
        .toSet();
    if (requiredIds.isEmpty) return names;

    final token = await gettokenFromPrefs();
    if (token == null || token.isEmpty) {
      throw StateError('Authentication token not found');
    }

    Uri? next = Uri.parse('$api/api/get/staffs/');
    final visited = <String>{};
    while (next != null && requiredIds.isNotEmpty) {
      if (!visited.add(next.toString())) {
        throw StateError('Staff API returned a repeated pagination URL');
      }
      final response = await http.get(next, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException(
          'Unable to resolve staff names (${response.statusCode})',
        );
      }
      final parsed = jsonDecode(response.body);
      if (parsed is! Map || parsed['results'] is! Map ||
          parsed['results']['data'] is! List) {
        throw const FormatException('Unexpected staff API response');
      }
      for (final entry in parsed['results']['data'] as List) {
        if (entry is! Map) continue;
        final id = entry['id']?.toString().trim() ?? '';
        final name = entry['name']?.toString().trim() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          names[id] = name;
          requiredIds.remove(id);
        }
      }
      final nextValue = parsed['next']?.toString();
      next = nextValue == null || nextValue.isEmpty
          ? null
          : next!.resolve(nextValue);
    }
    return names;
  }

  Future<void> _exportCustomersExcel() async {
    if (_exportingExcel) return;

    // Same export flow as GSTReportPage: export already loaded report data.
    final rows = List<Map<String, dynamic>>.from(filteredProducts);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers to export')),
      );
      return;
    }

    setState(() => _exportingExcel = true);
    try {
      final managerNames = await _loadManagerNamesForExcel(rows);
      final workbook = Excel.createExcel();
      final defaultSheet = workbook.getDefaultSheet();
      if (defaultSheet != null) {
        workbook.delete(defaultSheet);
      }
      final sheet = workbook['Customers'];
      final headers = <String>[
        'ID', 'Customer Name', 'Created At', 'Phone',
        'Family', 'State', 'Manager',
      ];

      sheet.appendRow(headers);
      for (int col = 0; col < headers.length; col++) {
        sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: 0,
        )).cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      for (final cust in rows) {
        sheet.appendRow([
          cust['id']?.toString() ?? '',
          cust['name']?.toString() ?? '',
          cust['created_at']?.toString() ?? '',
          cust['phone']?.toString() ?? '',
          cust['family']?.toString() ?? '',
          cust['state_name']?.toString() ?? '',
          managerNames[cust['manager']?.toString().trim() ?? ''] ?? '',
        ]);
      }

      final bytes = workbook.encode();
      if (bytes == null) {
        throw StateError('Could not generate Excel file');
      }

      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final filePath = '${directory.path}/Customers_$stamp.xlsx';
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel exported successfully (${rows.length} customers)')),
      );
      await OpenFilex.open(filePath);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  // Filtering is performed by Django. Keep the visible list in sync with
  // the backend response rather than filtering only loaded records.
  void applyFilters() {
    if (!mounted) return;
    setState(() {
      filteredProducts = List<Map<String, dynamic>>.from(customer);
    });
  }

  void _reloadFilteredCustomers() {
    if (_customerScrollController.hasClients) {
      _customerScrollController.jumpTo(0);
    }
    getcustomer(page: 1);
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    searchController.clear();
    setState(() {
      selectedFamilyFilter = 'All';
      selectedStateFilter = 'All';
      selectedStaffFilter = 'All';
      selectedCustomerTypeFilter = 'All';
    });
    _reloadFilteredCustomers();
  }

  Future<void> getcustomertype() async {
    try {
      final token = await gettokenFromPrefs();
      if (token == null || token.isEmpty) return;
      final response = await http.get(
        Uri.parse('$api/api/customer-types/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) return;
      final parsed = jsonDecode(response.body);
      final data = parsed is List ? parsed : (parsed is Map ? parsed['data'] : null);
      if (data is! List) return;
      final customerTypes = data.whereType<Map>().map((entry) => <String, dynamic>{
        'id': entry['id'],
        'name': entry['type_name'],
      }).toList();
      if (mounted) setState(() => type = customerTypes);
    } catch (error) {
      debugPrint('Failed to load customer types: $error');
    }
  }

  Future<void> getstaff() async {
    try {
      final token = await gettokenFromPrefs();

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
            'email': productData['email']
          });
        }
        setState(() {
          sta = stafflist;
        });
      }
    } catch (error) {}
  }

  Future<void> getfamily() async {
    try {
      final token = await gettokenFromPrefs();
      var response = await http.get(
        Uri.parse('$api/api/familys/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      List<Map<String, dynamic>> familylist = [];
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];
        for (var productData in productsData) {
          familylist.add({
            'id': productData['id'],
            'name': productData['name'],
          });
        }
        setState(() {
          fam = familylist;
        });
      }
    } catch (error) {}
  }

  Future<void> getstate() async {
    try {
      final token = await gettokenFromPrefs();
      var response = await http.get(
        Uri.parse('$api/api/states/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      List<Map<String, dynamic>> statelist = [];
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];
        for (var productData in productsData) {
          statelist.add({
            'id': productData['id'],
            'name': productData['name'],
          });
        }
        setState(() {
          stat = statelist;
        });
      }
    } catch (error) {}
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

  Future<void> _navigateBack() async {
    final dep = await getdepFromPrefs();
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
    } 
      else if (dep == "HR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HrDashboard(),
        ),
      );
    }else if (dep == "warehouse") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WarehouseDashboard()),
      );
    }else if (dep == "COO") {
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
    } else if (dep == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => cso_dashboard()),
      );
    } else if (dep == "Marketing") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => marketing_dashboard()),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            "Customer List",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final dep = await getdepFromPrefs();
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
              }   else if (dep == "HR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HrDashboard(),
        ),
      );
    }else if (dep == "COO") {
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
    }else if (dep == "warehouse") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => WarehouseDashboard()),
                );
              } else if (dep == "Warehouse Admin") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => WarehouseAdmin()),
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
              } else if (dep == "CSO") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => cso_dashboard()),
                );
              } else if (dep == "Marketing") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => marketing_dashboard()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => dashboard()),
                );
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Export customers to Excel',
              icon: _exportingExcel
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined, color: Colors.green),
              onPressed: _exportingExcel ? null : _exportCustomersExcel,
            ),
            IconButton(
              icon: Image.asset('lib/assets/profile.png'),
              onPressed: () {},
            ),
          ],
        ),
        //  drawer: Drawer(
        //     child: ListView(
        //       padding: EdgeInsets.zero,
        //       children: <Widget>[
        //         DrawerHeader(
        //             decoration: BoxDecoration(
        //               color: Colors.grey[200],
        //             ),
        //             child: Row(
        //               mainAxisAlignment: MainAxisAlignment.center,
        //               children: [
        //                 Image.asset(
        //                   "lib/assets/logo.png",
        //                   width: 150,
        //                   height: 150,
        //                   fit: BoxFit.contain,
        //                 ),
        //               ],
        //             )),
        //         ListTile(
        //           leading: Icon(Icons.dashboard),
        //           title: Text('Dashboard'),
        //           onTap: () {
        //             Navigator.push(context,
        //                 MaterialPageRoute(builder: (context) => dashboard()));
        //           },
        //         ),
        //
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Company'),
        //           onTap: () {
        //             Navigator.push(context,
        //                 MaterialPageRoute(builder: (context) => add_company()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Departments'),
        //           onTap: () {
        //             Navigator.push(
        //                 context,
        //                 MaterialPageRoute(
        //                     builder: (context) => add_department()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Supervisors'),
        //           onTap: () {
        //             Navigator.push(
        //                 context,
        //                 MaterialPageRoute(
        //                     builder: (context) => add_supervisor()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Family'),
        //           onTap: () {
        //             Navigator.push(context,
        //                 MaterialPageRoute(builder: (context) => add_family()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Bank'),
        //           onTap: () {
        //             Navigator.push(context,
        //                 MaterialPageRoute(builder: (context) => add_bank()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('States'),
        //           onTap: () {
        //             Navigator.push(context,
        //                 MaterialPageRoute(builder: (context) => add_state()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Attributes'),
        //           onTap: () {
        //             Navigator.push(context,
        //                 MaterialPageRoute(builder: (context) => add_attribute()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Services'),
        //           onTap: () {
        //             Navigator.push(
        //                 context,
        //                 MaterialPageRoute(
        //                     builder: (context) => CourierServices()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.person),
        //           title: Text('Delivery Notes'),
        //           onTap: () {
        //             Navigator.push(
        //                 context,
        //                 MaterialPageRoute(
        //                     builder: (context) => WarehouseOrderView(status: null,)));
        //           },
        //         ),
        //         Divider(),
        //         _buildDropdownTile(context, 'Reports', [
        //           'Sales Report',
        //           'Credit Sales Report',
        //           'COD Sales Report',
        //           'Statewise Sales Report',
        //           'Expence Report',
        //           'Delivery Report',
        //           'Product Sale Report',
        //           'Stock Report',
        //           'Damaged Stock'
        //         ]),
        //         _buildDropdownTile(context, 'Customers', [
        //           'Add Customer',
        //           'Customers',
        //         ]),
        //         _buildDropdownTile(context, 'Staff', [
        //           'Add Staff',
        //           'Staff',
        //         ]),
        //         _buildDropdownTile(context, 'Credit Note', [
        //           'Add Credit Note',
        //           'Credit Note List',
        //         ]),
        //         _buildDropdownTile(context, 'Proforma Invoice', [
        //           'New Proforma Invoice',
        //           'Proforma Invoice List',
        //         ]),
        //         _buildDropdownTile(context, 'Delivery Note',
        //             ['Delivery Note List', 'Daily Goods Movement']),
        //         _buildDropdownTile(
        //             context, 'Orders', ['New Orders', 'Orders List']),
        //         Divider(),
        //         Text("Others"),
        //         Divider(),
        //         _buildDropdownTile(context, 'Product', [
        //           'Product List',
        //           'Product Add',
        //           'Stock',
        //         ]),
        //         _buildDropdownTile(context, 'Expence', [
        //           'Add Expence',
        //           'Expence List',
        //         ]),
        //         _buildDropdownTile(
        //             context, 'GRV', ['Create New GRV', 'GRVs List']),
        //         _buildDropdownTile(context, 'Banking Module',
        //             ['Add Bank ', 'List', 'Other Transfer']),
        //         Divider(),
        //         ListTile(
        //           leading: Icon(Icons.settings),
        //           title: Text('Methods'),
        //           onTap: () {
        //             Navigator.push(context,
        //                 MaterialPageRoute(builder: (context) => Methods()));
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(Icons.chat),
        //           title: Text('Chat'),
        //           onTap: () {
        //             Navigator.pop(context);
        //           },
        //         ),
        //         Divider(),
        //         ListTile(
        //           leading: Icon(Icons.exit_to_app),
        //           title: Text('Logout'),
        //           onTap: () {
        //             logout();
        //           },
        //         ),
        //       ],
        //     ),
        //   ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Search customers..",
                      prefixIcon: Icon(Icons.search, color: Colors.blue),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide:
                            BorderSide(color: Colors.blueAccent, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                        if (mounted) _reloadFilteredCustomers();
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "Family",
                            labelStyle: TextStyle(color: Colors.blue),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  BorderSide(color: Colors.blue, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                  color: Colors.blueAccent, width: 2),
                            ),
                          ),
                          key: ValueKey('selectedFamilyFilter_${selectedFamilyFilter}'),
                          value: selectedFamilyFilter,
                          items: [
                            DropdownMenuItem(
                                value: "All", child: Text("All Family")),
                            ...fam.map(
                              (f) => DropdownMenuItem(
                                value: f['id'].toString(),
                                child: Text(
                                  f['name'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedFamilyFilter = val;
                              selectedStateFilter = "All";
                              selectedStaffFilter = "All";
                            });
                            _reloadFilteredCustomers();
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "State",
                            labelStyle: TextStyle(color: Colors.blue),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  BorderSide(color: Colors.blue, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                  color: Colors.blueAccent, width: 2),
                            ),
                          ),
                          key: ValueKey('selectedStateFilter_${selectedStateFilter}'),
                          value: selectedStateFilter,
                          items: [
                            DropdownMenuItem(
                                value: "All", child: Text("All States")),
                            ...stat.map(
                              (s) => DropdownMenuItem(
                                value: s['id'].toString(),
                                child: Text(
                                  s['name'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedStateFilter = val;
                              selectedFamilyFilter = "All";
                              selectedStaffFilter = "All";
                            });
                            _reloadFilteredCustomers();
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "Staff",
                            labelStyle: TextStyle(color: Colors.blue),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  BorderSide(color: Colors.blue, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                  color: Colors.blueAccent, width: 2),
                            ),
                          ),
                          key: ValueKey('selectedStaffFilter_${selectedStaffFilter}'),
                          value: selectedStaffFilter,
                          items: [
                            DropdownMenuItem(
                                value: "All", child: Text("All Staff")),
                            ...sta.map(
                              (s) => DropdownMenuItem(
                                value: s['id'].toString(),
                                child: Text(
                                  "${s['name']}",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedStaffFilter = val;
                              selectedFamilyFilter = "All";
                              selectedStateFilter = "All";
                            });
                            _reloadFilteredCustomers();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey('selectedCustomerTypeFilter_${selectedCustomerTypeFilter}'),
                          value: selectedCustomerTypeFilter,
                          decoration: InputDecoration(
                            labelText: 'Customer Type',
                            labelStyle: const TextStyle(color: Colors.blue),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Types')),
                            ...type.map((t) => DropdownMenuItem<String>(
                              value: t['id'].toString(),
                              child: Text(t['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() => selectedCustomerTypeFilter = value);
                            _reloadFilteredCustomers();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Clear Filters'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            minimumSize: const Size(0, 56),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (loadingPage && customer.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            Expanded(
              child: ListView.builder(
                controller: _customerScrollController,
                itemCount: filteredProducts.length +
                    ((loadingPage || _paginationError != null) ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= filteredProducts.length) {
                    if (loadingPage) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return TextButton.icon(
                      onPressed: () => getcustomer(page: currentPage + 1),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Could not load more customers. Tap to retry.'),
                    );
                  }
                  final customerData = filteredProducts[index];
                  return Card(
                    color: Colors.white,
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerCompleteReportPage(
                              customerId: customerData['id'],
                            ),
                          ),
                        );
                      },
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerData['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Created on: ${customerData['created_at']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.blue),
                            onSelected: (value) {
                              if (value == 'View') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => view_customer(
                                      customerid: customerData['id'],
                                    ),
                                  ),
                                );
                              } else if (value == 'Add Address') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => add_address(
                                      customerid: customerData['id'],
                                      name: customerData['name'],
                                    ),
                                  ),
                                );
                              } else if (value == 'View Ledger') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CustomerLedger(
                                      customerid: customerData['id'],
                                      customerName: customerData['name'],
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'View',
                                child: Text('View'),
                              ),
                              PopupMenuItem<String>(
                                value: 'Add Address',
                                child: Text('Add Address'),
                              ),
                              PopupMenuItem<String>(
                                value: 'View Ledger',
                                child: Text('View Ledger'),
                              ),
                            ],
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
}