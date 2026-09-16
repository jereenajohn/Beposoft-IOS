import 'dart:convert';
import 'dart:io';

import 'package:beposoft/Sales%20Directors/SD_dashboard.dart';
import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/update_Expense.dart';
import 'package:beposoft/pages/ACCOUNTS/update_staff.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/HR/hr_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:beposoft/pages/api.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class add_staff extends StatefulWidget {
  const add_staff({super.key});

  @override
  State<add_staff> createState() => _add_staffState();
}

class _add_staffState extends State<add_staff> {
  List<Map<String, dynamic>> statess = [];
  String staffId = '';

  List<bool> _checkboxValues = [];
  List<int> _selectedFamily = [];
  List<Map<String, dynamic>> fam = [];
  List<Map<String, dynamic>> Warehouses = [];
  int? selectedPostingStateId;

  DateTime? selecteLastWorking;

  File? selectedAadharImage;
  File? selectedPanImage;

  @override
  void initState() {
    super.initState();

    debugPrint('========== ADD STAFF PAGE INIT ==========');
    debugPrint('=========================================');

    getdepartments();
    getmanegers();
    getstaff();
    getwarehouse();
    getcountry();
    initdata();
  }

  void initdata() async {
    await getstates();
    getfamily();
  }

  var url = "$api/api/add/department/";
  String? selectstate;
  int? selectedStateId;
  List stat = [];
  List<int> dynamicStatid = [];

  TextEditingController name = TextEditingController();
  TextEditingController username = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController phone = TextEditingController();
  TextEditingController alternate_number = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController driving_license = TextEditingController();
  TextEditingController employment_status = TextEditingController();
  TextEditingController designation = TextEditingController();
  TextEditingController grade = TextEditingController();
  TextEditingController address = TextEditingController();
  TextEditingController city = TextEditingController();
  TextEditingController Country = TextEditingController();
  TextEditingController staff_id = TextEditingController();
  TextEditingController emergency_contact_name = TextEditingController();
  TextEditingController emergency_contact_number = TextEditingController();
  TextEditingController emergency_contact_name1 = TextEditingController();
  TextEditingController emergency_contact_number1 = TextEditingController();
  TextEditingController experience = TextEditingController();
  TextEditingController previous_company = TextEditingController();
  TextEditingController education = TextEditingController();
  TextEditingController aadhar_no = TextEditingController();
  TextEditingController pan_no = TextEditingController();
  TextEditingController place = TextEditingController();
  TextEditingController termination_date = TextEditingController();
  TextEditingController salary = TextEditingController();
  TextEditingController paid_leaves = TextEditingController();
  List<String> bloodGroups = [
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
  File? selectedExpLetter;
  File? selectedSalarySlip;

  Future<String?> gettokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    debugPrint(
      'AUTH TOKEN STATUS: ${token == null || token.isEmpty ? 'MISSING' : 'AVAILABLE'}',
    );

    return token;
  }

  List<String> gender = ["Female", 'Male', 'Other'];
  String selectgender = "Female";
  List<String> material = ["Married", 'Single', 'Other'];
  String selectmarital = "Single";
  List<String> approval = ["approved", 'disapproved'];
  String approvalstatus = "approved";

