import 'dart:convert';
import 'dart:io';

import 'package:beposoft/Sales%20Directors/SD_dashboard.dart';
import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/add_staff.dart';
import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/view_staff.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/HR/hr_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Staff_Update extends StatefulWidget {
  final dynamic id;

  const Staff_Update({super.key, required this.id});

  @override
  State<Staff_Update> createState() => _Staff_UpdateState();
}

class _Staff_UpdateState extends State<Staff_Update> {
  final TextEditingController name = TextEditingController();
  final TextEditingController username = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController alternate_number = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController driving_license = TextEditingController();
  final TextEditingController employment_status = TextEditingController();
  final TextEditingController designation = TextEditingController();
  final TextEditingController grade = TextEditingController();
  final TextEditingController paid_leaves = TextEditingController();

  // Salary
  final TextEditingController salary = TextEditingController();
  final TextEditingController incrementYear = TextEditingController();
  final TextEditingController incrementAmount = TextEditingController();
  final TextEditingController incrementRemarks = TextEditingController();

  final TextEditingController address = TextEditingController();
  final TextEditingController city = TextEditingController();
  final TextEditingController Country = TextEditingController();
  final TextEditingController staff_id = TextEditingController();
  final TextEditingController emergency_contact_name = TextEditingController();
  final TextEditingController emergency_contact_number =
      TextEditingController();
  final TextEditingController experience = TextEditingController();
  final TextEditingController previous_company = TextEditingController();
  final TextEditingController education = TextEditingController();
  final TextEditingController aadhar_no = TextEditingController();
  final TextEditingController pan_no = TextEditingController();
  final TextEditingController place = TextEditingController();
  final TextEditingController emergency_contact_name1 = TextEditingController();
  final TextEditingController emergency_contact_number1 =
      TextEditingController();

  List<Map<String, dynamic>> statess = [];
  List<Map<String, dynamic>> fam = [];
  List<Map<String, dynamic>> dep = [];
  List<Map<String, dynamic>> manager = [];
  List<Map<String, dynamic>> warehouses = [];
  List<Map<String, dynamic>> country = [];
  List<Map<String, dynamic>> sta = [];

  List<int> selectedFamily = [];
  List<int> dynamicStatid = [];
  List<String> selectedAllocatedStateNames = [];

  int? selectedCountryId;
  int? selectedDepartmentId;
  int? selectedManagerId;
  int? selectedWarehouseId;
  int? selectedPostingStateId;

  String? selectedCountryName;
  String? selectedDepartmentName;
  String? selectedManagerName;
  String? selectedWarehouseName;

  String? selectstate;
  int? selectedStateId;

  String staffId = '';
  bool isLoading = false;
  bool isPageLoading = true;

  File? selectedImage;
  File? selectedSignature;
  File? selectedExpLetter;
  File? selectedSalarySlip;

  String? existingImageUrl;
  String? existingSignatureUrl;
  String? existingExpLetterUrl;
  String? existingSalarySlipUrl;

  File? selectedAadharImage;
  File? selectedPanImage;

  String? existingAadharImageUrl;
  String? existingPanImageUrl;

  List<int> allocated_states = [];
  List<String> allocatedStateNames = [];

  final List<String> genderList = ["Female", "Male", "Other"];
  String selectgender = "Female";

  final List<String> maritalList = ["Married", "Single", "Other"];
  String selectmarital = "Single";

  final List<String> approvalList = ["approved", "disapproved"];
  String approvalstatus = "approved";

  final List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  String? selectedBloodGroup;

  DateTime selectedDate = DateTime.now();
  DateTime selecteExp = DateTime.now();
  DateTime selectejoin = DateTime.now();
  DateTime selecteconf = DateTime.now();
  DateTime? selectedTerminationDate;

  bool isManager = false;

  int? salaryRecordId;
  bool isSalaryLoading = false;
  bool isSalaryCreating = false;
  bool isSalaryUpdating = false;
  bool isSalaryEditing = false;
  int? editingIncrementId;

  // Salary increment history from GET api/staff/salary/
  List<Map<String, dynamic>> salaryIncrements = [];

  final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');

  drower d = drower();

  @override
  void initState() {
    super.initState();
    initdata();
  }

  Future<void> initdata() async {
    debugPrint('========== UPDATE STAFF PAGE INIT ==========');
    debugPrint('WIDGET STAFF ID: ${widget.id}');
    debugPrint('============================================');

    await Future.wait([
      getdepartments(),
      getmanegers(),
      getwarehouse(),
      getcountry(),
      getfamily(),
      getstates(),
      getstaffList(),
    ]);
    await getstaff();
    await getStaffSalary();

    if (mounted) {
      setState(() {
        isPageLoading = false;
      });
    }
  }