  DateTime selectedDate = DateTime.now();
  var date4;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month, picked.day);
        date4 = DateFormat('yyyy-MM-dd').format(selectedDate);
      });
    }
  }

  DateTime selecteExp = DateTime.now();
  DateTime selectejoin = DateTime.now();
  DateTime selecteconf = DateTime.now();

  var date3;
  Future<void> _selectDate2(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selecteExp,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selecteExp) {
      setState(() {
        selecteExp = DateTime(picked.year, picked.month, picked.day);
        date3 = DateFormat('yyyy-MM-dd').format(selecteExp);
      });
    }
  }

  var date1;
  Future<void> _selectDate3(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectejoin,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectejoin) {
      setState(() {
        selectejoin = DateTime(picked.year, picked.month, picked.day);
        date1 = DateFormat('yyyy-MM-dd').format(selectejoin);
      });
    }
  }

  var date2;
  Future<void> _selectDate4(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selecteconf,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selecteconf) {
      setState(() {
        selecteconf = DateTime(picked.year, picked.month, picked.day);
        date2 = DateFormat('yyyy-MM-dd').format(selecteconf);
      });
    }
  }

  Future<void> _selectLastWorkingDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selecteLastWorking ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        selecteLastWorking = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
        termination_date.text = DateFormat('yyyy-MM-dd').format(
          selecteLastWorking!,
        );
      });
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

        debugPrint('SELECTED EXPERIENCE LETTER: ${selectedExpLetter?.path}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Experience letter selected successfully."),
            backgroundColor: Color.fromARGB(173, 120, 249, 126),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

        debugPrint('SELECTED SALARY SLIP: ${selectedSalarySlip?.path}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Salary slip selected successfully."),
            backgroundColor: Color.fromARGB(173, 120, 249, 126),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error while selecting salary slip."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> country = [];

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
            'id': productData['id'],
            'country_code': productData['country_code'],
          });
        }
        setState(() {
          country = countrylist;
        });
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
            'id': productData['id'],
            'name': productData['name'],
            'location': productData['location']
          });
        }
        setState(() {
          Warehouses = warehouselist;
        });
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
            'id': productData['id'].toString(),
            'name': productData['name'],
          });
        }

        setState(() {
          fam = familylist;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('GET FAMILIES ERROR: $error');
      debugPrint('GET FAMILIES STACKTRACE: $stackTrace');
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
            'id': productData['id'],
            'name': productData['name'],
          });
        }
        setState(() {
          statess = stateslist;
          _checkboxValues = List<bool>.filled(statess.length, false);
        });
      }
    } catch (error, stackTrace) {
      debugPrint('GET STATES ERROR: $error');
      debugPrint('GET STATES STACKTRACE: $stackTrace');
    }
  }

  File? selectedImage;

  void imageSelect() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null) {
        setState(() {
          selectedImage = File(result.files.single.path!);
        });

        debugPrint('SELECTED PROFILE IMAGE: ${selectedImage?.path}');

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("image1 selected successfully."),
          backgroundColor: Color.fromARGB(173, 120, 249, 126),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error while selecting the file."),
        backgroundColor: Colors.red,
      ));
    }
  }

  File? selectedImage1;

  void imageSelect1() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null) {
        setState(() {
          selectedImage1 = File(result.files.single.path!);
        });

        debugPrint('SELECTED SIGNATURE IMAGE: ${selectedImage1?.path}');

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("image1 selected successfully."),
          backgroundColor: Color.fromARGB(173, 120, 249, 126),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error while selecting the file."),
        backgroundColor: Colors.red,
      ));
    }
  }

  var departments;
  List<Map<String, dynamic>> dep = [];
  List<Map<String, dynamic>> manager = [];

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
          String imageUrl = "${productData['image']}";
          departmentlist.add({
            'id': productData['id'],
            'name': productData['name'],
          });
        }
        setState(() {
          dep = departmentlist;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('GET DEPARTMENTS ERROR: $error');
      debugPrint('GET DEPARTMENTS STACKTRACE: $stackTrace');
    }
  }

  int? selectedCountryId;
  String? selectedCountryName;

  List<Map<String, dynamic>> sta = [];
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
          String imageUrl = "${productData['image']}";
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
    } catch (error, stackTrace) {
      debugPrint('GET STAFF LIST ERROR: $error');
      debugPrint('GET STAFF LIST STACKTRACE: $stackTrace');
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
          String imageUrl = "${productData['image']}";
          managerlist.add({
            'id': productData['id'],
            'name': productData['name'],
            'department_name': productData['department_name'],
          });
        }
        setState(() {
          manager = managerlist;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('GET SUPERVISORS ERROR: $error');
      debugPrint('GET SUPERVISORS STACKTRACE: $stackTrace');
    }
  }

  void pickAadharImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        setState(() {
          selectedAadharImage = File(result.files.single.path!);
        });

        debugPrint('SELECTED AADHAR IMAGE: ${selectedAadharImage?.path}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aadhar image selected successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error while selecting Aadhar image."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void pickPanImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        setState(() {
          selectedPanImage = File(result.files.single.path!);
        });

        debugPrint('SELECTED PAN IMAGE: ${selectedPanImage?.path}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PAN image selected successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error while selecting PAN image."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void addsupervisor(String name, BuildContext context) async {
    final token = await gettokenFromPrefs();

    try {
      final Map<String, String> supervisorBody = {
        "name": name,
        "department": selectedDepartmentId.toString(),
      };

      debugPrint('========== ADD SUPERVISOR ==========');
      debugPrint('URL: $api/api/add/supervisor/');
      debugPrint('REQUEST BODY: $supervisorBody');

      var response = await http.post(
        Uri.parse("$api/api/add/supervisor/"),
        headers: {
          'Authorization': '$token',
        },
        body: supervisorBody,
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('====================================');

      if (response.statusCode == 201) {
        var responseData = jsonDecode(response.body);

        Navigator.push(
            context, MaterialPageRoute(builder: (context) => add_staff()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromARGB(255, 49, 212, 4),
            content: Text('sucess'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('An error occurred. Please try again.'),
        ),
      );
    }
  }

  void removeProduct(int index) {
    setState(() {
      sta.removeAt(index);
    });
  }

  int? selectedmanagerId;
  int? selectedwarehouseId;

  String? selectedmanagerName;
  String? selectedwarehouseName;
  int? selectedDepartmentId;
  String? selectedDepartmentName;
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

  Future<String?> RegisterUserData(
    int selectedDepartmentId,
    DateTime selectedDate,
    String selectgender,
    String selectmarital,
    DateTime selecteExp,
    DateTime selectejoin,
    DateTime selecteconf,
    BuildContext scaffoldContext,
  ) async {
    final token = await gettokenFromPrefs();

    try {
      var request = http.Request(
        'POST',
        Uri.parse('$api/api/add/staff2/'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      Map<String, dynamic> data = {
        'date_of_birth': selectedDate.toIso8601String().substring(0, 10),
        'driving_license_exp_date':
            selecteExp.toIso8601String().substring(0, 10),
        'join_date': selectejoin.toIso8601String().substring(0, 10),
        'confirmation_date': selecteconf.toIso8601String().substring(0, 10),

        // THIS IS THE IMPORTANT PART
        'allocated_states': dynamicStatid,

        'name': name.text,
        'username': username.text,
        'email': email.text,
        'phone': phone.text,
        'password': password.text,
        'alternate_number': alternate_number.text,
        'designation': designation.text,
        'grade': grade.text,
        'address': address.text,
        'city': city.text,
        'country': Country.text,
        'country_code': selectedCountryId,
        'driving_license': driving_license.text,
        'department_id': selectedDepartmentId.toString(),
        'supervisor_id': selectedmanagerId?.toString(),
        'warehouse_id': selectedwarehouseId?.toString(),
        'gender': selectgender,
        'marital_status': selectmarital,
        'employment_status': employment_status.text,
        'approval_status': approvalstatus,
        'family': _selectedFamily.isNotEmpty ? _selectedFamily[0] : null,

        'staff_id': staff_id.text,
        'emergency_contact_name': emergency_contact_name.text,
        'emergency_contact_number': emergency_contact_number.text,
        'emergency_contact_name1': emergency_contact_name1.text.trim(),
        'emergency_contact_number1': emergency_contact_number1.text.trim(),
        'experience': experience.text.trim(),
        'termination_date': termination_date.text.trim(),
        'previous_company': previous_company.text,
        'blood_group': selectedBloodGroup ?? '',
        'education': education.text,
        'aadhar_no': aadhar_no.text,
        'pan_no': pan_no.text,
        'state': selectedPostingStateId,
        'place': place.text,
        'paid_leaves': int.tryParse(paid_leaves.text.trim()) ?? 0,
      };

      request.body = jsonEncode(data);

      debugPrint('========== CREATE STAFF ==========');
      debugPrint('URL: $api/api/add/staff2/');
      debugPrint('REQUEST BODY: ${jsonEncode(data)}');

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      debugPrint('STATUS CODE: ${responseData.statusCode}');
      debugPrint('RESPONSE: ${responseData.body}');
      debugPrint('==================================');

      if (responseData.statusCode == 201) {
        final Map<String, dynamic> responseJson = jsonDecode(responseData.body);
        final String newStaffId = responseJson['data']['id'].toString();
        staffId = newStaffId;

        debugPrint('========== STAFF CREATED ==========');
        debugPrint('STAFF ID: $newStaffId');
        debugPrint('RESPONSE: ${responseData.body}');
        debugPrint('===================================');

        return newStaffId;
      } else if (responseData.statusCode == 400) {
        final Map<String, dynamic> responseJson = jsonDecode(responseData.body);

        if (responseJson['errors'] != null) {
          String errorMessage = responseJson['errors'].entries.map((e) {
            final value = e.value;
            if (value is List) {
              return "${e.key}: ${value.join(', ')}";
            }
            return "${e.key}: $value";
          }).join('\n');

          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(errorMessage),
            ),
          );
        } else {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Validation failed. Please check your input.'),
            ),
          );
        }
        return null;
      } else {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Unable to create staff. Status: ${responseData.statusCode}\n${responseData.body}',
            ),
          ),
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('CREATE STAFF ERROR: $e');
      debugPrint('CREATE STAFF STACKTRACE: $stackTrace');
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: $e'),
        ),
      );
      return null;
    }
  }

  Future<bool> addStaffSalary({
    required String staffId,
    required int salaryAmount,
    required BuildContext scaffoldContext,
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

    try {
      final Map<String, dynamic> body = {
        'staff': int.parse(staffId),
        'salary': salaryAmount,
      };

      debugPrint('========== ADD STAFF SALARY ==========');
      debugPrint('URL: $api/api/staff/salary/');
      debugPrint('REQUEST: ${jsonEncode(body)}');
      debugPrint('STAFF ID: $staffId');
      debugPrint('SALARY AMOUNT: $salaryAmount');

      final response = await http.post(
        Uri.parse('$api/api/staff/salary/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('SALARY STATUS CODE: ${response.statusCode}');
      debugPrint('SALARY RESPONSE: ${response.body}');
      debugPrint('======================================');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      String message = 'Failed to add salary.';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message = decoded['message']?.toString() ??
              decoded['detail']?.toString() ??
              decoded['error']?.toString() ??
              'Failed to add salary.';
        }
      } catch (_) {
        message =
            'Failed to add salary. Status code: ${response.statusCode}';
      }

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
        ),
      );
      return false;
    } catch (e, stackTrace) {
      debugPrint('ADD SALARY ERROR: $e');
      debugPrint('ADD SALARY STACKTRACE: $stackTrace');
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Salary API error: $e'),
        ),
      );
      return false;
    }
  }

  bool isLoading = false;

  Future<void> updateStaffFiles(
    String staffId,
    File? image1,
    File? image2,
    File? expLetter,
    File? salarySlip,
    File? aadharImage,
    File? panImage,
    BuildContext scaffoldContext,
  ) async {
    final token = await gettokenFromPrefs();

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$api/api/staff/update/$staffId/'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (image1 != null) {
        request.files
            .add(await http.MultipartFile.fromPath('image', image1.path));
      }

      if (image2 != null) {
        request.files
            .add(await http.MultipartFile.fromPath('signatur_up', image2.path));
      }

      if (expLetter != null) {
        request.files.add(
            await http.MultipartFile.fromPath('exp_letter', expLetter.path));
      }

      if (salarySlip != null) {
        request.files.add(
            await http.MultipartFile.fromPath('salrary_slip', salarySlip.path));
      }

      if (aadharImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'aadhar_image', aadharImage.path));
      }

      if (panImage != null) {
        request.files
            .add(await http.MultipartFile.fromPath('pan_image', panImage.path));
      }

      debugPrint('========== UPDATE STAFF FILES ==========');
      debugPrint('URL: $api/api/staff/update/$staffId/');
      debugPrint('PROFILE IMAGE: ${image1?.path}');
      debugPrint('SIGNATURE IMAGE: ${image2?.path}');
      debugPrint('EXPERIENCE LETTER: ${expLetter?.path}');
      debugPrint('SALARY SLIP: ${salarySlip?.path}');
      debugPrint('AADHAR IMAGE: ${aadharImage?.path}');
      debugPrint('PAN IMAGE: ${panImage?.path}');

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('========================================');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Files Updated Successfully.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Text(
              'File upload failed. Status: ${response.statusCode}\n${response.body}',
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('UPDATE STAFF FILES ERROR: $e');
      debugPrint('UPDATE STAFF FILES STACKTRACE: $stackTrace');

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text('File upload error: $e')),
      );
    }
  }

  String? selectedValue;
  final TextEditingController textEditingController = TextEditingController();

  @override
  void dispose() {
    textEditingController.dispose();
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
    address.dispose();
    city.dispose();
    Country.dispose();
    staff_id.dispose();
    emergency_contact_name.dispose();
    emergency_contact_number.dispose();
    experience.dispose();
    previous_company.dispose();
    education.dispose();
    aadhar_no.dispose();
    pan_no.dispose();
    emergency_contact_name1.dispose();
    emergency_contact_number1.dispose();
    termination_date.dispose();
    salary.dispose();
    paid_leaves.dispose();

    place.dispose();
    super.dispose();
  }

  Widget _buildBloodGroupDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionMiniLabel("Blood Group"),
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

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  Future<void> _navigateBack() async {
    final dep = await getdepFromPrefs();
    if (dep == "BDO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => bdo_dashbord()),
      );
    } else if (dep == "SD") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                SdDashboard()), // Replace AnotherPage with your target page
      );
    } else if (dep == "BDM") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => bdm_dashbord()),
      );
    } else if (dep == "HR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HrDashboard()),
      );
    } else if (dep == "warehouse") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WarehouseDashboard()),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
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
          _sectionMiniLabel(title),
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

  Widget _buildOptionalLastWorkingDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionMiniLabel("Last day of working"),
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
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selecteLastWorking != null
                        ? DateFormat('dd / MM / yyyy')
                            .format(selecteLastWorking!)
                        : 'Select last working day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selecteLastWorking != null
                          ? Colors.black
                          : Colors.black54,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _selectLastWorkingDate(context),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.date_range_outlined,
                      color: Colors.blue,
                    ),
                  ),
                ),
                if (selecteLastWorking != null)
                  InkWell(
                    onTap: () {
                      setState(() {
                        selecteLastWorking = null;
                        termination_date.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
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

  Widget _sectionMiniLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildUploadTile({
    required String title,
    required String fallbackText,
    required File? file,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionMiniLabel(title),
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
                      file != null ? file.path.split('/').last : fallbackText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: file != null ? Colors.black : Colors.black54,
                        fontWeight:
                            file != null ? FontWeight.w600 : FontWeight.w500,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Add Staff",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Create employee profile, assign department, manager, warehouse and upload documents.",
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
                        Navigator.push(
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
      child: DropdownButton<String>(
        isExpanded: true,
        value: _selectedFamily.isEmpty ? null : _selectedFamily[0].toString(),
        hint: const Text("Select Family"),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        items: fam.map<DropdownMenuItem<String>>((family) {
          return DropdownMenuItem<String>(
            value: family['id'],
            child: Text(family['name']),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            if (newValue != null) {
              _selectedFamily = [int.parse(newValue)];
            }
          });

          debugPrint('SELECTED FAMILY: $_selectedFamily');
        },
      ),
    );
  }

  Widget _buildStateSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionMiniLabel("Allocated States"),
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
                              if (stat.contains(state['name']))
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
                      selectedStateId = newValue['id'];
                      if (!stat.contains(selectstate) &&
                          !dynamicStatid.contains(selectedStateId)) {
                        stat.add(selectstate!);
                        dynamicStatid.add(selectedStateId!);
                      } else {
                        stat.remove(selectstate!);
                        dynamicStatid.remove(selectedStateId);
                      }
                    });

                    debugPrint('ALLOCATED STATE NAMES: $stat');
                    debugPrint('ALLOCATED STATE IDS: $dynamicStatid');
                  }
                },
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.blue),
              ),
            ),
          ),
          if (stat.isNotEmpty) const SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: stat.map((value) {
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
                  deleteIcon:
                      const Icon(Icons.close, size: 18, color: Colors.blue),
                  onDeleted: () {
                    setState(() {
                      int index = stat.indexOf(value);
                      stat.removeAt(index);
                      dynamicStatid.removeAt(index);
                      if (stat.isEmpty) {
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

  Widget _buildGenderDropdown(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionMiniLabel("Gender"),
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
              items: gender.map<DropdownMenuItem<String>>((String value) {
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

  Widget _buildMaritalDropdown(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionMiniLabel("Marital Status"),
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
              items: material.map<DropdownMenuItem<String>>((String value) {
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

  Widget _buildApprovalDropdown(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionMiniLabel("Status"),
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
              items: approval.map<DropdownMenuItem<String>>((String value) {
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

          debugPrint(
            'SELECTED DEPARTMENT -> ID: $selectedDepartmentId | NAME: $selectedDepartmentName',
          );
        },
        items: dep.map<DropdownMenuItem<int>>((department) {
          return DropdownMenuItem<int>(
            value: department['id'],
            child: Text(department['name']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildManagerDropdown() {
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedmanagerId,
        hint: const Text('Select Manager'),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        onChanged: (int? newValue) {
          setState(() {
            selectedmanagerId = newValue;
            selectedmanagerName = manager
                .firstWhere((element) => element['id'] == newValue)['name'];
          });

          debugPrint(
            'SELECTED MANAGER -> ID: $selectedmanagerId | NAME: $selectedmanagerName',
          );
        },
        items: manager.map<DropdownMenuItem<int>>((manager) {
          return DropdownMenuItem<int>(
            value: manager['id'],
            child: Text(manager['name']),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedwarehouseId,
        hint: const Text('Select Warehouse'),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue),
        onChanged: (int? newValue) {
          setState(() {
            selectedwarehouseId = newValue;
            selectedwarehouseName = Warehouses.firstWhere(
                (element) => element['id'] == newValue)['name'];
          });

          debugPrint(
            'SELECTED WAREHOUSE -> ID: $selectedwarehouseId | NAME: $selectedwarehouseName',
          );
        },
        items: Warehouses.map<DropdownMenuItem<int>>((warehouse) {
          return DropdownMenuItem<int>(
            value: warehouse['id'],
            child: Text(warehouse['name']),
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
          _sectionMiniLabel("State"),
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
              items: statess.map<DropdownMenuItem<int>>((state) {
                return DropdownMenuItem<int>(
                  value: state['id'],
                  child: Text(state['name']),
                );
              }).toList(),
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
            "Add Staff",
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final dep = await getdepFromPrefs();
              if (dep == "BDO") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => bdo_dashbord()),
                );
              } else if (dep == "SD") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SdDashboard()), // Replace AnotherPage with your target page
                );
              } else if (dep == "BDM") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => bdm_dashbord()),
                );
              } else if (dep == "HR") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HrDashboard()),
                );
              } else if (dep == "warehouse") {
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
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => dashboard()),
                );
              }
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
        body: Builder(
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
                          _buildTextField(alternate_number, 'Alternate Number',
                              icon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone),
                          _buildTextField(password, 'Password',
                              icon: Icons.lock_outline, obscureText: true),
                          _buildTextField(staff_id, 'Staff ID',
                              icon: Icons.badge_outlined),
                          _buildDateField(
                            title: "Date of Birth",
                            date: selectedDate,
                            onTap: () => _selectDate(context),
                          ),
                          _buildGenderDropdown(constraints),
                          _buildMaritalDropdown(constraints),
                        ],
                      ),
                      _buildSectionCard(
                        title: "Work Assignment",
                        children: [
                          _buildDepartmentDropdown(),
                          _buildManagerDropdown(),
                          _buildWarehouseDropdown(),
                          _buildStateSelector(),
                          _buildFamilyDropdown(),
                          _buildTextField(
                              employment_status, 'Employment Status',
                              icon: Icons.work_outline),
                          _buildTextField(designation, 'Designation',
                              icon: Icons.assignment_ind_outlined),
                          _buildTextField(grade, 'Grade',
                              icon: Icons.stacked_bar_chart_outlined),
                          _buildTextField(
                            salary,
                            'Salary',
                            icon: Icons.currency_rupee_rounded,
                            keyboardType: TextInputType.number,
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
                          _buildTextField(previous_company, 'Previous Company',
                              icon: Icons.business_outlined),
                          _buildTextField(education, 'Education',
                              icon: Icons.school_outlined),
                          _buildDateField(
                            title: "Joining Date",
                            date: selectejoin,
                            onTap: () => _selectDate3(context),
                          ),
                          _buildDateField(
                            title: "Confirmation Date",
                            date: selecteconf,
                            onTap: () => _selectDate4(context),
                          ),
                          _buildOptionalLastWorkingDateField(),
                          _buildApprovalDropdown(constraints),
                        ],
                      ),
                      _buildSectionCard(
                        title: "Emergency & Personal Details",
                        children: [
                          _buildTextField(
                              emergency_contact_name, 'Emergency Contact Name',
                              icon: Icons.contact_phone_outlined),
                          _buildTextField(emergency_contact_number,
                              'Emergency Contact Number',
                              icon: Icons.call_outlined,
                              keyboardType: TextInputType.phone),
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
                          // _buildTextField(previous_company, 'Previous Company',
                          //     icon: Icons.business_outlined),
                          // _buildTextField(education, 'Education',
                          //     icon: Icons.school_outlined),
                          _buildBloodGroupDropdown(),
                          // _buildTextField(aadhar_no, 'Aadhar Number',
                          //     icon: Icons.credit_card_outlined,
                          //     keyboardType: TextInputType.number),
                          // _buildTextField(pan_no, 'PAN Number',
                          //     icon: Icons.account_box_outlined,
                          //     textCapitalization:
                          //         TextCapitalization.characters),
                        ],
                      ),
                      // _buildSectionCard(
                      //   title: "License, Address & Country",
                      //   children: [
                      //     _buildTextField(driving_license, 'Driving License',
                      //         icon: Icons.drive_eta_outlined),
                      //     _buildDateField(
                      //       title: "License Expiry Date",
                      //       date: selecteExp,
                      //       onTap: () => _selectDate2(context),
                      //     ),
                      //     _buildTextField(address, 'Address',
                      //         icon: Icons.location_on_outlined, maxLines: 3),
                      //     _buildTextField(city, 'City',
                      //         icon: Icons.location_city_outlined),
                      //     _buildTextField(Country, 'Country',
                      //         icon: Icons.public_outlined),
                      //     _buildPostingStateDropdown(),
                      //     _buildTextField(place, 'Place',
                      //         icon: Icons.place_outlined),
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
                            onTap: imageSelect,
                          ),
                          // _buildUploadTile(
                          //   title: "Signature",
                          //   fallbackText: "Select Signature",
                          //   file: selectedImage1,
                          //   onTap: imageSelect1,
                          // ),
                          _buildUploadTile(
                            title: "Experience Letter",
                            fallbackText: "Select Experience Letter",
                            file: selectedExpLetter,
                            onTap: pickExpLetter,
                          ),
                          // _buildUploadTile(
                          //   title: "Salary Slip",
                          //   fallbackText: "Select Salary Slip",
                          //   file: selectedSalarySlip,
                          //   onTap: pickSalarySlip,
                          // ),
                          _buildUploadTile(
                            title: "Aadhar Image",
                            fallbackText: "Select Aadhar Image",
                            file: selectedAadharImage,
                            onTap: pickAadharImage,
                          ),
                          _buildUploadTile(
                            title: "PAN Image",
                            fallbackText: "Select PAN Image",
                            file: selectedPanImage,
                            onTap: pickPanImage,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      debugPrint('========== ADD STAFF SUBMIT ==========');
                                      debugPrint('NAME: ${name.text}');
                                      debugPrint('USERNAME: ${username.text}');
                                      debugPrint('EMAIL: ${email.text}');
                                      debugPrint('PHONE: ${phone.text}');
                                      debugPrint('DEPARTMENT ID: $selectedDepartmentId');
                                      debugPrint('MANAGER ID: $selectedmanagerId');
                                      debugPrint('WAREHOUSE ID: $selectedwarehouseId');
                                      debugPrint('FAMILY: $_selectedFamily');
                                      debugPrint('ALLOCATED STATES: $dynamicStatid');
                                      debugPrint('SALARY INPUT: ${salary.text}');
                                      debugPrint('PAID LEAVES INPUT: ${paid_leaves.text}');
                                      debugPrint('======================================');

                                      if (selectedDepartmentId == null) {
                                        ScaffoldMessenger.of(scaffoldContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(
                                              'Please select department.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (name.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(scaffoldContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(
                                              'Please enter staff name.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (salary.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(scaffoldContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(
                                              'Please enter salary.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final int? salaryAmount =
                                          int.tryParse(salary.text.trim());

                                      if (salaryAmount == null ||
                                          salaryAmount <= 0) {
                                        ScaffoldMessenger.of(scaffoldContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(
                                              'Please enter a valid salary.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => isLoading = true);

                                      try {
                                        final String? newStaffId =
                                            await RegisterUserData(
                                          selectedDepartmentId!,
                                          selectedDate,
                                          selectgender,
                                          selectmarital,
                                          selecteExp,
                                          selectejoin,
                                          selecteconf,
                                          scaffoldContext,
                                        );

                                        if (newStaffId == null ||
                                            newStaffId.isEmpty) {
                                          return;
                                        }

                                        final bool salaryAdded =
                                            await addStaffSalary(
                                          staffId: newStaffId,
                                          salaryAmount: salaryAmount,
                                          scaffoldContext: scaffoldContext,
                                        );

                                        if (!salaryAdded) {
                                          ScaffoldMessenger.of(scaffoldContext)
                                              .showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.orange,
                                              content: Text(
                                                'Staff created, but salary could not be added.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final bool hasFiles =
                                            selectedImage != null ||
                                                selectedImage1 != null ||
                                                selectedExpLetter != null ||
                                                selectedSalarySlip != null ||
                                                selectedAadharImage != null ||
                                                selectedPanImage != null;

                                        if (hasFiles) {
                                          await updateStaffFiles(
                                            newStaffId,
                                            selectedImage,
                                            selectedImage1,
                                            selectedExpLetter,
                                            selectedSalarySlip,
                                            selectedAadharImage,
                                            selectedPanImage,
                                            scaffoldContext,
                                          );
                                        }

                                        if (!mounted) return;

                                        ScaffoldMessenger.of(scaffoldContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            backgroundColor: Colors.green,
                                            content: Text(
                                              'Staff and salary added successfully.',
                                            ),
                                          ),
                                        );

                                        Navigator.pushReplacement(
                                          scaffoldContext,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const add_staff(),
                                          ),
                                        );
                                      } catch (e, stackTrace) {
                                        debugPrint('SUBMIT ERROR: $e');
                                        debugPrint(
                                          'SUBMIT STACKTRACE: $stackTrace',
                                        );

                                        if (!mounted) return;

                                        ScaffoldMessenger.of(scaffoldContext)
                                            .showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(
                                              'Something went wrong: $e',
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => isLoading = false);
                                        }
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
                                      "Submit",
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