  Future<String?> gettokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    debugPrint(
      'AUTH TOKEN STATUS: ${token == null || token.isEmpty ? 'MISSING' : 'AVAILABLE'}',
    );
    return token;
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  Future<void> _navigateBack() async {
    final depValue = await getdepFromPrefs();
    if (!mounted) return;

    if (depValue == "BDO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => bdo_dashbord()),
      );
    } else if (depValue == "BDM") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => bdm_dashbord()),
      );
    } else if (depValue == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    }
    else if (depValue == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => cso_dashboard()),
      );
    }else if (depValue == "SD") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SdDashboard()),
      );
    } else if (depValue == "HR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HrDashboard()),
      );
    } else if (depValue == "warehouse") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WarehouseDashboard()),
      );
    } else if (depValue == "CEO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    } else if (depValue == "COO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ceo_dashboard()),
      );
    } else if (depValue == "CSO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => cso_dashboard()),
      );
    } else if (depValue == "Warehouse Admin") {
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

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  bool _isPdfFile(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  Future<void> _openLocalFile(File file) async {
    await OpenFilex.open(file.path);
  }

  Future<void> _openNetworkFile(String url) async {
    final fullUrl = url.startsWith('http') ? url : '$api$url';
    await OpenFilex.open(fullUrl);
  }

  void _showFullPreview({
    required BuildContext context,
    File? file,
    String? networkPath,
    required bool isPdf,
  }) {
    final String? path = file?.path ?? networkPath;

    if (path == null || path.isEmpty) return;

    if (isPdf) {
      if (file != null) {
        _openLocalFile(file);
      } else if (networkPath != null) {
        _openNetworkFile(networkPath);
      }
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: file != null
                        ? Image.file(
                            file,
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            networkPath!.startsWith('http')
                                ? networkPath
                                : '$api$networkPath',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> getcountry() async {
    final token = await gettokenFromPrefs();
    try {
      final response =
          await http.get(Uri.parse('$api/api/country/codes/'), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      debugPrint('========== GET COUNTRY CODES ==========');
      debugPrint('URL: $api/api/country/codes/');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=======================================');

      List<Map<String, dynamic>> countrylist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        for (var productData in productsData) {
          countrylist.add({
            'id': int.tryParse(productData['id'].toString()) ?? 0,
            'country_code': productData['country_code'],
          });
        }

        if (mounted) {
          setState(() {
            country = countrylist;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('GET COUNTRY ERROR: $e');
      debugPrint('GET COUNTRY STACKTRACE: $stackTrace');
    }
  }

  Future<void> getwarehouse() async {
    final token = await gettokenFromPrefs();
    try {
      final response =
          await http.get(Uri.parse('$api/api/warehouse/add/'), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      debugPrint('========== GET WAREHOUSES ==========');
      debugPrint('URL: $api/api/warehouse/add/');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('====================================');

      List<Map<String, dynamic>> warehouselist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);

        for (var productData in parsed) {
          warehouselist.add({
            'id': int.tryParse(productData['id'].toString()) ?? 0,
            'name': productData['name'],
            'location': productData['location'],
          });
        }

        if (mounted) {
          setState(() {
            warehouses = warehouselist;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('GET WAREHOUSE ERROR: $e');
      debugPrint('GET WAREHOUSE STACKTRACE: $stackTrace');
    }
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

      debugPrint('========== GET FAMILIES ==========');
      debugPrint('URL: $api/api/familys/');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('==================================');

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];
        List<Map<String, dynamic>> familylist = [];

        for (var productData in productsData) {
          familylist.add({
            'id': int.tryParse(productData['id'].toString()) ?? 0,
            'name': productData['name'],
          });
        }

        if (mounted) {
          setState(() {
            fam = familylist;
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('GET FAMILY ERROR: $error');
      debugPrint('GET FAMILY STACKTRACE: $stackTrace');
    }
  }

  Future<void> getstates() async {
    try {
      final token = await gettokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/states/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('========== GET STATES ==========');
      debugPrint('URL: $api/api/states/');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('================================');

      List<Map<String, dynamic>> stateslist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        for (var productData in productsData) {
          stateslist.add({
            'id': int.tryParse(productData['id'].toString()) ?? 0,
            'name': productData['name'],
          });
        }

        if (mounted) {
          setState(() {
            statess = stateslist;
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('GET STATES ERROR: $error');
      debugPrint('GET STATES STACKTRACE: $stackTrace');
    }
  }

  Future<void> getdepartments() async {
    try {
      final token = await gettokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/departments/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('========== GET DEPARTMENTS ==========');
      debugPrint('URL: $api/api/departments/');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=====================================');

      List<Map<String, dynamic>> departmentlist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        for (var productData in productsData) {
          departmentlist.add({
            'id': int.tryParse(productData['id'].toString()) ?? 0,
            'name': productData['name'],
          });
        }

        if (mounted) {
          setState(() {
            dep = departmentlist;
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('GET DEPARTMENTS ERROR: $error');
      debugPrint('GET DEPARTMENTS STACKTRACE: $stackTrace');
    }
  }

  Future<void> getmanegers() async {
    try {
      final token = await gettokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/supervisors/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('========== GET SUPERVISORS ==========');
      debugPrint('URL: $api/api/supervisors/');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=====================================');

      List<Map<String, dynamic>> managerlist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        for (var productData in productsData) {
          managerlist.add({
            'id': int.tryParse(productData['id'].toString()) ?? 0,
            'name': productData['name'],
            'department_name': productData['department_name'],
          });
        }

        if (mounted) {
          setState(() {
            manager = managerlist;
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('GET SUPERVISORS ERROR: $error');
      debugPrint('GET SUPERVISORS STACKTRACE: $stackTrace');
    }
  }

  Future<void> getstaffList() async {
    try {
      final token = await gettokenFromPrefs();

      var response = await http.get(
        Uri.parse('$api/api/staffs/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('========== GET STAFF LIST ==========');
      debugPrint('URL: $api/api/staffs/');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('====================================');

      List<Map<String, dynamic>> stafflist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        for (var productData in productsData) {
          stafflist.add({
            'id': productData['id'],
            'name': productData['name'],
            'email': productData['email'],
          });
        }

        if (mounted) {
          setState(() {
            sta = stafflist;
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('GET STAFF LIST ERROR: $error');
      debugPrint('GET STAFF LIST STACKTRACE: $stackTrace');
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

      debugPrint('========== GET CURRENT STAFF ==========');
      debugPrint('URL: $api/api/staffs/');
      debugPrint('TARGET STAFF ID: ${widget.id}');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=======================================');

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var staffDataList = parsed['data'];

        for (var staffData in staffDataList) {
          debugPrint(
            'CHECKING STAFF -> API ID: ${staffData['id']} | TARGET ID: ${widget.id}',
          );

          if (widget.id.toString() == staffData['id'].toString()) {
            debugPrint('MATCHED STAFF DATA: ${jsonEncode(staffData)}');
            name.text = staffData['name']?.toString() ?? '';
            username.text = staffData['username']?.toString() ?? '';
            email.text = staffData['email']?.toString() ?? '';
            phone.text = staffData['phone']?.toString() ?? '';
            alternate_number.text =
                staffData['alternate_number']?.toString() ?? '';
            password.text = '';
            driving_license.text =
                staffData['driving_license']?.toString() ?? '';
            employment_status.text =
                staffData['employment_status']?.toString() ?? '';
            designation.text = staffData['designation']?.toString() ?? '';
            grade.text = staffData['grade']?.toString() ?? '';
            paid_leaves.text = staffData['paid_leaves']?.toString() ?? '0';
            address.text = staffData['address']?.toString() ?? '';
            city.text = staffData['city']?.toString() ?? '';
            Country.text = staffData['country']?.toString() ?? '';
            staff_id.text = staffData['staff_id']?.toString() ?? '';
            emergency_contact_name.text =
                staffData['emergency_contact_name']?.toString() ?? '';
            emergency_contact_number.text =
                staffData['emergency_contact_number']?.toString() ?? '';
            experience.text = staffData['experience']?.toString() ?? '';
            previous_company.text =
                staffData['previous_company']?.toString() ?? '';
            education.text = staffData['education']?.toString() ?? '';
            aadhar_no.text = staffData['aadhar_no']?.toString() ?? '';
            pan_no.text = staffData['pan_no']?.toString() ?? '';
            place.text = staffData['place']?.toString() ?? '';

            selectgender = staffData['gender']?.toString() ?? "Female";
            selectmarital = staffData['marital_status']?.toString() ?? "Single";
            approvalstatus =
                staffData['approval_status']?.toString() ?? "approved";
            selectedBloodGroup = staffData['blood_group']?.toString();
            isManager = staffData['is_manager'] ?? false;

            selectedCountryId =
                int.tryParse(staffData['country_code']?.toString() ?? '');
            selectedDepartmentId =
                int.tryParse(staffData['department_id']?.toString() ?? '');
            selectedManagerId =
                int.tryParse(staffData['supervisor_id']?.toString() ?? '');
            selectedWarehouseId =
                int.tryParse(staffData['warehouse_id']?.toString() ?? '');
            selectedPostingStateId =
                int.tryParse(staffData['state']?.toString() ?? '');
            existingAadharImageUrl = staffData['aadhar_image']?.toString();
            existingPanImageUrl = staffData['pan_image']?.toString();
            emergency_contact_name1.text =
                staffData['emergency_contact_name1']?.toString() ?? '';

            emergency_contact_number1.text =
                staffData['emergency_contact_number1']?.toString() ?? '';

            if (staffData['family'] != null) {
              selectedFamily = [
                int.tryParse(staffData['family'].toString()) ?? 0,
              ];
            }

            selectedDepartmentName = selectedDepartmentId != null
                ? dep
                    .firstWhere(
                      (e) => e['id'] == selectedDepartmentId,
                      orElse: () => {'name': null},
                    )['name']
                    ?.toString()
                : null;

            selectedManagerName = selectedManagerId != null
                ? manager
                    .firstWhere(
                      (e) => e['id'] == selectedManagerId,
                      orElse: () => {'name': null},
                    )['name']
                    ?.toString()
                : null;

            selectedWarehouseName = selectedWarehouseId != null
                ? warehouses
                    .firstWhere(
                      (e) => e['id'] == selectedWarehouseId,
                      orElse: () => {'name': null},
                    )['name']
                    ?.toString()
                : null;

            selectedCountryName = selectedCountryId != null
                ? country
                    .firstWhere(
                      (e) => e['id'] == selectedCountryId,
                      orElse: () => {'country_code': null},
                    )['country_code']
                    ?.toString()
                : null;

            if (staffData['date_of_birth'] != null &&
                staffData['date_of_birth'].toString().isNotEmpty) {
              selectedDate = DateTime.parse(staffData['date_of_birth']);
            }

            if (staffData['driving_license_exp_date'] != null &&
                staffData['driving_license_exp_date'].toString().isNotEmpty) {
              selecteExp =
                  DateTime.parse(staffData['driving_license_exp_date']);
            }

            if (staffData['join_date'] != null &&
                staffData['join_date'].toString().isNotEmpty) {
              selectejoin = DateTime.parse(staffData['join_date']);
            }

            if (staffData['confirmation_date'] != null &&
                staffData['confirmation_date'].toString().isNotEmpty) {
              selecteconf = DateTime.parse(staffData['confirmation_date']);
            }

            if (staffData['termination_date'] != null &&
                staffData['termination_date'].toString().isNotEmpty) {
              selectedTerminationDate =
                  DateTime.parse(staffData['termination_date']);
            }

            existingImageUrl = staffData['image']?.toString();
            existingSignatureUrl = staffData['signatur_up']?.toString();
            existingExpLetterUrl = staffData['exp_letter']?.toString();
            existingSalarySlipUrl = staffData['salrary_slip']?.toString();

            if (staffData['allocated_states'] != null) {
              allocated_states = List<int>.from(
                (staffData['allocated_states'] as List).map(
                  (e) => int.tryParse(e.toString()) ?? 0,
                ),
              );

              allocatedStateNames = allocated_states
                  .map((stateId) => statess.firstWhere(
                        (element) => element['id'] == stateId,
                        orElse: () => {'name': 'Unknown'},
                      )['name'] as String)
                  .toList();
            }

            break;
          }
        }

        if (mounted) {
          setState(() {});
        }
      }
    } catch (error, stackTrace) {
      debugPrint('GET CURRENT STAFF ERROR: $error');
      debugPrint('GET CURRENT STAFF STACKTRACE: $stackTrace');
    }
  }


  Future<void> getStaffSalary() async {
    final token = await gettokenFromPrefs();

    if (token == null || token.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        isSalaryLoading = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('$api/api/staff/salary/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('========== GET STAFF SALARY ==========');
      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('TARGET STAFF ID: ${widget.id}');
      debugPrint('======================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        salaryRecordId = null;

        final dynamic decoded = jsonDecode(response.body);

        List<dynamic> salaryList = [];

        if (decoded is List) {
          salaryList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            salaryList = decoded['data'];
          } else if (decoded['results'] is List) {
            salaryList = decoded['results'];
          }
        }

        Map<String, dynamic>? matchedSalary;

        for (final item in salaryList) {
          if (item is! Map) continue;

          final map = Map<String, dynamic>.from(item);

          debugPrint('SALARY ITEM: ${jsonEncode(map)}');

          dynamic staffValue = map['staff'];

          int? staffValueId;

          if (staffValue is Map) {
            staffValueId = int.tryParse(
              (staffValue['id'] ?? staffValue['staff_id'] ?? '').toString(),
            );
          } else {
            staffValueId = int.tryParse(staffValue?.toString() ?? '');
          }

          debugPrint(
            'SALARY MATCH CHECK -> STAFF VALUE: $staffValue | PARSED STAFF ID: $staffValueId | TARGET STAFF ID: ${widget.id}',
          );

          if (staffValueId == int.tryParse(widget.id.toString())) {
            matchedSalary = map;
            debugPrint('MATCHED SALARY RECORD: ${jsonEncode(map)}');
            break;
          }
        }

        if (matchedSalary != null) {
          salaryRecordId =
              int.tryParse(matchedSalary['id']?.toString() ?? '');

          final dynamic salaryValue =
              matchedSalary['salary'] ??
              matchedSalary['current_salary'] ??
              matchedSalary['amount'];

          salary.text = salaryValue?.toString() ?? '';

          final dynamic incrementsData = matchedSalary['increments'];

          if (incrementsData is List) {
            salaryIncrements = incrementsData
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

            // Show latest increment first.
            salaryIncrements.sort((a, b) {
              final int aId =
                  int.tryParse(a['id']?.toString() ?? '') ?? 0;
              final int bId =
                  int.tryParse(b['id']?.toString() ?? '') ?? 0;
              return bId.compareTo(aId);
            });
          } else {
            salaryIncrements = [];
          }

          debugPrint(
            'SALARY INCREMENTS: ${jsonEncode(salaryIncrements)}',
          );
        } else {
          salaryRecordId = null;
          salary.clear();
          salaryIncrements = [];
          debugPrint(
            'NO SALARY RECORD MATCHED FOR STAFF ID: ${widget.id}',
          );
        }

        debugPrint('FINAL SALARY RECORD ID: $salaryRecordId');
        debugPrint('FINAL CURRENT SALARY: ${salary.text}');
        debugPrint(
          'TOTAL INCREMENTS: ${salaryIncrements.length}',
        );
        debugPrint(
          'SALARY UI MODE: ${salaryRecordId == null ? 'CREATE SALARY' : 'INCREMENT SALARY'}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('GET STAFF SALARY ERROR: $e');
      debugPrint('GET STAFF SALARY STACKTRACE: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          isSalaryLoading = false;
        });
      }
    }
  }

  Future<bool> createStaffSalary(
    BuildContext scaffoldContext,
  ) async {
    final String salaryText = salary.text.trim();

    debugPrint('========== CREATE STAFF SALARY BUTTON ==========');
    debugPrint('TARGET STAFF ID: ${widget.id}');
    debugPrint('SALARY INPUT: $salaryText');
    debugPrint('================================================');

    if (salaryText.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter salary.'),
        ),
      );
      return false;
    }

    final num? salaryAmount = num.tryParse(salaryText);

    if (salaryAmount == null || salaryAmount <= 0) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter a valid salary.'),
        ),
      );
      return false;
    }

    final int? staffPk = int.tryParse(widget.id.toString());

    if (staffPk == null) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Invalid staff ID.'),
        ),
      );
      return false;
    }

    final token = await gettokenFromPrefs();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Authentication token not found.'),
        ),
      );
      return false;
    }

    if (mounted) {
      setState(() {
        isSalaryCreating = true;
      });
    }

    try {
      final Map<String, dynamic> body = {
        'staff': staffPk,
        'salary': salaryAmount,
      };

      debugPrint('========== CREATE STAFF SALARY ==========');
      debugPrint('URL: $api/api/staff/salary/');
      debugPrint('REQUEST: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$api/api/staff/salary/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=========================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await getStaffSalary();

        if (!mounted) return true;

        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Salary added successfully.'),
          ),
        );

        return true;
      }

      if (!mounted) return false;

      String errorMessage = 'Failed to add salary.';

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final dynamic errors = decoded['errors'];

          if (errors is Map) {
            errorMessage = errors.entries.map((entry) {
              final value = entry.value;
              if (value is List) {
                return '${entry.key}: ${value.join(', ')}';
              }
              return '${entry.key}: $value';
            }).join('\n');
          } else {
            errorMessage =
                decoded['message']?.toString() ??
                decoded['detail']?.toString() ??
                decoded['error']?.toString() ??
                response.body;
          }
        }
      } catch (_) {
        errorMessage =
            'Failed to add salary. Status: ${response.statusCode}';
      }

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(errorMessage),
        ),
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint('CREATE STAFF SALARY ERROR: $e');
      debugPrint('CREATE STAFF SALARY STACKTRACE: $stackTrace');

      if (!mounted) return false;

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Salary creation error: $e'),
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSalaryCreating = false;
        });
      }
    }
  }

  Future<bool> updateStaffSalaryIncrement(
    BuildContext scaffoldContext,
  ) async {
    debugPrint('========== SALARY INCREMENT BUTTON ==========');
    debugPrint('TARGET STAFF ID: ${widget.id}');
    debugPrint('SALARY RECORD ID: $salaryRecordId');
    debugPrint('CURRENT SALARY: ${salary.text}');
    debugPrint('INCREMENT YEAR INPUT: ${incrementYear.text}');
    debugPrint('INCREMENT AMOUNT INPUT: ${incrementAmount.text}');
    debugPrint('INCREMENT REMARKS INPUT: ${incrementRemarks.text}');
    debugPrint('=============================================');

    if (salaryRecordId == null) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Salary record not found for this staff.',
          ),
        ),
      );
      return false;
    }

    final String yearText = incrementYear.text.trim();
    final String amountText = incrementAmount.text.trim();
    final String remarksText = incrementRemarks.text.trim();

    if (yearText.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter increment year.'),
        ),
      );
      return false;
    }

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter increment amount.'),
        ),
      );
      return false;
    }

    final int? year = int.tryParse(yearText);
    final num? amount = num.tryParse(amountText);

    if (year == null || year < 2000 || year > 2101) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter a valid increment year.'),
        ),
      );
      return false;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter a valid increment amount.'),
        ),
      );
      return false;
    }

    final token = await gettokenFromPrefs();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Authentication token not found.'),
        ),
      );
      return false;
    }

    if (mounted) {
      setState(() {
        isSalaryUpdating = true;
      });
    }

    try {
      final Map<String, dynamic> body = {
        'year': year,
        'increment_amount': amount,
        'remarks': remarksText,
      };

      debugPrint('========== ADD STAFF SALARY INCREMENT ==========');
      debugPrint(
        'URL: $api/api/staff/salary/update/$salaryRecordId/',
      );
      debugPrint('REQUEST: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse(
          '$api/api/staff/salary/update/$salaryRecordId/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=========================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await getStaffSalary();

        if (!mounted) return true;

        incrementYear.clear();
        incrementAmount.clear();
        incrementRemarks.clear();

        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Salary increment updated successfully.'),
          ),
        );

        return true;
      }

      if (!mounted) return false;

      String errorMessage = 'Failed to update salary increment.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          errorMessage =
              decoded['message']?.toString() ??
              decoded['detail']?.toString() ??
              decoded['error']?.toString() ??
              response.body;
        }
      } catch (_) {
        errorMessage =
            'Failed to update salary increment. Status: ${response.statusCode}';
      }

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(errorMessage),
        ),
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint('UPDATE STAFF SALARY ERROR: $e');
      debugPrint('UPDATE STAFF SALARY STACKTRACE: $stackTrace');

      if (!mounted) return false;

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Salary update error: $e'),
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSalaryUpdating = false;
        });
      }
    }
  }


  Future<bool> editStaffSalary({
    required BuildContext scaffoldContext,
    required num updatedSalary,
  }) async {
    if (salaryRecordId == null) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Salary record not found.'),
        ),
      );
      return false;
    }

    final token = await gettokenFromPrefs();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Authentication token not found.'),
        ),
      );
      return false;
    }

    if (mounted) {
      setState(() {
        isSalaryEditing = true;
      });
    }

    try {
      final Map<String, dynamic> body = {
        'salary': updatedSalary,
      };

      debugPrint('========== EDIT STAFF SALARY ==========');
      debugPrint(
        'URL: $api/api/staff/salary/edit/$salaryRecordId/',
      );
      debugPrint('REQUEST: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse(
          '$api/api/staff/salary/edit/$salaryRecordId/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('=======================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final dynamic decoded = jsonDecode(response.body);

          if (decoded is Map<String, dynamic> &&
              decoded['data'] is Map) {
            final Map<String, dynamic> responseData =
                Map<String, dynamic>.from(decoded['data']);

            final dynamic salaryValue =
                responseData['salary'] ??
                responseData['current_salary'] ??
                responseData['amount'];

            if (salaryValue != null) {
              salary.text = salaryValue.toString();
            }

            final dynamic incrementsData =
                responseData['increments'];

            if (incrementsData is List) {
              salaryIncrements = incrementsData
                  .whereType<Map>()
                  .map(
                    (item) =>
                        Map<String, dynamic>.from(item),
                  )
                  .toList();

              salaryIncrements.sort((a, b) {
                final int aId =
                    int.tryParse(a['id']?.toString() ?? '') ?? 0;
                final int bId =
                    int.tryParse(b['id']?.toString() ?? '') ?? 0;
                return bId.compareTo(aId);
              });
            }
          }
        } catch (e, stackTrace) {
          debugPrint(
            'EDIT SALARY RESPONSE PARSE ERROR: $e',
          );
          debugPrint(
            'EDIT SALARY RESPONSE PARSE STACKTRACE: $stackTrace',
          );
        }

        if (mounted) {
          setState(() {});
        }

        if (!mounted) return true;

        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Salary updated successfully.'),
          ),
        );

        return true;
      }

      if (!mounted) return false;

      String message = 'Failed to update salary.';

      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message =
              decoded['message']?.toString() ??
              decoded['detail']?.toString() ??
              decoded['error']?.toString() ??
              response.body;
        }
      } catch (_) {
        message =
            'Failed to update salary. Status: ${response.statusCode}';
      }

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
        ),
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint('EDIT STAFF SALARY ERROR: $e');
      debugPrint('EDIT STAFF SALARY STACKTRACE: $stackTrace');

      if (!mounted) return false;

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Salary edit error: $e'),
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSalaryEditing = false;
        });
      }
    }
  }

  Future<bool> editSalaryIncrement({
    required BuildContext scaffoldContext,
    required int incrementId,
    required int year,
    required num incrementAmountValue,
    required String remarksValue,
  }) async {
    final token = await gettokenFromPrefs();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Authentication token not found.'),
        ),
      );
      return false;
    }

    if (mounted) {
      setState(() {
        editingIncrementId = incrementId;
      });
    }

    try {
      final Map<String, dynamic> body = {
        'year': year,
        'increment_amount': incrementAmountValue,
        'remarks': remarksValue,
      };

      debugPrint('========== EDIT SALARY INCREMENT ==========');
      debugPrint(
        'URL: $api/api/staff/salary/increment/edit/$incrementId/',
      );
      debugPrint('REQUEST: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse(
          '$api/api/staff/salary/increment/edit/$incrementId/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('===========================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await getStaffSalary();

        if (!mounted) return true;

        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Salary increment updated successfully.'),
          ),
        );

        return true;
      }

      if (!mounted) return false;

      String message = 'Failed to edit salary increment.';

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          message =
              decoded['message']?.toString() ??
              decoded['detail']?.toString() ??
              decoded['error']?.toString() ??
              response.body;
        }
      } catch (_) {
        message =
            'Failed to edit salary increment. Status: ${response.statusCode}';
      }

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
        ),
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint('EDIT SALARY INCREMENT ERROR: $e');
      debugPrint(
        'EDIT SALARY INCREMENT STACKTRACE: $stackTrace',
      );

      if (!mounted) return false;

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Increment edit error: $e'),
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          editingIncrementId = null;
        });
      }
    }
  }

  Future<void> _showEditSalaryDialog() async {
    String editedSalary = salary.text.trim();
    bool dialogSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Edit Salary',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: TextFormField(
                initialValue: editedSalary,
                enabled: !dialogSubmitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  'Salary',
                  icon: Icons.currency_rupee_rounded,
                ),
                onChanged: (value) {
                  editedSalary = value;
                },
              ),
              actions: [
                TextButton(
                  onPressed: dialogSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: dialogSubmitting
                      ? null
                      : () async {
                          final num? amount =
                              num.tryParse(editedSalary.trim());

                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  'Please enter a valid salary.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            dialogSubmitting = true;
                          });

                          final bool updated = await editStaffSalary(
                            scaffoldContext: context,
                            updatedSalary: amount,
                          );

                          if (!dialogContext.mounted) return;

                          if (updated) {
                            Navigator.of(dialogContext).pop();
                          } else {
                            setDialogState(() {
                              dialogSubmitting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: dialogSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditIncrementDialog(
    Map<String, dynamic> increment,
  ) async {
    final int? incrementId =
        int.tryParse(increment['id']?.toString() ?? '');

    if (incrementId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Invalid increment record ID.'),
        ),
      );
      return;
    }

    String editedYear =
        increment['year']?.toString() ?? '';
    String editedAmount =
        increment['increment_amount']?.toString() ?? '';
    String editedRemarks =
        increment['remarks']?.toString() ?? '';
    bool dialogSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Edit Increment',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: editedYear,
                      enabled: !dialogSubmitting,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        'Increment Year',
                        icon: Icons.calendar_today_outlined,
                      ),
                      onChanged: (value) {
                        editedYear = value;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: editedAmount,
                      enabled: !dialogSubmitting,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Increment Amount',
                        icon: Icons.trending_up_rounded,
                      ),
                      onChanged: (value) {
                        editedAmount = value;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: editedRemarks,
                      enabled: !dialogSubmitting,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Remarks',
                        icon: Icons.notes_outlined,
                      ),
                      onChanged: (value) {
                        editedRemarks = value;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: dialogSubmitting
                      ? null
                      : () async {
                          final int? year =
                              int.tryParse(editedYear.trim());

                          final num? amount =
                              num.tryParse(editedAmount.trim());

                          final String remarks =
                              editedRemarks.trim();

                          if (year == null ||
                              year < 2000 ||
                              year > 2101) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  'Please enter a valid increment year.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  'Please enter a valid increment amount.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            dialogSubmitting = true;
                          });

                          final bool updated =
                              await editSalaryIncrement(
                            scaffoldContext: context,
                            incrementId: incrementId,
                            year: year,
                            incrementAmountValue: amount,
                            remarksValue: remarks,
                          );

                          if (!dialogContext.mounted) return;

                          if (updated) {
                            Navigator.of(dialogContext).pop();
                          } else {
                            setDialogState(() {
                              dialogSubmitting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: dialogSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIncrementHistory() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBFD7FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.blue,
                size: 21,
              ),
              SizedBox(width: 8),
              Text(
                'Increment History',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (salaryIncrements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No increment history added yet.',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            ...salaryIncrements.asMap().entries.map(
              (entry) {
                final int index = entry.key;
                final Map<String, dynamic> increment = entry.value;

                return _buildIncrementHistoryCard(
                  increment: increment,
                  isLast: index == salaryIncrements.length - 1,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildIncrementHistoryCard({
    required Map<String, dynamic> increment,
    required bool isLast,
  }) {
    final String year =
        increment['year']?.toString() ?? '-';
    final String incrementAmountValue =
        increment['increment_amount']?.toString() ?? '-';
    final String previousSalary =
        increment['previous_salary']?.toString() ?? '-';
    final String newSalary =
        increment['new_salary']?.toString() ?? '-';

    final String remarks =
        increment['remarks']?.toString().trim().isNotEmpty == true
            ? increment['remarks'].toString()
            : '-';

    final int? incrementId =
        int.tryParse(increment['id']?.toString() ?? '');

    final bool isEditing =
        incrementId != null && editingIncrementId == incrementId;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        bottom: isLast ? 0 : 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD8E7FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Increment $year',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              if (isEditing)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Edit Increment',
                  onPressed: () {
                    _showEditIncrementDialog(increment);
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _salaryHistoryRow(
            'Year',
            year,
          ),
          _salaryHistoryRow(
            'Increment Amount',
            '₹$incrementAmountValue',
          ),
          _salaryHistoryRow(
            'Previous Salary',
            '₹$previousSalary',
          ),
          _salaryHistoryRow(
            'New Salary',
            '₹$newSalary',
          ),
          _salaryHistoryRow(
            'Remarks',
            remarks,
            isLastRow: true,
          ),
        ],
      ),
    );
  }

  Widget _salaryHistoryRow(
    String label,
    String value, {
    bool isLastRow = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastRow ? 0 : 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalarySection() {
    final bool hasSalaryRecord = salaryRecordId != null;

    return _buildSectionCard(
      title: hasSalaryRecord ? 'Salary & Increment' : 'Salary',
      children: [
        if (isSalaryLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: LinearProgressIndicator(),
          ),

        if (!isSalaryLoading && !hasSalaryRecord)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFBFD7FF),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No salary has been added for this staff. Enter the current salary below and save it first.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

        _buildTextField(
          salary,
          hasSalaryRecord ? 'Current Salary' : 'Salary',
          icon: Icons.currency_rupee_rounded,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          readOnly: hasSalaryRecord || isSalaryLoading,
        ),

        if (!isSalaryLoading && !hasSalaryRecord)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isSalaryCreating
                  ? null
                  : () async {
                      await createStaffSalary(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isSalaryCreating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                isSalaryCreating ? 'Adding Salary...' : 'Add Salary',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        if (!isSalaryLoading && hasSalaryRecord) ...[
          if (salaryIncrements.isEmpty)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: isSalaryEditing
                    ? null
                    : _showEditSalaryDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(
                    color: Colors.blue,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: isSalaryEditing
                    ? const SizedBox(
                        height: 17,
                        width: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.edit_outlined,
                        size: 19,
                      ),
                label: Text(
                  isSalaryEditing ? 'Updating Salary...' : 'Edit Salary',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          if (salaryIncrements.isEmpty)
            const SizedBox(height: 18),

          _buildTextField(
            incrementYear,
            'Increment Year',
            icon: Icons.calendar_today_outlined,
            keyboardType: TextInputType.number,
          ),
          _buildTextField(
            incrementAmount,
            'Increment Amount',
            icon: Icons.trending_up_rounded,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
          ),
          _buildTextField(
            incrementRemarks,
            'Remarks',
            icon: Icons.notes_outlined,
            maxLines: 3,
          ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isSalaryUpdating
                  ? null
                  : () async {
                      await updateStaffSalaryIncrement(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isSalaryUpdating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.trending_up_rounded),
              label: Text(
                isSalaryUpdating
                    ? 'Updating...'
                    : 'Add Salary Increment',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          _buildIncrementHistory(),
        ],
      ],
    );
  }

  Future<bool> registerUserData(BuildContext scaffoldContext) async {
    final token = await gettokenFromPrefs();

    try {
      var request = http.Request(
        'PUT',
        Uri.parse('$api/api/staff/update/${widget.id}/'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      Map<String, dynamic> data = {
        'date_of_birth': dateFormatter.format(selectedDate),
        'driving_license_exp_date': dateFormatter.format(selecteExp),
        'join_date': dateFormatter.format(selectejoin),
        'confirmation_date': dateFormatter.format(selecteconf),
        'termination_date': selectedTerminationDate != null
            ? dateFormatter.format(selectedTerminationDate!)
            : null,
        'is_manager': isManager,
        'allocated_states': allocated_states,
        'name': name.text,
        'username': username.text,
        'email': email.text,
        'phone': phone.text,
        'alternate_number': alternate_number.text,
        'designation': designation.text,
        'grade': grade.text,
        'paid_leaves': int.tryParse(paid_leaves.text.trim()) ?? 0,
        'address': address.text,
        'city': city.text,
        'country': Country.text,
        'country_code': selectedCountryId,
        'driving_license': driving_license.text,
        'department_id': selectedDepartmentId,
        'supervisor_id': selectedManagerId,
        'warehouse_id': selectedWarehouseId,
        'gender': selectgender,
        'marital_status': selectmarital,
        'employment_status': employment_status.text,
        'approval_status': approvalstatus,
        'family': selectedFamily.isNotEmpty ? selectedFamily[0] : null,
        'staff_id': staff_id.text,
        'emergency_contact_name': emergency_contact_name.text,
        'emergency_contact_number': emergency_contact_number.text,
        'experience': experience.text.trim(),
        'emergency_contact_name1': emergency_contact_name1.text.trim(),
        'emergency_contact_number1': emergency_contact_number1.text.trim(),
        'previous_company': previous_company.text,
        'blood_group': selectedBloodGroup ?? '',
        'education': education.text,
        'aadhar_no': aadhar_no.text,
        'pan_no': pan_no.text,
        'state': selectedPostingStateId,
        'place': place.text,
      };

      if (password.text.trim().isNotEmpty) {
        data['password'] = password.text.trim();
      }

      request.body = jsonEncode(data);

      debugPrint('========== UPDATE STAFF DATA ==========');
      debugPrint('URL: $api/api/staff/update/${widget.id}/');
      debugPrint('REQUEST BODY: ${jsonEncode(data)}');

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      debugPrint('STATUS CODE: ${responseData.statusCode}');
      debugPrint('RESPONSE: ${responseData.body}');
      debugPrint('=======================================');

      if (responseData.statusCode == 200) {
        final Map<String, dynamic> responseJson = jsonDecode(responseData.body);
        staffId = responseJson['data']['id'].toString();
        return true;
      } else if (responseData.statusCode == 400) {
        final Map<String, dynamic> responseJson = jsonDecode(responseData.body);

        if (!mounted) return false;

        if (responseJson['errors'] != null) {
          String errorMessage = responseJson['errors'].entries.map((e) {
            return "${e.key}: ${e.value.join(', ')}";
          }).join('\n');

          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        } else {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(content: Text(responseData.body)),
          );
        }
        return false;
      } else {
        if (!mounted) return false;
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Text(
              'Something went wrong. Status: ${responseData.statusCode}\n${responseData.body}',
            ),
          ),
        );
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('UPDATE STAFF DATA ERROR: $e');
      debugPrint('UPDATE STAFF DATA STACKTRACE: $stackTrace');

      if (!mounted) return false;
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      return false;
    }
  }

  void pickAadharImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        selectedAadharImage = File(result.files.single.path!);
      });
      debugPrint('SELECTED AADHAR IMAGE: ${selectedAadharImage?.path}');
    }
  }

  void pickPanImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        selectedPanImage = File(result.files.single.path!);
      });
      debugPrint('SELECTED PAN IMAGE: ${selectedPanImage?.path}');
    }
  }

  void removeAadharImage() {
    setState(() {
      selectedAadharImage = null;
      existingAadharImageUrl = null;
    });
  }

  void removePanImage() {
    setState(() {
      selectedPanImage = null;
      existingPanImageUrl = null;
    });
  }

  Future<bool> updateStaffFiles(BuildContext scaffoldContext) async {
    final token = await gettokenFromPrefs();

    try {
      if (selectedImage == null &&
          selectedSignature == null &&
          selectedExpLetter == null &&
          selectedSalarySlip == null &&
          selectedAadharImage == null &&
          selectedPanImage == null) {
        debugPrint('========== UPDATE STAFF FILES ==========');
        debugPrint('NO NEW FILES SELECTED. SKIPPING FILE UPLOAD.');
        debugPrint('========================================');
        return true;
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$api/api/staff/update/${widget.id}/'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', selectedImage!.path),
        );
      }

      if (selectedSignature != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'signatur_up',
            selectedSignature!.path,
          ),
        );
      }

      if (selectedExpLetter != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'exp_letter',
            selectedExpLetter!.path,
          ),
        );
      }

      if (selectedSalarySlip != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'salrary_slip',
            selectedSalarySlip!.path,
          ),
        );
      }

      if (selectedAadharImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'aadhar_image',
            selectedAadharImage!.path,
          ),
        );
      }

      if (selectedPanImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'pan_image',
            selectedPanImage!.path,
          ),
        );
      }

      debugPrint('========== UPDATE STAFF FILES ==========');
      debugPrint('URL: $api/api/staff/update/${widget.id}/');
      debugPrint('PROFILE IMAGE: ${selectedImage?.path}');
      debugPrint('SIGNATURE: ${selectedSignature?.path}');
      debugPrint('EXPERIENCE LETTER: ${selectedExpLetter?.path}');
      debugPrint('SALARY SLIP: ${selectedSalarySlip?.path}');
      debugPrint('AADHAR IMAGE: ${selectedAadharImage?.path}');
      debugPrint('PAN IMAGE: ${selectedPanImage?.path}');

      var streamedResponse = await request.send();
      var responseData = await http.Response.fromStream(streamedResponse);

      debugPrint('STATUS CODE: ${responseData.statusCode}');
      debugPrint('RESPONSE: ${responseData.body}');
      debugPrint('========================================');

      if (responseData.statusCode == 200) {
        return true;
      } else {
        if (!mounted) return false;
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Text(
              'File upload failed. Status: ${responseData.statusCode}\n${responseData.body}',
            ),
          ),
        );
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('UPDATE STAFF FILES ERROR: $e');
      debugPrint('UPDATE STAFF FILES STACKTRACE: $stackTrace');

      if (!mounted) return false;
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      return false;
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        onDateSelected(DateTime(picked.year, picked.month, picked.day));
      });
    }
  }

  void imageSelect() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null) {
        setState(() {
          selectedImage = File(result.files.single.path!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile image selected successfully."),
            backgroundColor: Color.fromARGB(173, 120, 249, 126),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error while selecting the file."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void imageSelect1() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null) {
        setState(() {
          selectedSignature = File(result.files.single.path!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Signature selected successfully."),
            backgroundColor: Color.fromARGB(173, 120, 249, 126),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error while selecting the file."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void pickExpLetter() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          selectedExpLetter = File(result.files.single.path!);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Experience letter selected successfully."),
            backgroundColor: Color.fromARGB(173, 120, 249, 126),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error while selecting experience letter."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void pickSalarySlip() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          selectedSalarySlip = File(result.files.single.path!);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Salary slip selected successfully."),
            backgroundColor: Color.fromARGB(173, 120, 249, 126),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error while selecting salary slip."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildImagePreview({
    required File? file,
    required String? networkPath,
    required VoidCallback onRemove,
  }) {
    if (file != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          InkWell(
            onTap: () {
              _showFullPreview(
                context: context,
                file: file,
                networkPath: null,
                isPdf: false,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      );
    }

    if (networkPath != null && networkPath.isNotEmpty) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          InkWell(
            onTap: () {
              _showFullPreview(
                context: context,
                file: null,
                networkPath: networkPath,
                isPdf: false,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '$api$networkPath',
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 110,
                    height: 110,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.red),
                  );
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      );
    }

    return const Text(
      "No Image Selected",
      style: TextStyle(color: Colors.black54),
    );
  }

  void removeImage() {
    setState(() {
      selectedImage = null;
      existingImageUrl = null;
    });
  }

  void removeSignatureImage() {
    setState(() {
      selectedSignature = null;
      existingSignatureUrl = null;
    });
  }

  void removeExpLetter() {
    setState(() {
      selectedExpLetter = null;
      existingExpLetterUrl = null;
    });
  }

  void removeSalarySlip() {
    setState(() {
      selectedSalarySlip = null;
      existingSalarySlipUrl = null;
    });
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      labelStyle: const TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBFD7FF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        readOnly: readOnly,
        decoration: _inputDecoration(label, icon: icon),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFD7FF)),
      ),
      child: child,
    );
  }

  Widget _buildDateField({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFD7FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('dd / MM / yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.date_range_outlined, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTile({
    required String title,
    required String fallbackText,
    required File? file,
    required String? existingUrl,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    String displayText = fallbackText;

    if (file != null) {
      displayText = file.path.split('/').last;
    } else if (existingUrl != null && existingUrl.isNotEmpty) {
      displayText = existingUrl.split('/').last;
    }

    final bool hasFile =
        file != null || (existingUrl != null && existingUrl.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFD7FF)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasFile ? Colors.black : Colors.black54,
                        fontWeight: hasFile ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Browse",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasFile) const SizedBox(height: 10),
          if (hasFile)
            _buildFilePreview(
              file: file,
              existingUrl: existingUrl,
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }

  Widget _buildFilePreview({
    required File? file,
    required String? existingUrl,
    required VoidCallback onRemove,
  }) {
    final String? path = file?.path ?? existingUrl;

    if (path == null || path.isEmpty) {
      return const SizedBox();
    }

    final bool isImage = _isImageFile(path);
    final bool isPdf = _isPdfFile(path);

    if (isImage) {
      return InkWell(
        onTap: () {
          _showFullPreview(
            context: context,
            file: file,
            networkPath: existingUrl,
            isPdf: false,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFD7FF)),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: file != null
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      existingUrl!.startsWith('http')
                          ? existingUrl
                          : '$api$existingUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.red,
                            size: 34,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.blue),
                        );
                      },
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isPdf) {
      return InkWell(
        onTap: () {
          _showFullPreview(
            context: context,
            file: file,
            networkPath: existingUrl,
            isPdf: true,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFD7FF)),
            color: const Color(0xFFF7FAFF),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  path.split('/').last,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onRemove,
                child: const Icon(Icons.close, color: Colors.red),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, color: Colors.blue),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFD7FF)),
        color: const Color(0xFFF7FAFF),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              path.split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFD7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          ...children,
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.blue,
        boxShadow: const [
          BoxShadow(
            color: Color(0x220000FF),
            blurRadius: 16,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Update Staff",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Edit employee profile, assignment details and upload updated documents.",
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableStaffSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 55),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFD7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Available Staff"),
          if (sta.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: const Center(
                child: Text(
                  "No staff available",
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              itemCount: sta.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const Divider(
                height: 18,
                color: Color(0xFFBFD7FF),
              ),
              itemBuilder: (context, i) {
                return Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${i + 1}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${sta[i]['name']}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${sta[i]['email'] ?? ''}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                Staff_Update(id: sta[i]['id']),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyDropdown() {
    if (fam.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _buildDropdownContainer(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedFamily.isEmpty ? null : selectedFamily[0],
        hint: const Text("Select Family"),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        onChanged: (int? newValue) {
          setState(() {
            if (newValue != null) {
              selectedFamily = [newValue];
            }
          });
        },
        items: fam.map<DropdownMenuItem<int>>((familyItem) {
          return DropdownMenuItem<int>(
            value: familyItem['id'],
            child: Text(familyItem['name']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStateSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Allocated States",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFD7FF)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                hint: const Text(
                  'Select State',
                  style: TextStyle(fontSize: 14),
                ),
                value: statess.isNotEmpty && selectstate != null
                    ? statess.firstWhere(
                        (element) => element['name'] == selectstate,
                        orElse: () => statess[0],
                      )
                    : null,
                items: statess.isNotEmpty
                    ? statess.map<DropdownMenuItem<Map<String, dynamic>>>(
                        (Map<String, dynamic> state) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: state,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  state['name'],
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (allocatedStateNames.contains(state['name']))
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                            ],
                          ),
                        );
                      }).toList()
                    : [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No states available'),
                        ),
                      ],
                onChanged: (Map<String, dynamic>? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectstate = newValue['name'];

                      if (!allocatedStateNames.contains(newValue['name'])) {
                        allocatedStateNames.add(newValue['name']);
                      }

                      allocated_states = allocatedStateNames
                          .map((stateName) => statess.firstWhere(
                                (element) => element['name'] == stateName,
                                orElse: () => {'id': 0},
                              )['id'] as int)
                          .toList();
                    });
                  }
                },
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          if (allocatedStateNames.isNotEmpty) const SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: allocatedStateNames.map((value) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFBFD7FF)),
                ),
                child: Chip(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  label: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.blue,
                  ),
                  onDeleted: () {
                    setState(() {
                      allocatedStateNames.remove(value);

                      allocated_states = allocatedStateNames
                          .map((stateName) => statess.firstWhere(
                                (element) => element['name'] == stateName,
                                orElse: () => {'id': 0},
                              )['id'] as int)
                          .toList();

                      if (allocatedStateNames.isEmpty) {
                        selectstate = null;
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Gender",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            child: DropdownButton<String>(
              value: selectgender,
              underline: const SizedBox(),
              isExpanded: true,
              icon:
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
              onChanged: (String? newValue) {
                setState(() {
                  selectgender = newValue!;
                });
              },
              items: genderList.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaritalDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Marital Status",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            child: DropdownButton<String>(
              value: selectmarital,
              underline: const SizedBox(),
              isExpanded: true,
              icon:
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
              onChanged: (String? newValue) {
                setState(() {
                  selectmarital = newValue!;
                });
              },
              items: maritalList.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Status",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            child: DropdownButton<String>(
              value: approvalstatus,
              underline: const SizedBox(),
              isExpanded: true,
              icon:
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
              onChanged: (String? newValue) {
                setState(() {
                  approvalstatus = newValue!;
                });
              },
              items: approvalList.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Blood Group",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedBloodGroup,
              hint: const Text('Select Blood Group'),
              underline: const SizedBox(),
              icon:
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
              onChanged: (String? newValue) {
                setState(() {
                  selectedBloodGroup = newValue;
                });
              },
              items: bloodGroups.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedDepartmentId,
        hint: const Text('Select Department'),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        onChanged: (int? newValue) {
          setState(() {
            selectedDepartmentId = newValue;
            selectedDepartmentName =
                dep.firstWhere((element) => element['id'] == newValue)['name'];
          });
        },
        items: dep.map<DropdownMenuItem<int>>((departmentItem) {
          return DropdownMenuItem<int>(
            value: departmentItem['id'],
            child: Text(departmentItem['name']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildManagerDropdown() {
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedManagerId,
        hint: const Text('Select Manager'),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        onChanged: (int? newValue) {
          setState(() {
            selectedManagerId = newValue;
            selectedManagerName = manager
                .firstWhere((element) => element['id'] == newValue)['name'];
          });
        },
        items: manager.map<DropdownMenuItem<int>>((managerItem) {
          return DropdownMenuItem<int>(
            value: managerItem['id'],
            child: Text(managerItem['name']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedWarehouseId,
        hint: const Text('Select Warehouse'),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        onChanged: (int? newValue) {
          setState(() {
            selectedWarehouseId = newValue;
            selectedWarehouseName = warehouses
                .firstWhere((element) => element['id'] == newValue)['name'];
          });
        },
        items: warehouses.map<DropdownMenuItem<int>>((warehouseItem) {
          return DropdownMenuItem<int>(
            value: warehouseItem['id'],
            child: Text(warehouseItem['name']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCountryCodeDropdown() {
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedCountryId,
        hint: const Text('Select Country Code'),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        onChanged: (int? newValue) {
          setState(() {
            selectedCountryId = newValue;
            selectedCountryName =
                country.firstWhere((c) => c['id'] == newValue)['country_code'];
          });
        },
        items: country.map<DropdownMenuItem<int>>((countryItem) {
          return DropdownMenuItem<int>(
            value: countryItem['id'],
            child: Text(countryItem['country_code']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPostingStateDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "State",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedPostingStateId,
              hint: const Text('Select State'),
              underline: const SizedBox(),
              icon:
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
              onChanged: (int? newValue) {
                setState(() {
                  selectedPostingStateId = newValue;
                });
              },
              items: statess.map<DropdownMenuItem<int>>((stateItem) {
                return DropdownMenuItem<int>(
                  value: stateItem['id'],
                  child: Text(stateItem['name']),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminationDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Last day of working",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFD7FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedTerminationDate != null
                        ? DateFormat('dd / MM / yyyy')
                            .format(selectedTerminationDate!)
                        : 'Select termination date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selectedTerminationDate != null
                          ? Colors.black
                          : Colors.black54,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _selectDate(
                    context,
                    selectedTerminationDate ?? DateTime.now(),
                    (picked) => selectedTerminationDate = picked,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.date_range_outlined, color: Colors.blue),
                  ),
                ),
                if (selectedTerminationDate != null)
                  InkWell(
                    onTap: () {
                      setState(() {
                        selectedTerminationDate = null;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close, color: Colors.red, size: 20),
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
  void dispose() {
    name.dispose();
    username.dispose();
    email.dispose();
    phone.dispose();
    alternate_number.dispose();
    password.dispose();
    driving_license.dispose();
    employment_status.dispose();
    designation.dispose();
    grade.dispose();
    paid_leaves.dispose();
    salary.dispose();
    incrementYear.dispose();
    incrementAmount.dispose();
    incrementRemarks.dispose();
    address.dispose();
    city.dispose();
    Country.dispose();
    staff_id.dispose();
    emergency_contact_name.dispose();
    emergency_contact_number.dispose();
    emergency_contact_name1.dispose();
    emergency_contact_number1.dispose();
    experience.dispose();
    previous_company.dispose();
    education.dispose();
    aadhar_no.dispose();
    pan_no.dispose();
    place.dispose();
    super.dispose();
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
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          centerTitle: true,
          title: const Text(
            "Update Staff",
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              _navigateBack();
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('lib/assets/profile.png'),
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
        body: isPageLoading
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (BuildContext scaffoldContext) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                        child: Column(
                          children: [
                            _buildHeaderCard(),
                            _buildSectionCard(
                              title: "Basic Information",
                              children: [
                                _buildTextField(name, 'Full Name',
                                    icon: Icons.person_outline),
                                _buildTextField(username, 'Username',
                                    icon: Icons.alternate_email),
                                _buildTextField(email, 'Email',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress),
                                _buildTextField(phone, 'Phone',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone),
                                _buildTextField(
                                  alternate_number,
                                  'Alternate Number',
                                  icon: Icons.phone_android_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                _buildTextField(
                                  password,
                                  'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: true,
                                ),
                                _buildTextField(
                                  staff_id,
                                  'Staff ID',
                                  icon: Icons.badge_outlined,
                                ),
                                _buildDateField(
                                  title: "Date of Birth",
                                  date: selectedDate,
                                  onTap: () => _selectDate(
                                    context,
                                    selectedDate,
                                    (picked) => selectedDate = picked,
                                  ),
                                ),
                                _buildGenderDropdown(),
                                _buildMaritalDropdown(),
                              ],
                            ),
                            _buildSectionCard(
                              title: "Work Assignment",
                              children: [
                                _buildDepartmentDropdown(),
                                _buildManagerDropdown(),
                                Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFBFD7FF)),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isManager,
                                        activeColor: Colors.blue,
                                        onChanged: (value) {
                                          setState(() {
                                            isManager = value ?? false;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          "Is Manager",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildWarehouseDropdown(),
                                _buildStateSelector(),
                                _buildFamilyDropdown(),
                                _buildTextField(
                                  employment_status,
                                  'Employment Status',
                                  icon: Icons.work_outline,
                                ),
                                _buildTextField(
                                  designation,
                                  'Designation',
                                  icon: Icons.assignment_ind_outlined,
                                ),
                                _buildTextField(
                                  grade,
                                  'Grade',
                                  icon: Icons.stacked_bar_chart_outlined,
                                ),
                                _buildTextField(
                                  paid_leaves,
                                  'Paid Leaves',
                                  icon: Icons.event_available_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                                _buildTextField(
                                  experience,
                                  'Experience',
                                  icon: Icons.timeline_outlined,
                                  keyboardType: TextInputType.text,
                                ),
                                _buildTextField(
                                  previous_company,
                                  'Previous Company',
                                  icon: Icons.business_outlined,
                                ),
                                _buildTextField(
                                  education,
                                  'Education',
                                  icon: Icons.school_outlined,
                                ),
                                _buildDateField(
                                  title: "Joining Date",
                                  date: selectejoin,
                                  onTap: () => _selectDate(
                                    context,
                                    selectejoin,
                                    (picked) => selectejoin = picked,
                                  ),
                                ),
                                _buildDateField(
                                  title: "Confirmation Date",
                                  date: selecteconf,
                                  onTap: () => _selectDate(
                                    context,
                                    selecteconf,
                                    (picked) => selecteconf = picked,
                                  ),
                                ),
                                _buildTerminationDateField(),
                                _buildApprovalDropdown(),
                              ],
                            ),
                            _buildSalarySection(),
                            _buildSectionCard(
                              title: "Emergency & Personal Details",
                              children: [
                                _buildTextField(
                                  emergency_contact_name,
                                  'Emergency Contact Name',
                                  icon: Icons.contact_phone_outlined,
                                ),
                                _buildTextField(
                                  emergency_contact_number,
                                  'Emergency Contact Number',
                                  icon: Icons.call_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                _buildTextField(
                                  emergency_contact_name1,
                                  'Emergency Contact Name 2',
                                  icon: Icons.contact_phone_outlined,
                                ),
                                _buildTextField(
                                  emergency_contact_number1,
                                  'Emergency Contact Number 2',
                                  icon: Icons.call_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                // _buildTextField(
                                //   experience,
                                //   'Experience',
                                //   icon: Icons.timeline_outlined,
                                //   keyboardType: TextInputType.text,
                                // ),
                                // _buildTextField(
                                //   previous_company,
                                //   'Previous Company',
                                //   icon: Icons.business_outlined,
                                // ),
                                // _buildTextField(
                                //   education,
                                //   'Education',
                                //   icon: Icons.school_outlined,
                                // ),
                                _buildBloodGroupDropdown(),
                                _buildTextField(
                                  aadhar_no,
                                  'Aadhar Number',
                                  icon: Icons.credit_card_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                                _buildTextField(
                                  pan_no,
                                  'PAN Number',
                                  icon: Icons.account_box_outlined,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                              ],
                            ),
                            // _buildSectionCard(
                            //   title: "License, Address & Country",
                            //   children: [
                            //     _buildTextField(
                            //       driving_license,
                            //       'Driving License',
                            //       icon: Icons.drive_eta_outlined,
                            //     ),
                            //     _buildDateField(
                            //       title: "License Expiry Date",
                            //       date: selecteExp,
                            //       onTap: () => _selectDate(
                            //         context,
                            //         selecteExp,
                            //         (picked) => selecteExp = picked,
                            //       ),
                            //     ),
                            //     _buildTextField(
                            //       address,
                            //       'Address',
                            //       icon: Icons.location_on_outlined,
                            //       maxLines: 3,
                            //     ),
                            //     _buildTextField(
                            //       city,
                            //       'City',
                            //       icon: Icons.location_city_outlined,
                            //     ),
                            //     _buildTextField(
                            //       Country,
                            //       'Country',
                            //       icon: Icons.public_outlined,
                            //     ),
                            //     _buildPostingStateDropdown(),
                            //     _buildTextField(
                            //       place,
                            //       'Place',
                            //       icon: Icons.place_outlined,
                            //     ),
                            //     _buildCountryCodeDropdown(),
                            //   ],
                            // ),
                            _buildSectionCard(
                              title: "Uploads",
                              children: [
                                _buildUploadTile(
                                  title: "Profile Image",
                                  fallbackText: "Select Profile Image",
                                  file: selectedImage,
                                  existingUrl: existingImageUrl,
                                  onTap: imageSelect,
                                  onRemove: removeImage,
                                ),
                                // _buildUploadTile(
                                //   title: "Signature",
                                //   fallbackText: "Select Signature",
                                //   file: selectedSignature,
                                //   existingUrl: existingSignatureUrl,
                                //   onTap: imageSelect1,
                                //   onRemove: removeSignatureImage,
                                // ),
                                _buildUploadTile(
                                  title: "Experience Letter",
                                  fallbackText: "Select Experience Letter",
                                  file: selectedExpLetter,
                                  existingUrl: existingExpLetterUrl,
                                  onTap: pickExpLetter,
                                  onRemove: removeExpLetter,
                                ),
                                // _buildUploadTile(
                                //   title: "Salary Slip",
                                //   fallbackText: "Select Salary Slip",
                                //   file: selectedSalarySlip,
                                //   existingUrl: existingSalarySlipUrl,
                                //   onTap: pickSalarySlip,
                                //   onRemove: removeSalarySlip,
                                // ),
                                _buildUploadTile(
                                  title: "Aadhar Image",
                                  fallbackText: "Select Aadhar Image",
                                  file: selectedAadharImage,
                                  existingUrl: existingAadharImageUrl,
                                  onTap: pickAadharImage,
                                  onRemove: () {
                                    setState(() {
                                      selectedAadharImage = null;
                                      existingAadharImageUrl = null;
                                    });
                                  },
                                ),
                                _buildUploadTile(
                                  title: "PAN Image",
                                  fallbackText: "Select PAN Image",
                                  file: selectedPanImage,
                                  existingUrl: existingPanImageUrl,
                                  onTap: pickPanImage,
                                  onRemove: () {
                                    setState(() {
                                      selectedPanImage = null;
                                      existingPanImageUrl = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      debugPrint('========== UPDATE STAFF BUTTON ==========');
                                      debugPrint('STAFF ID: ${widget.id}');
                                      debugPrint('DEPARTMENT ID: $selectedDepartmentId');
                                      debugPrint('MANAGER ID: $selectedManagerId');
                                      debugPrint('WAREHOUSE ID: $selectedWarehouseId');
                                      debugPrint('FAMILY: $selectedFamily');
                                      debugPrint('PAID LEAVES: ${paid_leaves.text}');
                                      debugPrint('ALLOCATED STATES: $allocated_states');
                                      debugPrint('=========================================');

                                      if (selectedDepartmentId == null) {
                                        ScaffoldMessenger.of(scaffoldContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                "Please select department"),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => isLoading = true);

                                      final bool dataUpdated =
                                          await registerUserData(
                                              scaffoldContext);

                                      if (dataUpdated) {
                                        final bool filesUpdated =
                                            await updateStaffFiles(
                                                scaffoldContext);

                                        if (filesUpdated && mounted) {
                                          ScaffoldMessenger.of(scaffoldContext)
                                              .showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.green,
                                              content: Text(
                                                  "Staff updated successfully"),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );

                                          await Future.delayed(
                                              const Duration(seconds: 1));

                                          if (mounted) {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const add_staff()),
                                            );
                                          }
                                        }
                                      }

                                      if (mounted) {
                                        setState(() => isLoading = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : const Text(
                                            "Update Staff",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            _buildAvailableStaffSection(),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
