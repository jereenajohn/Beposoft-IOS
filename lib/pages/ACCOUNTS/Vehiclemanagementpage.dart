import 'dart:convert';
import 'dart:typed_data';

import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleKmManagementPage extends StatefulWidget {
  const VehicleKmManagementPage({super.key});

  @override
  State<VehicleKmManagementPage> createState() =>
      _VehicleKmManagementPageState();
}

class _VehicleKmManagementPageState extends State<VehicleKmManagementPage> {
  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  final TextEditingController vehicleNameController =
      TextEditingController();

  final TextEditingController registrationNumberController =
      TextEditingController();

  final TextEditingController vehicleModelController =
      TextEditingController();

  final TextEditingController startingKmController =
      TextEditingController();

  final TextEditingController endKmController =
      TextEditingController();

  final TextEditingController usedKmController =
      TextEditingController();

  final TextEditingController petrolController =
      TextEditingController();

  final TextEditingController vehicleSearchController =
      TextEditingController();

  final TextEditingController kmSearchController =
      TextEditingController();

  final TextEditingController serviceTypeController =
      TextEditingController();

  final TextEditingController serviceCenterController =
      TextEditingController();

  final TextEditingController serviceOdometerController =
      TextEditingController();

  final TextEditingController serviceCostController =
      TextEditingController();

  final TextEditingController serviceDescriptionController =
      TextEditingController();

  final TextEditingController serviceSearchController =
      TextEditingController();

  // ===========================================================================
  // DATA
  // ===========================================================================

  List<Map<String, dynamic>> vehicles = [];
  List<Map<String, dynamic>> kmEntries = [];

  List<Map<String, dynamic>> filteredVehicles = [];
  List<Map<String, dynamic>> filteredKmEntries = [];

  List<Map<String, dynamic>> serviceHistory = [];
  List<Map<String, dynamic>> filteredServiceHistory = [];

  Map<String, dynamic> kmSummary = {};
  List<Map<String, dynamic>> kmVehicleSummary = [];

  int kmTotalCount = 0;
  String? kmNextUrl;
  String? kmPreviousUrl;
  int kmCurrentPage = 1;

  // ===========================================================================
  // PAGE STATE
  // ===========================================================================

  bool isVehicleLoading = true;
  bool isKmLoading = true;
  bool isKmPageLoading = false;
  bool isServiceLoading = true;

  bool isVehicleSubmitting = false;
  bool isKmSubmitting = false;
  bool isServiceSubmitting = false;

  int selectedTab = 0;

  int? selectedVehicleId;
  int? editingVehicleId;
  int? editingKmEntryId;

  int? selectedServiceVehicleId;
  int? editingServiceHistoryId;

  DateTime selectedDate = DateTime.now();
  DateTime? selectedServiceDate;
  DateTime? selectedNextServiceDate;

  final ImagePicker _imagePicker = ImagePicker();
  XFile? selectedVehicleImage;
  Uint8List? selectedVehicleImageBytes;
  String existingVehicleImageUrl = '';

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    getVehicles();
    getKmEntries();
    getServiceHistory();

    startingKmController.addListener(calculateUsedKm);
    endKmController.addListener(calculateUsedKm);
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    vehicleNameController.dispose();
    registrationNumberController.dispose();
    vehicleModelController.dispose();

    startingKmController.removeListener(calculateUsedKm);
    endKmController.removeListener(calculateUsedKm);

    startingKmController.dispose();
    endKmController.dispose();
    usedKmController.dispose();
    petrolController.dispose();

    vehicleSearchController.dispose();
    kmSearchController.dispose();

    serviceTypeController.dispose();
    serviceCenterController.dispose();
    serviceOdometerController.dispose();
    serviceCostController.dispose();
    serviceDescriptionController.dispose();
    serviceSearchController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // SHARED PREFERENCES
  // ===========================================================================

  Future<String?> gettokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  String buildMediaUrl(dynamic value) {
    dynamic rawValue = value;

    if (rawValue is Map) {
      rawValue = rawValue['image'] ??
          rawValue['url'] ??
          rawValue['file'] ??
          rawValue['path'];
    }

    final String path = rawValue?.toString().trim() ?? '';

    if (path.isEmpty || path.toLowerCase() == 'null') {
      return '';
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final String base = api.endsWith('/')
        ? api.substring(0, api.length - 1)
        : api;

    if (path.startsWith('/')) {
      return '$base$path';
    }

    return '$base/$path';
  }

  String getCreatedByName(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is Map) {
      return value['name']?.toString() ??
          value['username']?.toString() ??
          value['email']?.toString() ??
          value['id']?.toString() ??
          '';
    }

    return value.toString();
  }

  String formatDateTimeValue(dynamic value) {
    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return '';
    }

    final DateTime? parsed = DateTime.tryParse(text);

    if (parsed == null) {
      return text;
    }

    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  Future<Uint8List> _readImageBytes(XFile image) async {
    return await image.readAsBytes();
  }

  MediaType _resolveImageMediaType(XFile image) {
    final String extension =
        image.path.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
      case 'heif':
        return MediaType('image', 'heic');
      case 'jpeg':
      case 'jpg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<void> pickVehicleImage(
    StateSetter setModalState,
  ) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) {
        return;
      }

      final Uint8List bytes = await _readImageBytes(
        picked,
      );

      const int maxSize = 5 * 1024 * 1024;

      if (bytes.lengthInBytes > maxSize) {
        showErrorSnackBar(
          'Image size must be 5 MB or less.',
        );
        return;
      }

      debugPrint(
        '================ VEHICLE IMAGE SELECTED ================',
      );
      debugPrint(
        'VEHICLE IMAGE PATH: ${picked.path}',
      );
      debugPrint(
        'VEHICLE IMAGE NAME: ${picked.name}',
      );
      debugPrint(
        'VEHICLE IMAGE SIZE BYTES: ${bytes.lengthInBytes}',
      );
      debugPrint(
        'VEHICLE IMAGE MIME TYPE: ${_resolveImageMediaType(picked)}',
      );
      debugPrint(
        '=======================================================',
      );

      setModalState(() {
        selectedVehicleImage = picked;
        selectedVehicleImageBytes = bytes;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'PICK VEHICLE IMAGE ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      showErrorSnackBar(
        'Unable to select image. Please try again.',
      );
    }
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

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
    } else if (dep == "warehouse") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WarehouseDashboard(),
        ),
      );
    } else if (dep == "Warehouse Admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WarehouseAdmin(),
        ),
      );
    } else if (dep == "CEO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ceo_dashboard(),
        ),
      );
    } else if (dep == "COO") {
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
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => dashboard(),
        ),
      );
    }
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove('userId');
    await prefs.remove('token');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully'),
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => login(),
      ),
    );
  }

  // ===========================================================================
  // API ERROR MESSAGE
  // ===========================================================================

  String getApiErrorMessage(http.Response response) {
    try {
      final parsed = jsonDecode(response.body);

      if (parsed is Map<String, dynamic>) {
        if (parsed['message'] != null) {
          return parsed['message'].toString();
        }

        if (parsed['detail'] != null) {
          return parsed['detail'].toString();
        }

        if (parsed['error'] != null) {
          return parsed['error'].toString();
        }

        List<String> errors = [];

        parsed.forEach((key, value) {
          if (value is List) {
            errors.add('$key: ${value.join(", ")}');
          } else if (value != null) {
            errors.add('$key: $value');
          }
        });

        if (errors.isNotEmpty) {
          return errors.join('\n');
        }
      }
    } catch (e) {
      // Ignore parsing error.
    }

    return 'Request failed. Status code: ${response.statusCode}';
  }

  // ===========================================================================
  // GET VEHICLES
  //
  // API:
  // GET api/vehicles/
  // ===========================================================================

  Future<void> getVehicles() async {
    if (!mounted) return;

    setState(() {
      isVehicleLoading = true;
    });

    try {
      final token = await gettokenFromPrefs();

      final String url = '$api/api/vehicles/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      debugPrint(
        '================ GET VEHICLES REQUEST ================',
      );
      debugPrint(
        'GET VEHICLES URL: $url',
      );
      debugPrint(
        'GET VEHICLES HEADERS: $headers',
      );

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint(
        '================ GET VEHICLES RESPONSE ================',
      );
      debugPrint(
        'GET VEHICLES STATUS: ${response.statusCode}',
      );
      debugPrint(
        'GET VEHICLES HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'GET VEHICLES BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);

        List<dynamic> vehicleData = [];

        if (parsed is List) {
          vehicleData = parsed;
        } else if (parsed is Map<String, dynamic>) {
          if (parsed['results'] is List) {
            vehicleData = parsed['results'];
          } else if (parsed['data'] is List) {
            vehicleData = parsed['data'];
          } else if (parsed['vehicles'] is List) {
            vehicleData = parsed['vehicles'];
          }
        }

        List<Map<String, dynamic>> vehicleList = [];

        for (var item in vehicleData) {
          if (item is Map<String, dynamic>) {
            vehicleList.add({
              'id': item['id'],
              'name': item['name']?.toString() ?? '',
              'registration_number':
                  item['registration_number']?.toString() ?? '',
              'model': item['model']?.toString() ?? '',
              'image': buildMediaUrl(item['image']),
              'created_by': getCreatedByName(item['created_by']),
              'created_at': item['created_at']?.toString() ?? '',
              'updated_at': item['updated_at']?.toString() ?? '',
            });
          }
        }

        vehicleList.sort(
          (a, b) => a['name']
              .toString()
              .toLowerCase()
              .compareTo(
                b['name'].toString().toLowerCase(),
              ),
        );

        if (!mounted) return;

        setState(() {
          vehicles = vehicleList;
          filteredVehicles = vehicleList;
          isVehicleLoading = false;

          if (selectedVehicleId != null) {
            bool vehicleExists = vehicles.any(
              (item) => item['id'] == selectedVehicleId,
            );

            if (!vehicleExists) {
              selectedVehicleId = null;
            }
          }
        });
      } else {
        if (!mounted) return;

        setState(() {
          isVehicleLoading = false;
        });

        showErrorSnackBar(
          getApiErrorMessage(response),
        );
      }
    } catch (error) {
      debugPrint(
        'GET VEHICLES ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        isVehicleLoading = false;
      });

      showErrorSnackBar(
        'Unable to load vehicles. Please try again.',
      );
    }
  }

  // ===========================================================================
  // GET SINGLE VEHICLE
  //
  // API:
  // GET api/vehicles/<pk>/
  //
  // Used before editing so that the latest vehicle image and details
  // are loaded from the backend.
  // ===========================================================================

  Future<Map<String, dynamic>?> getVehicleDetail(
    int vehicleId,
  ) async {
    try {
      final String? token = await gettokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        showErrorSnackBar(
          'Authentication token not found.',
        );
        return null;
      }

      final String url =
          '$api/api/vehicles/$vehicleId/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      debugPrint(
        '============= GET VEHICLE DETAIL REQUEST =============',
      );
      debugPrint(
        'GET VEHICLE DETAIL URL: $url',
      );
      debugPrint(
        'GET VEHICLE DETAIL HEADERS: $headers',
      );

      final http.Response response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint(
        '============= GET VEHICLE DETAIL RESPONSE ============',
      );
      debugPrint(
        'GET VEHICLE DETAIL STATUS: ${response.statusCode}',
      );
      debugPrint(
        'GET VEHICLE DETAIL HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'GET VEHICLE DETAIL BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode != 200) {
        showErrorSnackBar(
          getApiErrorMessage(response),
        );
        return null;
      }

      final dynamic parsed = jsonDecode(
        response.body,
      );

      Map<String, dynamic>? rawVehicle;

      if (parsed is Map<String, dynamic>) {
        if (parsed['data'] is Map) {
          rawVehicle = Map<String, dynamic>.from(
            parsed['data'],
          );
        } else if (parsed['vehicle'] is Map) {
          rawVehicle = Map<String, dynamic>.from(
            parsed['vehicle'],
          );
        } else {
          rawVehicle = Map<String, dynamic>.from(
            parsed,
          );
        }
      }

      if (rawVehicle == null) {
        showErrorSnackBar(
          'Unable to load vehicle details.',
        );
        return null;
      }

      return {
        'id': rawVehicle['id'],
        'name': rawVehicle['name']?.toString() ?? '',
        'registration_number':
            rawVehicle['registration_number']?.toString() ?? '',
        'model': rawVehicle['model']?.toString() ?? '',
        'image': buildMediaUrl(
          rawVehicle['image'],
        ),
        'created_by': getCreatedByName(
          rawVehicle['created_by'],
        ),
        'created_at':
            rawVehicle['created_at']?.toString() ?? '',
        'updated_at':
            rawVehicle['updated_at']?.toString() ?? '',
      };
    } catch (error, stackTrace) {
      debugPrint(
        'GET VEHICLE DETAIL ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      showErrorSnackBar(
        'Unable to load vehicle details. Please try again.',
      );

      return null;
    }
  }

  // ===========================================================================
  // ADD VEHICLE
  //
  // API:
  // POST api/vehicles/
  //
  // fields:
  // name
  // registration_number
  // model
  // image
  // ===========================================================================

  Future<bool> addVehicle() async {
    final String name = vehicleNameController.text.trim();
    final String registration =
        registrationNumberController.text.trim().toUpperCase();
    final String model = vehicleModelController.text.trim();

    if (name.isEmpty &&
        registration.isEmpty &&
        model.isEmpty &&
        selectedVehicleImage == null) {
      showErrorSnackBar(
        'Please enter at least one vehicle detail.',
      );
      return false;
    }

    if (isVehicleSubmitting) {
      return false;
    }

    if (mounted) {
      setState(() {
        isVehicleSubmitting = true;
      });
    }

    try {
      final String? token = await gettokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found.',
        );
      }

      final String url = '$api/api/vehicles/';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(url),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields.addAll({
        'name': name,
        'registration_number': registration,
        'model': model,
      });

      debugPrint(
        '================ ADD VEHICLE REQUEST ==================',
      );
      debugPrint(
        'ADD VEHICLE URL: $url',
      );
      debugPrint(
        'ADD VEHICLE METHOD: POST',
      );
      debugPrint(
        'ADD VEHICLE HEADERS: ${request.headers}',
      );
      debugPrint(
        'ADD VEHICLE FIELDS: ${request.fields}',
      );

      if (selectedVehicleImage != null) {
        final XFile image = selectedVehicleImage!;
        final Uint8List bytes =
            selectedVehicleImageBytes ??
                await _readImageBytes(image);

        final String extension =
            image.path.split('.').last.toLowerCase();

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename:
                'vehicle_${DateTime.now().millisecondsSinceEpoch}.$extension',
            contentType: _resolveImageMediaType(image),
          ),
        );
      }

      debugPrint(
        'ADD VEHICLE FILES COUNT: ${request.files.length}',
      );

      for (final file in request.files) {
        debugPrint(
          'ADD VEHICLE FILE: '
          'field=${file.field}, '
          'filename=${file.filename}, '
          'length=${file.length}, '
          'contentType=${file.contentType}',
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint(
        '================ ADD VEHICLE RESPONSE =================',
      );
      debugPrint(
        'ADD VEHICLE STATUS: ${response.statusCode}',
      );
      debugPrint(
        'ADD VEHICLE HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'ADD VEHICLE BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        clearVehicleForm();

        await getVehicles();

        if (!mounted) return true;

        setState(() {
          isVehicleSubmitting = false;
        });

        showSuccessSnackBar(
          'Vehicle added successfully',
        );

        return true;
      } else {
        if (!mounted) return false;

        setState(() {
          isVehicleSubmitting = false;
        });

        showErrorSnackBar(
          getApiErrorMessage(response),
        );

        return false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'ADD VEHICLE ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return false;

      setState(() {
        isVehicleSubmitting = false;
      });

      showErrorSnackBar(
        error.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    }
  }

  // ===========================================================================
  // UPDATE VEHICLE
  //
  // API:
  // PUT api/vehicles/<pk>/
  // ===========================================================================

  Future<bool> updateVehicle() async {
    if (editingVehicleId == null) {
      return false;
    }

    final String name = vehicleNameController.text.trim();
    final String registration =
        registrationNumberController.text.trim().toUpperCase();
    final String model = vehicleModelController.text.trim();

    if (name.isEmpty &&
        registration.isEmpty &&
        model.isEmpty &&
        selectedVehicleImage == null &&
        existingVehicleImageUrl.isEmpty) {
      showErrorSnackBar(
        'Please enter at least one vehicle detail.',
      );
      return false;
    }

    if (isVehicleSubmitting) {
      return false;
    }

    if (mounted) {
      setState(() {
        isVehicleSubmitting = true;
      });
    }

    try {
      final String? token = await gettokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found.',
        );
      }

      final String url =
          '$api/api/vehicles/$editingVehicleId/';

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(url),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields.addAll({
        'name': name,
        'registration_number': registration,
        'model': model,
      });

      debugPrint(
        '=============== UPDATE VEHICLE REQUEST ================',
      );
      debugPrint(
        'UPDATE VEHICLE URL: $url',
      );
      debugPrint(
        'UPDATE VEHICLE METHOD: PUT',
      );
      debugPrint(
        'UPDATE VEHICLE HEADERS: ${request.headers}',
      );
      debugPrint(
        'UPDATE VEHICLE FIELDS: ${request.fields}',
      );
      debugPrint(
        'UPDATE VEHICLE EXISTING IMAGE URL: '
        '$existingVehicleImageUrl',
      );

      if (selectedVehicleImage != null) {
        final XFile image = selectedVehicleImage!;
        final Uint8List bytes =
            selectedVehicleImageBytes ??
                await _readImageBytes(image);

        final String extension =
            image.path.split('.').last.toLowerCase();

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename:
                'vehicle_${DateTime.now().millisecondsSinceEpoch}.$extension',
            contentType: _resolveImageMediaType(image),
          ),
        );
      }

      debugPrint(
        'UPDATE VEHICLE FILES COUNT: ${request.files.length}',
      );

      for (final file in request.files) {
        debugPrint(
          'UPDATE VEHICLE FILE: '
          'field=${file.field}, '
          'filename=${file.filename}, '
          'length=${file.length}, '
          'contentType=${file.contentType}',
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint(
        '=============== UPDATE VEHICLE RESPONSE ===============',
      );
      debugPrint(
        'UPDATE VEHICLE STATUS: ${response.statusCode}',
      );
      debugPrint(
        'UPDATE VEHICLE HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'UPDATE VEHICLE BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 202) {
        clearVehicleForm();

        await getVehicles();
        await getKmEntries();

        if (!mounted) return true;

        setState(() {
          isVehicleSubmitting = false;
        });

        showSuccessSnackBar(
          'Vehicle updated successfully',
        );

        return true;
      } else {
        if (!mounted) return false;

        setState(() {
          isVehicleSubmitting = false;
        });

        showErrorSnackBar(
          getApiErrorMessage(response),
        );

        return false;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'UPDATE VEHICLE ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return false;

      setState(() {
        isVehicleSubmitting = false;
      });

      showErrorSnackBar(
        error.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    }
  }

  // ===========================================================================
  // GET KM ENTRIES
  //
  // API:
  // GET api/vehicle/km/entry/
  // ===========================================================================

  Future<void> getKmEntries({
    String? pageUrl,
    bool showMainLoader = true,
  }) async {
    if (!mounted) return;

    if (showMainLoader) {
      setState(() {
        isKmLoading = true;
      });
    } else {
      setState(() {
        isKmPageLoading = true;
      });
    }

    try {
      final String? token = await gettokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found.',
        );
      }

      final String url = pageUrl == null || pageUrl.trim().isEmpty
          ? '$api/api/vehicle/km/entry/'
          : resolvePaginationUrl(pageUrl);

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      debugPrint(
        '=============== GET KM ENTRIES REQUEST ================',
      );
      debugPrint(
        'GET KM ENTRIES URL: $url',
      );
      debugPrint(
        'GET KM ENTRIES HEADERS: $headers',
      );

      final http.Response response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint(
        '=============== GET KM ENTRIES RESPONSE ===============',
      );
      debugPrint(
        'GET KM ENTRIES STATUS: ${response.statusCode}',
      );
      debugPrint(
        'GET KM ENTRIES HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'GET KM ENTRIES BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200) {
        final dynamic parsed = jsonDecode(
          response.body,
        );

        List<dynamic> entryData = [];
        Map<String, dynamic> summaryData = {};
        List<dynamic> vehicleSummaryData = [];

        int totalCount = 0;
        String? nextUrl;
        String? previousUrl;

        if (parsed is Map<String, dynamic>) {
          totalCount = parseInt(
                parsed['count'],
              ) ??
              0;

          nextUrl = parsed['next']?.toString();
          previousUrl = parsed['previous']?.toString();

          final dynamic results = parsed['results'];

          if (results is Map) {
            final Map<String, dynamic> resultMap =
                Map<String, dynamic>.from(
              results,
            );

            if (resultMap['data'] is List) {
              entryData = List<dynamic>.from(
                resultMap['data'],
              );
            }

            if (resultMap['summary'] is Map) {
              summaryData = Map<String, dynamic>.from(
                resultMap['summary'],
              );
            }

            if (resultMap['vehicle_summary'] is List) {
              vehicleSummaryData = List<dynamic>.from(
                resultMap['vehicle_summary'],
              );
            }

            debugPrint(
              'GET KM ENTRIES API STATUS: ${resultMap['status']}',
            );
            debugPrint(
              'GET KM ENTRIES API MESSAGE: ${resultMap['message']}',
            );
            debugPrint(
              'GET KM ENTRIES FILTERS: ${resultMap['filters']}',
            );
            debugPrint(
              'GET KM ENTRIES SUMMARY: $summaryData',
            );
            debugPrint(
              'GET KM ENTRIES VEHICLE SUMMARY: $vehicleSummaryData',
            );
          } else if (results is List) {
            // Backward-compatible fallback only.
            entryData = List<dynamic>.from(
              results,
            );
          }
        } else if (parsed is List) {
          // Backward-compatible fallback only.
          entryData = parsed;
          totalCount = parsed.length;
        }

        final List<Map<String, dynamic>> entryList = [];

        for (final dynamic itemValue in entryData) {
          if (itemValue is! Map) {
            continue;
          }

          final Map<String, dynamic> item =
              Map<String, dynamic>.from(
            itemValue,
          );

          final dynamic vehicleData = item['vehicle'];

          int? vehicleId;
          String vehicleName = '';
          String registrationNumber = '';

          if (vehicleData is Map) {
            final Map<String, dynamic> vehicleMap =
                Map<String, dynamic>.from(
              vehicleData,
            );

            vehicleId = parseInt(
              vehicleMap['id'],
            );

            vehicleName =
                vehicleMap['name']?.toString() ?? '';

            registrationNumber =
                vehicleMap['registration_number']
                        ?.toString() ??
                    '';
          } else {
            vehicleId = parseInt(
              vehicleData,
            );
          }

          if (vehicleName.trim().isEmpty) {
            vehicleName =
                item['vehicle_name']?.toString() ?? '';
          }

          if (registrationNumber.trim().isEmpty) {
            registrationNumber =
                item['registration_number']?.toString() ??
                    item['vehicle_registration_number']
                        ?.toString() ??
                    '';
          }

          entryList.add({
            'id': item['id'],
            'date': item['date']?.toString() ?? '',
            'vehicle': vehicleId,
            'vehicle_name': vehicleName,
            'registration_number': registrationNumber,
            'starting_km': parseDouble(
              item['starting_km'],
            ),
            'end_km': parseDouble(
              item['end_km'],
            ),
            'used_km': parseDouble(
              item['used_km'],
            ),
            'petrol': parseDouble(
              item['petrol'],
            ),
            'created_by': item['created_by'],
            'created_by_name':
                item['created_by_name']?.toString() ?? '',
            'created_at':
                item['created_at']?.toString() ?? '',
            'updated_at':
                item['updated_at']?.toString() ?? '',
          });
        }

        entryList.sort(
          (a, b) {
            final DateTime? dateA = DateTime.tryParse(
              a['date']?.toString() ?? '',
            );

            final DateTime? dateB = DateTime.tryParse(
              b['date']?.toString() ?? '',
            );

            if (dateA != null && dateB != null) {
              return dateB.compareTo(dateA);
            }

            return (parseInt(b['id']) ?? 0).compareTo(
              parseInt(a['id']) ?? 0,
            );
          },
        );

        final List<Map<String, dynamic>>
            parsedVehicleSummary = [];

        for (final dynamic summaryItem
            in vehicleSummaryData) {
          if (summaryItem is Map) {
            parsedVehicleSummary.add(
              Map<String, dynamic>.from(
                summaryItem,
              ),
            );
          }
        }

        final int resolvedPage =
            getPageNumberFromUrl(
          url,
          fallback: pageUrl == null ? 1 : kmCurrentPage,
        );

        if (!mounted) return;

        setState(() {
          kmEntries = entryList;
          filteredKmEntries = entryList;

          kmTotalCount = totalCount;
          kmNextUrl = normalizeNullableUrl(
            nextUrl,
          );
          kmPreviousUrl = normalizeNullableUrl(
            previousUrl,
          );
          kmCurrentPage = resolvedPage;

          kmSummary = summaryData;
          kmVehicleSummary = parsedVehicleSummary;

          isKmLoading = false;
          isKmPageLoading = false;
        });

        if (kmSearchController.text.trim().isNotEmpty) {
          searchKmEntries(
            kmSearchController.text,
          );
        }
      } else {
        if (!mounted) return;

        setState(() {
          isKmLoading = false;
          isKmPageLoading = false;
        });

        showErrorSnackBar(
          getApiErrorMessage(response),
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'GET KM ENTRIES ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        isKmLoading = false;
        isKmPageLoading = false;
      });

      showErrorSnackBar(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  Future<void> loadNextKmPage() async {
    if (isKmLoading ||
        isKmPageLoading ||
        kmNextUrl == null) {
      return;
    }

    await getKmEntries(
      pageUrl: kmNextUrl,
      showMainLoader: false,
    );
  }

  Future<void> loadPreviousKmPage() async {
    if (isKmLoading ||
        isKmPageLoading ||
        kmPreviousUrl == null) {
      return;
    }

    await getKmEntries(
      pageUrl: kmPreviousUrl,
      showMainLoader: false,
    );
  }

  String? normalizeNullableUrl(
    dynamic value,
  ) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  String resolvePaginationUrl(
    String value,
  ) {
    final String url = value.trim();

    if (url.startsWith('http://') ||
        url.startsWith('https://')) {
      return url;
    }

    final String base = api.endsWith('/')
        ? api.substring(
            0,
            api.length - 1,
          )
        : api;

    if (url.startsWith('/')) {
      return '$base$url';
    }

    return '$base/$url';
  }

  int getPageNumberFromUrl(
    String url, {
    int fallback = 1,
  }) {
    try {
      final Uri uri = Uri.parse(
        url,
      );

      return int.tryParse(
            uri.queryParameters['page'] ?? '',
          ) ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  // ===========================================================================
  // ADD KM ENTRY
  //
  // API:
  // POST api/vehicle/km/entry/
  //
  // fields:
  // date
  // vehicle
  // starting_km
  // end_km
  // used_km
  // petrol
  // ===========================================================================

  Future<bool> addKmEntry() async {
    if (selectedVehicleId == null) {
      showErrorSnackBar(
        'Please select vehicle.',
      );
      return false;
    }

    if (startingKmController.text.trim().isEmpty) {
      showErrorSnackBar(
        'Please enter starting KM.',
      );
      return false;
    }

    if (endKmController.text.trim().isEmpty) {
      showErrorSnackBar(
        'Please enter end KM.',
      );
      return false;
    }

    if (petrolController.text.trim().isEmpty) {
      showErrorSnackBar(
        'Please enter petrol.',
      );
      return false;
    }

    double? startKm = double.tryParse(
      startingKmController.text.trim(),
    );

    double? endKm = double.tryParse(
      endKmController.text.trim(),
    );

    double? petrol = double.tryParse(
      petrolController.text.trim(),
    );

    if (startKm == null) {
      showErrorSnackBar(
        'Please enter valid starting KM.',
      );
      return false;
    }

    if (endKm == null) {
      showErrorSnackBar(
        'Please enter valid end KM.',
      );
      return false;
    }

    if (endKm < startKm) {
      showErrorSnackBar(
        'End KM cannot be less than starting KM.',
      );
      return false;
    }

    if (petrol == null || petrol < 0) {
      showErrorSnackBar(
        'Please enter valid petrol value.',
      );
      return false;
    }

    double usedKm = endKm - startKm;

    if (isKmSubmitting) {
      return false;
    }

    if (mounted) {
      setState(() {
        isKmSubmitting = true;
      });
    }

    try {
      final token = await gettokenFromPrefs();

      final String url =
          '$api/api/vehicle/km/entry/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
      };

      final Map<String, String> body = {
        'date': DateFormat('yyyy-MM-dd').format(
          selectedDate,
        ),
        'vehicle': selectedVehicleId.toString(),
        'starting_km': numberToApi(startKm),
        'end_km': numberToApi(endKm),
        'used_km': numberToApi(usedKm),
        'petrol': numberToApi(petrol),
      };

      debugPrint(
        '================ ADD KM ENTRY REQUEST =================',
      );
      debugPrint(
        'ADD KM ENTRY URL: $url',
      );
      debugPrint(
        'ADD KM ENTRY METHOD: POST',
      );
      debugPrint(
        'ADD KM ENTRY HEADERS: $headers',
      );
      debugPrint(
        'ADD KM ENTRY BODY: $body',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '================ ADD KM ENTRY RESPONSE ================',
      );
      debugPrint(
        'ADD KM ENTRY STATUS: ${response.statusCode}',
      );
      debugPrint(
        'ADD KM ENTRY HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'ADD KM ENTRY BODY RESPONSE: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        clearKmForm();

        await getKmEntries();

        if (!mounted) return true;

        setState(() {
          isKmSubmitting = false;
        });

        showSuccessSnackBar(
          'KM entry added successfully',
        );

        return true;
      } else {
        if (!mounted) return false;

        setState(() {
          isKmSubmitting = false;
        });

        showErrorSnackBar(
          getApiErrorMessage(response),
        );

        return false;
      }
    } catch (error) {
      debugPrint(
        'ADD KM ENTRY ERROR: $error',
      );

      if (!mounted) return false;

      setState(() {
        isKmSubmitting = false;
      });

      showErrorSnackBar(
        'An error occurred while adding KM entry.',
      );

      return false;
    }
  }

  // ===========================================================================
  // UPDATE KM ENTRY
  //
  // API:
  // PUT api/vehicle/km/entry/<pk>/
  // ===========================================================================

  Future<bool> updateKmEntry() async {
    if (editingKmEntryId == null) {
      return false;
    }

    if (selectedVehicleId == null) {
      showErrorSnackBar(
        'Please select vehicle.',
      );
      return false;
    }

    double? startKm = double.tryParse(
      startingKmController.text.trim(),
    );

    double? endKm = double.tryParse(
      endKmController.text.trim(),
    );

    double? petrol = double.tryParse(
      petrolController.text.trim(),
    );

    if (startKm == null) {
      showErrorSnackBar(
        'Please enter valid starting KM.',
      );
      return false;
    }

    if (endKm == null) {
      showErrorSnackBar(
        'Please enter valid end KM.',
      );
      return false;
    }

    if (endKm < startKm) {
      showErrorSnackBar(
        'End KM cannot be less than starting KM.',
      );
      return false;
    }

    if (petrol == null || petrol < 0) {
      showErrorSnackBar(
        'Please enter valid petrol.',
      );
      return false;
    }

    double usedKm = endKm - startKm;

    if (isKmSubmitting) {
      return false;
    }

    if (mounted) {
      setState(() {
        isKmSubmitting = true;
      });
    }

    try {
      final token = await gettokenFromPrefs();

      final String url =
          '$api/api/vehicle/km/entry/$editingKmEntryId/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
      };

      final Map<String, String> body = {
        'date': DateFormat('yyyy-MM-dd').format(
          selectedDate,
        ),
        'vehicle': selectedVehicleId.toString(),
        'starting_km': numberToApi(startKm),
        'end_km': numberToApi(endKm),
        'used_km': numberToApi(usedKm),
        'petrol': numberToApi(petrol),
      };

      debugPrint(
        '=============== UPDATE KM ENTRY REQUEST ===============',
      );
      debugPrint(
        'UPDATE KM ENTRY URL: $url',
      );
      debugPrint(
        'UPDATE KM ENTRY METHOD: PUT',
      );
      debugPrint(
        'UPDATE KM ENTRY HEADERS: $headers',
      );
      debugPrint(
        'UPDATE KM ENTRY BODY: $body',
      );

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '=============== UPDATE KM ENTRY RESPONSE ==============',
      );
      debugPrint(
        'UPDATE KM ENTRY STATUS: ${response.statusCode}',
      );
      debugPrint(
        'UPDATE KM ENTRY HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'UPDATE KM ENTRY BODY RESPONSE: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 202) {
        clearKmForm();

        await getKmEntries();

        if (!mounted) return true;

        setState(() {
          isKmSubmitting = false;
        });

        showSuccessSnackBar(
          'KM entry updated successfully',
        );

        return true;
      } else {
        if (!mounted) return false;

        setState(() {
          isKmSubmitting = false;
        });

        showErrorSnackBar(
          getApiErrorMessage(response),
        );

        return false;
      }
    } catch (error) {
      debugPrint(
        'UPDATE KM ENTRY ERROR: $error',
      );

      if (!mounted) return false;

      setState(() {
        isKmSubmitting = false;
      });

      showErrorSnackBar(
        'An error occurred while updating KM entry.',
      );

      return false;
    }
  }

  // ===========================================================================
  // CALCULATE USED KM
  // ===========================================================================

  void calculateUsedKm() {
    double? startKm = double.tryParse(
      startingKmController.text.trim(),
    );

    double? endKm = double.tryParse(
      endKmController.text.trim(),
    );

    if (startKm != null &&
        endKm != null &&
        endKm >= startKm) {
      double usedKm = endKm - startKm;

      String newValue = formatNumber(
        usedKm,
      );

      if (usedKmController.text != newValue) {
        usedKmController.text = newValue;
      }
    } else {
      if (usedKmController.text.isNotEmpty) {
        usedKmController.clear();
      }
    }
  }

  // ===========================================================================
  // SEARCH VEHICLES
  // ===========================================================================

  void searchVehicles(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        filteredVehicles = vehicles;
      });

      return;
    }

    final search = query.toLowerCase().trim();

    setState(() {
      filteredVehicles = vehicles.where((vehicle) {
        String name =
            vehicle['name']?.toString().toLowerCase() ?? '';

        String registration = vehicle['registration_number']
                ?.toString()
                .toLowerCase() ??
            '';

        String model =
            vehicle['model']?.toString().toLowerCase() ?? '';

        return name.contains(search) ||
            registration.contains(search) ||
            model.contains(search);
      }).toList();
    });
  }

  // ===========================================================================
  // SEARCH KM
  // ===========================================================================

  void searchKmEntries(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        filteredKmEntries = kmEntries;
      });

      return;
    }

    final search = query.toLowerCase().trim();

    setState(() {
      filteredKmEntries = kmEntries.where((entry) {
        String vehicleName =
            getVehicleName(entry).toLowerCase();

        String registration =
            getVehicleRegistration(entry).toLowerCase();

        String date =
            entry['date']?.toString().toLowerCase() ?? '';

        String startingKm =
            entry['starting_km']?.toString() ?? '';

        String endKm =
            entry['end_km']?.toString() ?? '';

        String usedKm =
            entry['used_km']?.toString() ?? '';

        return vehicleName.contains(search) ||
            registration.contains(search) ||
            date.contains(search) ||
            startingKm.contains(search) ||
            endKm.contains(search) ||
            usedKm.contains(search);
      }).toList();
    });
  }

  // ===========================================================================
  // VEHICLE LOOKUP
  // ===========================================================================

  Map<String, dynamic>? getVehicleById(
    int? vehicleId,
  ) {
    if (vehicleId == null) {
      return null;
    }

    for (var vehicle in vehicles) {
      if (parseInt(vehicle['id']) == vehicleId) {
        return vehicle;
      }
    }

    return null;
  }

  String getVehicleName(
    Map<String, dynamic> entry,
  ) {
    String name =
        entry['vehicle_name']?.toString() ?? '';

    if (name.trim().isNotEmpty) {
      return name;
    }

    int? vehicleId = parseInt(
      entry['vehicle'],
    );

    Map<String, dynamic>? vehicle =
        getVehicleById(vehicleId);

    return vehicle?['name']?.toString() ??
        'Unknown Vehicle';
  }

  String getVehicleRegistration(
    Map<String, dynamic> entry,
  ) {
    String registration =
        entry['registration_number']?.toString() ?? '';

    if (registration.trim().isNotEmpty) {
      return registration;
    }

    int? vehicleId = parseInt(
      entry['vehicle'],
    );

    Map<String, dynamic>? vehicle =
        getVehicleById(vehicleId);

    return vehicle?['registration_number']
            ?.toString() ??
        '';
  }

  // ===========================================================================
  // CLEAR VEHICLE FORM
  // ===========================================================================

  void clearVehicleForm() {
    vehicleNameController.clear();
    registrationNumberController.clear();
    vehicleModelController.clear();

    selectedVehicleImage = null;
    selectedVehicleImageBytes = null;
    existingVehicleImageUrl = '';

    editingVehicleId = null;
  }

  // ===========================================================================
  // CLEAR KM FORM
  // ===========================================================================

  void clearKmForm() {
    selectedVehicleId = null;

    selectedDate = DateTime.now();

    startingKmController.clear();
    endKmController.clear();
    usedKmController.clear();
    petrolController.clear();

    editingKmEntryId = null;
  }

  // ===========================================================================
  // OPEN VEHICLE FORM
  // ===========================================================================

  Future<void> openVehicleForm({
    Map<String, dynamic>? vehicle,
  }) async {
    bool isEditing = vehicle != null;
    Map<String, dynamic>? vehicleForEdit = vehicle;

    if (isEditing) {
      final int? vehicleId = parseInt(
        vehicle['id'],
      );

      if (vehicleId == null) {
        showErrorSnackBar(
          'Invalid vehicle ID.',
        );
        return;
      }

      final Map<String, dynamic>? latestVehicle =
          await getVehicleDetail(
        vehicleId,
      );

      if (!mounted) return;

      if (latestVehicle == null) {
        return;
      }

      vehicleForEdit = latestVehicle;

      editingVehicleId = vehicleId;

      vehicleNameController.text =
          vehicleForEdit['name']?.toString() ?? '';

      registrationNumberController.text =
          vehicleForEdit['registration_number']
                  ?.toString() ??
              '';

      vehicleModelController.text =
          vehicleForEdit['model']?.toString() ?? '';

      existingVehicleImageUrl = buildMediaUrl(
        vehicleForEdit['image'],
      );

      selectedVehicleImage = null;
      selectedVehicleImageBytes = null;
    } else {
      clearVehicleForm();
    }

    final Map<String, dynamic>? editVehicleData =
        vehicleForEdit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height *
                        0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 15,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                          25,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEFF6FF),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Edit Vehicle'
                                    : 'Add Vehicle',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                isEditing
                                    ? 'Update vehicle information'
                                    : 'Add vehicle for KM tracking',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                      Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    const Text(
                      'Vehicle Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextField(
                      controller:
                          vehicleNameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration: inputDecoration(
                        labelText:
                            'Enter vehicle name',
                        icon:
                            Icons.directions_car_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Registration Number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextField(
                      controller:
                          registrationNumberController,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration: inputDecoration(
                        labelText:
                            'Example: KL 07 AB 1234',
                        icon:
                            Icons.pin_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Model',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextField(
                      controller: vehicleModelController,
                      textCapitalization: TextCapitalization.words,
                      decoration: inputDecoration(
                        labelText: 'Enter vehicle model',
                        icon: Icons.badge_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Vehicle Image',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              height: 170,
                              color: const Color(0xFFF3F4F6),
                              child: selectedVehicleImage != null &&
                                      selectedVehicleImageBytes != null
                                  ? Image.memory(
                                      selectedVehicleImageBytes!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 40,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        );
                                      },
                                    )
                                  : existingVehicleImageUrl.isNotEmpty
                                      ? Image.network(
                                          existingVehicleImageUrl,
                                          width: double.infinity,
                                          height: 170,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }

                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            );
                                          },
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            debugPrint(
                                              'VEHICLE IMAGE LOAD ERROR: '
                                              '$existingVehicleImageUrl - $error',
                                            );

                                            return const Center(
                                              child: Icon(
                                                Icons
                                                    .broken_image_outlined,
                                                size: 40,
                                                color:
                                                    Color(0xFF9CA3AF),
                                              ),
                                            );
                                          },
                                        )
                                      : const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 38,
                                                color:
                                                    Color(0xFF9CA3AF),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'No image selected',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                            ),
                          ),

                          if (selectedVehicleImage == null &&
                              existingVehicleImageUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Current uploaded image',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isVehicleSubmitting
                                      ? null
                                      : () async {
                                          await pickVehicleImage(
                                            setModalState,
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    selectedVehicleImage != null ||
                                            existingVehicleImageUrl.isNotEmpty
                                        ? 'Change Image'
                                        : 'Choose Image',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              if (selectedVehicleImage != null) ...[
                                const SizedBox(width: 10),
                                IconButton(
                                  tooltip: 'Remove selected image',
                                  onPressed: isVehicleSubmitting
                                      ? null
                                      : () {
                                          setModalState(() {
                                            selectedVehicleImage = null;
                                            selectedVehicleImageBytes = null;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (isEditing) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((editVehicleData?['created_by']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty)
                              Text(
                                'Created by: ${editVehicleData?['created_by']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            if ((editVehicleData?['created_at']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Created: ${formatDateTimeValue(editVehicleData?['created_at'])}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                            if ((editVehicleData?['updated_at']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Updated: ${formatDateTimeValue(editVehicleData?['updated_at'])}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 25,
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            isVehicleSubmitting
                                ? null
                                : () async {
                                    bool success;

                                    if (isEditing) {
                                      success =
                                          await updateVehicle();
                                    } else {
                                      success =
                                          await addVehicle();
                                    }

                                    if (success &&
                                        bottomSheetContext
                                            .mounted) {
                                      Navigator.pop(
                                        bottomSheetContext,
                                      );
                                    } else {
                                      setModalState(
                                        () {},
                                      );
                                    }
                                  },
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF2563EB),
                          foregroundColor:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                        ),
                        child: isVehicleSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Update Vehicle'
                                    : 'Add Vehicle',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      clearVehicleForm();

      if (mounted) {
        setState(() {
          isVehicleSubmitting = false;
        });
      }
    });
  }

  // ===========================================================================
  // OPEN KM FORM
  // ===========================================================================

  void openKmForm({
    Map<String, dynamic>? entry,
  }) {
    if (vehicles.isEmpty) {
      showErrorSnackBar(
        'Please add a vehicle first.',
      );
      return;
    }

    bool isEditing = entry != null;

    if (isEditing) {
      editingKmEntryId = parseInt(
        entry['id'],
      );

      selectedVehicleId = parseInt(
        entry['vehicle'],
      );

      selectedDate =
          DateTime.tryParse(
            entry['date']?.toString() ?? '',
          ) ??
          DateTime.now();

      startingKmController.text =
          formatNumber(
        parseDouble(
          entry['starting_km'],
        ),
      );

      endKmController.text =
          formatNumber(
        parseDouble(
          entry['end_km'],
        ),
      );

      usedKmController.text =
          formatNumber(
        parseDouble(
          entry['used_km'],
        ),
      );

      petrolController.text =
          formatNumber(
        parseDouble(
          entry['petrol'],
        ),
      );
    } else {
      clearKmForm();

      if (vehicles.isNotEmpty) {
        selectedVehicleId =
            parseInt(vehicles.first['id']);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height *
                        0.95,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 15,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                          25,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFECFDF5),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.speed_rounded,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Edit KM Entry'
                                    : 'Add KM Entry',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              const Text(
                                'Vehicle KM & petrol tracking',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    InkWell(
                      onTap: () async {
                        DateTime? pickedDate =
                            await showDatePicker(
                          context: context,
                          initialDate:
                              selectedDate,
                          firstDate:
                              DateTime(2020),
                          lastDate:
                              DateTime(2100),
                        );

                        if (pickedDate != null) {
                          setModalState(() {
                            selectedDate =
                                pickedDate;
                          });
                        }
                      },
                      child: Container(
                        height: 53,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 15,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF9FAFB),
                          border: Border.all(
                            color:
                                const Color(0xFFE5E7EB),
                          ),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons
                                  .calendar_today_outlined,
                              size: 19,
                              color:
                                  Color(0xFF6B7280),
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'dd-MM-yyyy',
                                ).format(
                                  selectedDate,
                                ),
                                style:
                                    const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons
                                  .keyboard_arrow_down,
                              color:
                                  Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Vehicle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    DropdownButtonFormField<int>(
                      value: vehicles.any(
                        (vehicle) =>
                            parseInt(
                              vehicle['id'],
                            ) ==
                            selectedVehicleId,
                      )
                          ? selectedVehicleId
                          : null,
                      isExpanded: true,
                      decoration: inputDecoration(
                        labelText:
                            'Select vehicle',
                        icon: Icons
                            .directions_car_outlined,
                      ),
                      items: vehicles.map(
                        (vehicle) {
                          int? id = parseInt(
                            vehicle['id'],
                          );

                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              [
                                vehicle['name']?.toString().trim() ?? '',
                                vehicle['model']?.toString().trim() ?? '',
                                vehicle['registration_number']?.toString().trim() ?? '',
                              ].where((value) => value.isNotEmpty).join(' - '),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedVehicleId =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Starting KM',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              TextField(
                                controller:
                                    startingKmController,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    inputDecoration(
                                  labelText:
                                      'Starting',
                                  icon:
                                      Icons.flag_outlined,
                                  suffixText: 'KM',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End KM',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              TextField(
                                controller:
                                    endKmController,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    inputDecoration(
                                  labelText:
                                      'Ending',
                                  icon: Icons
                                      .sports_score_outlined,
                                  suffixText: 'KM',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Used KM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextField(
                      controller:
                          usedKmController,
                      readOnly: true,
                      decoration:
                          inputDecoration(
                        labelText:
                            'Automatically calculated',
                        icon:
                            Icons.route_outlined,
                        suffixText: 'KM',
                        fillColor:
                            const Color(0xFFF0FDF4),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Petrol',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextField(
                      controller:
                          petrolController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          inputDecoration(
                        labelText:
                            'Enter petrol',
                        icon: Icons
                            .local_gas_station_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFFFFBEB),
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFFDE68A),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color:
                                Color(0xFFD97706),
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              'Used KM is automatically calculated as End KM - Starting KM.',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            isKmSubmitting
                                ? null
                                : () async {
                                    bool success;

                                    if (isEditing) {
                                      success =
                                          await updateKmEntry();
                                    } else {
                                      success =
                                          await addKmEntry();
                                    }

                                    if (success &&
                                        bottomSheetContext
                                            .mounted) {
                                      Navigator.pop(
                                        bottomSheetContext,
                                      );
                                    } else {
                                      setModalState(
                                        () {},
                                      );
                                    }
                                  },
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF059669),
                          foregroundColor:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                        ),
                        child: isKmSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Update KM Entry'
                                    : 'Save KM Entry',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      clearKmForm();

      if (mounted) {
        setState(() {
          isKmSubmitting = false;
        });
      }
    });
  }



  // ===========================================================================
  // GET SINGLE / LATEST KM ENTRY BY VEHICLE
  //
  // API:
  // GET api/vehicle/km/entry/single/?vehicle_id=<vehicle_id>
  //
  // Used by Service edit/open flow to resolve the selected vehicle and
  // prefill the latest odometer KM without depending on a service-history ID.
  // ===========================================================================

  Future<Map<String, dynamic>?> getSingleKmEntryByVehicle(
    int vehicleId,
  ) async {
    try {
      final String? token =
          await gettokenFromPrefs();

      if (token == null ||
          token.trim().isEmpty) {
        showErrorSnackBar(
          'Authentication token not found.',
        );
        return null;
      }

      final Uri uri = Uri.parse(
        '$api/api/vehicle/km/entry/single/',
      ).replace(
        queryParameters: {
          'vehicle_id': vehicleId.toString(),
        },
      );

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      debugPrint(
        '=========== GET SINGLE KM BY VEHICLE REQUEST ===========',
      );
      debugPrint(
        'GET SINGLE KM URL: $uri',
      );
      debugPrint(
        'GET SINGLE KM HEADERS: $headers',
      );

      final http.Response response =
          await http.get(
        uri,
        headers: headers,
      );

      debugPrint(
        '========== GET SINGLE KM BY VEHICLE RESPONSE ===========',
      );
      debugPrint(
        'GET SINGLE KM STATUS: ${response.statusCode}',
      );
      debugPrint(
        'GET SINGLE KM HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'GET SINGLE KM BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode != 200) {
        showErrorSnackBar(
          getApiErrorMessage(response),
        );
        return null;
      }

      final dynamic parsed =
          jsonDecode(
        response.body,
      );

      Map<String, dynamic>? rawEntry;

      if (parsed is Map) {
        final Map<String, dynamic> map =
            Map<String, dynamic>.from(
          parsed,
        );

        if (map['data'] is Map) {
          rawEntry =
              Map<String, dynamic>.from(
            map['data'],
          );
        } else if (map['result'] is Map) {
          rawEntry =
              Map<String, dynamic>.from(
            map['result'],
          );
        } else if (map['results'] is Map) {
          final Map<String, dynamic> results =
              Map<String, dynamic>.from(
            map['results'],
          );

          if (results['data'] is Map) {
            rawEntry =
                Map<String, dynamic>.from(
              results['data'],
            );
          } else if (results.containsKey(
            'vehicle',
          )) {
            rawEntry = results;
          }
        } else if (map.containsKey(
              'vehicle',
            ) ||
            map.containsKey(
              'vehicle_id',
            )) {
          rawEntry = map;
        }
      }

      if (rawEntry == null) {
        return null;
      }

      final dynamic vehicleData =
          rawEntry['vehicle'];

      int? resolvedVehicleId;
      String vehicleName = '';
      String registrationNumber = '';

      if (vehicleData is Map) {
        final Map<String, dynamic>
            vehicleMap =
            Map<String, dynamic>.from(
          vehicleData,
        );

        resolvedVehicleId =
            parseInt(
          vehicleMap['id'],
        );

        vehicleName =
            vehicleMap['name']
                    ?.toString() ??
                '';

        registrationNumber =
            vehicleMap[
                        'registration_number']
                    ?.toString() ??
                '';
      } else {
        resolvedVehicleId =
            parseInt(
          vehicleData,
        );
      }

      resolvedVehicleId ??=
          parseInt(
        rawEntry['vehicle_id'],
      );

      resolvedVehicleId ??=
          vehicleId;

      if (vehicleName.trim().isEmpty) {
        vehicleName =
            rawEntry['vehicle_name']
                    ?.toString() ??
                '';
      }

      if (registrationNumber
          .trim()
          .isEmpty) {
        registrationNumber =
            rawEntry[
                        'registration_number']
                    ?.toString() ??
                rawEntry[
                            'vehicle_registration_number']
                        ?.toString() ??
                    '';
      }

      return {
        'id': rawEntry['id'],
        'vehicle': resolvedVehicleId,
        'vehicle_name': vehicleName,
        'registration_number':
            registrationNumber,
        'date':
            rawEntry['date']
                    ?.toString() ??
                '',
        'starting_km':
            parseDouble(
          rawEntry['starting_km'],
        ),
        'end_km':
            parseDouble(
          rawEntry['end_km'],
        ),
        'used_km':
            parseDouble(
          rawEntry['used_km'],
        ),
        'petrol':
            parseDouble(
          rawEntry['petrol'],
        ),
        'created_by':
            rawEntry['created_by'],
        'created_by_name':
            rawEntry['created_by_name']
                    ?.toString() ??
                '',
        'created_at':
            rawEntry['created_at']
                    ?.toString() ??
                '',
        'updated_at':
            rawEntry['updated_at']
                    ?.toString() ??
                '',
      };
    } catch (error, stackTrace) {
      debugPrint(
        'GET SINGLE KM BY VEHICLE ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      showErrorSnackBar(
        'Unable to load latest vehicle KM details.',
      );

      return null;
    }
  }

  int? getServiceVehicleId(
    Map<String, dynamic> service,
  ) {
    int? vehicleId =
        parseInt(
      service['vehicle_id'],
    );

    vehicleId ??=
        parseInt(
      service['vehicle'],
    );

    if (vehicleId != null) {
      return vehicleId;
    }

    final String registration =
        getServiceVehicleRegistration(
      service,
    ).trim().toLowerCase();

    final String vehicleName =
        getServiceVehicleName(
      service,
    ).trim().toLowerCase();

    for (final Map<String, dynamic> vehicle
        in vehicles) {
      final String currentRegistration =
          vehicle['registration_number']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final String currentName =
          vehicle['name']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      if (registration.isNotEmpty &&
          currentRegistration ==
              registration) {
        return parseInt(
          vehicle['id'],
        );
      }

      if (vehicleName.isNotEmpty &&
          currentName ==
              vehicleName) {
        return parseInt(
          vehicle['id'],
        );
      }
    }

    return null;
  }

  // ===========================================================================
  // VEHICLE SERVICE HISTORY
  //
  // GET / POST:
  // api/vehicle/service/history/
  //
  // GET / PUT:
  // api/vehicle/service/history/edit/<pk>/
  //
  // fields:
  // vehicle
  // service_date
  // service_type
  // service_center
  // odometer_km
  // service_cost
  // description
  // next_service_date
  // ===========================================================================

  bool isServiceHistoryRecord(
    Map<String, dynamic> item,
  ) {
    const List<String> serviceKeys = [
      'service_date',
      'service_type',
      'service_center',
      'odometer_km',
      'service_cost',
      'description',
      'next_service_date',
    ];

    return serviceKeys.any(
      (key) => item.containsKey(key),
    );
  }

  List<dynamic> extractServiceHistoryData(
    dynamic parsed,
  ) {
    final List<Map<String, dynamic>> records = [];

    void walk(dynamic value) {
      if (value is List) {
        for (final dynamic item in value) {
          walk(item);
        }
        return;
      }

      if (value is! Map) {
        return;
      }

      final Map<String, dynamic> map =
          Map<String, dynamic>.from(
        value,
      );

      if (isServiceHistoryRecord(map)) {
        records.add(map);
        return;
      }

      // Prefer known containers first.
      const List<String> preferredKeys = [
        'service_history',
        'services',
        'results',
        'data',
        'items',
      ];

      bool preferredFound = false;

      for (final String key in preferredKeys) {
        if (map.containsKey(key)) {
          preferredFound = true;
          walk(
            map[key],
          );
        }
      }

      // If the backend uses another wrapper key, inspect nested values,
      // but only service-history shaped maps will be accepted.
      if (!preferredFound) {
        for (final dynamic child
            in map.values) {
          if (child is Map ||
              child is List) {
            walk(
              child,
            );
          }
        }
      }
    }

    walk(
      parsed,
    );

    debugPrint(
      'SERVICE HISTORY EXTRACTED RECORD COUNT: ${records.length}',
    );

    for (int index = 0;
        index < records.length;
        index++) {
      debugPrint(
        'SERVICE HISTORY RAW RECORD [$index]: ${records[index]}',
      );
    }

    return records;
  }

  Map<String, dynamic>? extractServiceHistoryDetail(
    dynamic parsed,
  ) {
    debugPrint(
      'SERVICE DETAIL RAW PARSED: $parsed',
    );

    Map<String, dynamic>? found;

    void walk(dynamic value) {
      if (found != null) {
        return;
      }

      if (value is List) {
        for (final dynamic item in value) {
          walk(
            item,
          );

          if (found != null) {
            return;
          }
        }
        return;
      }

      if (value is! Map) {
        return;
      }

      final Map<String, dynamic> map =
          Map<String, dynamic>.from(
        value,
      );

      if (isServiceHistoryRecord(map)) {
        found = map;
        return;
      }

      const List<String> preferredKeys = [
        'service',
        'service_history',
        'result',
        'results',
        'data',
        'item',
      ];

      for (final String key in preferredKeys) {
        if (map.containsKey(key)) {
          walk(
            map[key],
          );

          if (found != null) {
            return;
          }
        }
      }

      for (final dynamic child
          in map.values) {
        if (child is Map ||
            child is List) {
          walk(
            child,
          );

          if (found != null) {
            return;
          }
        }
      }
    }

    walk(
      parsed,
    );

    debugPrint(
      'SERVICE DETAIL EXTRACTED: $found',
    );

    return found;
  }

  Map<String, dynamic> normalizeServiceHistoryItem(
    Map<String, dynamic> item,
  ) {
    debugPrint(
      'NORMALIZE SERVICE HISTORY INPUT: $item',
    );

    dynamic vehicleData =
        item['vehicle'];

    int? vehicleId =
        parseInt(
      item['vehicle_id'],
    );

    String vehicleName =
        item['vehicle_name']?.toString() ?? '';

    String registrationNumber =
        item['registration_number']
                ?.toString() ??
            item['vehicle_registration_number']
                ?.toString() ??
            '';

    if (vehicleData is Map) {
      final Map<String, dynamic> vehicleMap =
          Map<String, dynamic>.from(
        vehicleData,
      );

      vehicleId ??=
          parseInt(
        vehicleMap['id'],
      );

      if (vehicleName.trim().isEmpty) {
        vehicleName =
            vehicleMap['name']?.toString() ?? '';
      }

      if (registrationNumber.trim().isEmpty) {
        registrationNumber =
            vehicleMap['registration_number']
                    ?.toString() ??
                '';
      }
    } else {
      vehicleId ??=
          parseInt(
        vehicleData,
      );
    }

    final int? serviceId =
        parseInt(
          item['id'],
        ) ??
        parseInt(
          item['service_id'],
        ) ??
        parseInt(
          item['service_history_id'],
        ) ??
        parseInt(
          item['pk'],
        );

    final Map<String, dynamic> normalized = {
      'id': serviceId,
      'vehicle_id': vehicleId,
      'vehicle': vehicleId,
      'vehicle_name': vehicleName,
      'registration_number':
          registrationNumber,
      'service_date':
          item['service_date']?.toString() ?? '',
      'service_type':
          item['service_type']?.toString() ?? '',
      'service_center':
          item['service_center']?.toString() ?? '',
      'odometer_km':
          parseInt(
        item['odometer_km'],
      ),
      'service_cost':
          item['service_cost'],
      'description':
          item['description']?.toString() ?? '',
      'next_service_date':
          item['next_service_date']?.toString() ?? '',
      'created_by':
          item['created_by'],
      'created_by_name':
          item['created_by_name']?.toString() ??
              getCreatedByName(
                item['created_by'],
              ),
      'created_at':
          item['created_at']?.toString() ?? '',
      'updated_at':
          item['updated_at']?.toString() ?? '',
    };

    debugPrint(
      'NORMALIZE SERVICE HISTORY OUTPUT: $normalized',
    );

    return normalized;
  }

  Future<void> getServiceHistory() async {
    if (!mounted) return;

    setState(() {
      isServiceLoading = true;
    });

    try {
      final String? token =
          await gettokenFromPrefs();

      if (token == null ||
          token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found.',
        );
      }

      final String url =
          '$api/api/vehicle/service/history/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      debugPrint(
        '============= GET SERVICE HISTORY REQUEST =============',
      );
      debugPrint(
        'GET SERVICE HISTORY URL: $url',
      );
      debugPrint(
        'GET SERVICE HISTORY HEADERS: $headers',
      );

      final http.Response response =
          await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint(
        '============= GET SERVICE HISTORY RESPONSE ============',
      );
      debugPrint(
        'GET SERVICE HISTORY STATUS: ${response.statusCode}',
      );
      debugPrint(
        'GET SERVICE HISTORY HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'GET SERVICE HISTORY BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode != 200) {
        if (!mounted) return;

        setState(() {
          isServiceLoading = false;
        });

        showErrorSnackBar(
          getApiErrorMessage(response),
        );
        return;
      }

      final dynamic parsed = jsonDecode(
        response.body,
      );

      debugPrint(
        'GET SERVICE HISTORY PARSED TYPE: ${parsed.runtimeType}',
      );
      debugPrint(
        'GET SERVICE HISTORY PARSED VALUE: $parsed',
      );

      final List<dynamic> rawList =
          extractServiceHistoryData(
        parsed,
      );

      final List<Map<String, dynamic>>
          serviceList = [];

      for (final dynamic value in rawList) {
        if (value is Map) {
          serviceList.add(
            normalizeServiceHistoryItem(
              Map<String, dynamic>.from(
                value,
              ),
            ),
          );
        }
      }

      serviceList.sort(
        (a, b) {
          final DateTime? dateA =
              DateTime.tryParse(
            a['service_date']?.toString() ?? '',
          );

          final DateTime? dateB =
              DateTime.tryParse(
            b['service_date']?.toString() ?? '',
          );

          if (dateA != null &&
              dateB != null) {
            return dateB.compareTo(
              dateA,
            );
          }

          return (parseInt(b['id']) ?? 0)
              .compareTo(
            parseInt(a['id']) ?? 0,
          );
        },
      );

      debugPrint(
        'GET SERVICE HISTORY NORMALIZED COUNT: ${serviceList.length}',
      );

      for (int index = 0;
          index < serviceList.length;
          index++) {
        debugPrint(
          'GET SERVICE HISTORY NORMALIZED [$index]: ${serviceList[index]}',
        );
      }

      if (!mounted) return;

      setState(() {
        serviceHistory = serviceList;
        filteredServiceHistory = serviceList;
        isServiceLoading = false;
      });

      if (serviceSearchController.text
          .trim()
          .isNotEmpty) {
        searchServiceHistory(
          serviceSearchController.text,
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'GET SERVICE HISTORY ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        isServiceLoading = false;
      });

      showErrorSnackBar(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  Future<Map<String, dynamic>?>
      getServiceHistoryDetail(
    int serviceId,
  ) async {
    try {
      final String? token =
          await gettokenFromPrefs();

      if (token == null ||
          token.trim().isEmpty) {
        showErrorSnackBar(
          'Authentication token not found.',
        );
        return null;
      }

      final String url =
          '$api/api/vehicle/service/history/edit/$serviceId/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      debugPrint(
        '========== GET SERVICE HISTORY DETAIL REQUEST =========',
      );
      debugPrint(
        'GET SERVICE DETAIL URL: $url',
      );
      debugPrint(
        'GET SERVICE DETAIL HEADERS: $headers',
      );

      final http.Response response =
          await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint(
        '========== GET SERVICE HISTORY DETAIL RESPONSE ========',
      );
      debugPrint(
        'GET SERVICE DETAIL STATUS: ${response.statusCode}',
      );
      debugPrint(
        'GET SERVICE DETAIL HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'GET SERVICE DETAIL BODY: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode != 200) {
        showErrorSnackBar(
          getApiErrorMessage(response),
        );
        return null;
      }

      final dynamic parsed = jsonDecode(
        response.body,
      );

      debugPrint(
        'GET SERVICE DETAIL PARSED TYPE: ${parsed.runtimeType}',
      );
      debugPrint(
        'GET SERVICE DETAIL PARSED VALUE: $parsed',
      );

      final Map<String, dynamic>? detail =
          extractServiceHistoryDetail(
        parsed,
      );

      if (detail == null) {
        showErrorSnackBar(
          'Unable to load service details.',
        );
        return null;
      }

      return normalizeServiceHistoryItem(
        detail,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GET SERVICE HISTORY DETAIL ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      showErrorSnackBar(
        'Unable to load service details. Please try again.',
      );

      return null;
    }
  }

  Future<bool> addServiceHistory() async {
    if (selectedServiceVehicleId == null) {
      showErrorSnackBar(
        'Please select vehicle.',
      );
      return false;
    }

    final String odometerText =
        serviceOdometerController.text.trim();

    final String costText =
        serviceCostController.text.trim();

    int? odometer;

    if (odometerText.isNotEmpty) {
      odometer = int.tryParse(
        odometerText,
      );

      if (odometer == null ||
          odometer < 0) {
        showErrorSnackBar(
          'Please enter a valid odometer KM.',
        );
        return false;
      }
    }

    double? serviceCost;

    if (costText.isNotEmpty) {
      serviceCost = double.tryParse(
        costText,
      );

      if (serviceCost == null ||
          serviceCost < 0) {
        showErrorSnackBar(
          'Please enter a valid service cost.',
        );
        return false;
      }
    }

    if (isServiceSubmitting) {
      return false;
    }

    if (mounted) {
      setState(() {
        isServiceSubmitting = true;
      });
    }

    try {
      final String? token =
          await gettokenFromPrefs();

      if (token == null ||
          token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found.',
        );
      }

      final String url =
          '$api/api/vehicle/service/history/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final Map<String, String> body = {
        'vehicle':
            selectedServiceVehicleId.toString(),
        'service_date':
            selectedServiceDate == null
                ? ''
                : DateFormat(
                    'yyyy-MM-dd',
                  ).format(
                    selectedServiceDate!,
                  ),
        'service_type':
            serviceTypeController.text.trim(),
        'service_center':
            serviceCenterController.text.trim(),
        'odometer_km':
            odometer?.toString() ?? '',
        'service_cost':
            serviceCost == null
                ? ''
                : numberToApi(
                    serviceCost,
                  ),
        'description':
            serviceDescriptionController.text.trim(),
        'next_service_date':
            selectedNextServiceDate == null
                ? ''
                : DateFormat(
                    'yyyy-MM-dd',
                  ).format(
                    selectedNextServiceDate!,
                  ),
      };

      debugPrint(
        'ADD SERVICE FORM VALUES -> '
        'vehicle=$selectedServiceVehicleId, '
        'serviceDate=$selectedServiceDate, '
        'serviceType=${serviceTypeController.text}, '
        'serviceCenter=${serviceCenterController.text}, '
        'odometer=${serviceOdometerController.text}, '
        'cost=${serviceCostController.text}, '
        'description=${serviceDescriptionController.text}, '
        'nextServiceDate=$selectedNextServiceDate',
      );

      debugPrint(
        '============= ADD SERVICE HISTORY REQUEST ==============',
      );
      debugPrint(
        'ADD SERVICE HISTORY URL: $url',
      );
      debugPrint(
        'ADD SERVICE HISTORY METHOD: POST',
      );
      debugPrint(
        'ADD SERVICE HISTORY HEADERS: $headers',
      );
      debugPrint(
        'ADD SERVICE HISTORY BODY: $body',
      );

      final http.Response response =
          await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '============= ADD SERVICE HISTORY RESPONSE =============',
      );
      debugPrint(
        'ADD SERVICE HISTORY STATUS: ${response.statusCode}',
      );
      debugPrint(
        'ADD SERVICE HISTORY HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'ADD SERVICE HISTORY BODY RESPONSE: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        clearServiceForm();

        await getServiceHistory();

        if (!mounted) return true;

        setState(() {
          isServiceSubmitting = false;
        });

        showSuccessSnackBar(
          'Vehicle service added successfully',
        );

        return true;
      }

      if (!mounted) return false;

      setState(() {
        isServiceSubmitting = false;
      });

      showErrorSnackBar(
        getApiErrorMessage(response),
      );

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'ADD SERVICE HISTORY ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return false;

      setState(() {
        isServiceSubmitting = false;
      });

      showErrorSnackBar(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );

      return false;
    }
  }

  Future<bool> updateServiceHistory() async {
    if (editingServiceHistoryId == null) {
      return false;
    }

    if (selectedServiceVehicleId == null) {
      showErrorSnackBar(
        'Please select vehicle.',
      );
      return false;
    }

    final String odometerText =
        serviceOdometerController.text.trim();

    final String costText =
        serviceCostController.text.trim();

    int? odometer;

    if (odometerText.isNotEmpty) {
      odometer = int.tryParse(
        odometerText,
      );

      if (odometer == null ||
          odometer < 0) {
        showErrorSnackBar(
          'Please enter a valid odometer KM.',
        );
        return false;
      }
    }

    double? serviceCost;

    if (costText.isNotEmpty) {
      serviceCost = double.tryParse(
        costText,
      );

      if (serviceCost == null ||
          serviceCost < 0) {
        showErrorSnackBar(
          'Please enter a valid service cost.',
        );
        return false;
      }
    }

    if (isServiceSubmitting) {
      return false;
    }

    if (mounted) {
      setState(() {
        isServiceSubmitting = true;
      });
    }

    try {
      final String? token =
          await gettokenFromPrefs();

      if (token == null ||
          token.trim().isEmpty) {
        throw Exception(
          'Authentication token not found.',
        );
      }

      final String url =
          '$api/api/vehicle/service/history/edit/$editingServiceHistoryId/';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final Map<String, String> body = {
        'vehicle':
            selectedServiceVehicleId.toString(),
        'service_date':
            selectedServiceDate == null
                ? ''
                : DateFormat(
                    'yyyy-MM-dd',
                  ).format(
                    selectedServiceDate!,
                  ),
        'service_type':
            serviceTypeController.text.trim(),
        'service_center':
            serviceCenterController.text.trim(),
        'odometer_km':
            odometer?.toString() ?? '',
        'service_cost':
            serviceCost == null
                ? ''
                : numberToApi(
                    serviceCost,
                  ),
        'description':
            serviceDescriptionController.text.trim(),
        'next_service_date':
            selectedNextServiceDate == null
                ? ''
                : DateFormat(
                    'yyyy-MM-dd',
                  ).format(
                    selectedNextServiceDate!,
                  ),
      };

      debugPrint(
        'UPDATE SERVICE FORM VALUES -> '
        'serviceId=$editingServiceHistoryId, '
        'vehicle=$selectedServiceVehicleId, '
        'serviceDate=$selectedServiceDate, '
        'serviceType=${serviceTypeController.text}, '
        'serviceCenter=${serviceCenterController.text}, '
        'odometer=${serviceOdometerController.text}, '
        'cost=${serviceCostController.text}, '
        'description=${serviceDescriptionController.text}, '
        'nextServiceDate=$selectedNextServiceDate',
      );

      debugPrint(
        '============ UPDATE SERVICE HISTORY REQUEST ============',
      );
      debugPrint(
        'UPDATE SERVICE HISTORY URL: $url',
      );
      debugPrint(
        'UPDATE SERVICE HISTORY METHOD: PUT',
      );
      debugPrint(
        'UPDATE SERVICE HISTORY HEADERS: $headers',
      );
      debugPrint(
        'UPDATE SERVICE HISTORY BODY: $body',
      );

      final http.Response response =
          await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '============ UPDATE SERVICE HISTORY RESPONSE ===========',
      );
      debugPrint(
        'UPDATE SERVICE HISTORY STATUS: ${response.statusCode}',
      );
      debugPrint(
        'UPDATE SERVICE HISTORY HEADERS RESPONSE: ${response.headers}',
      );
      debugPrint(
        'UPDATE SERVICE HISTORY BODY RESPONSE: ${response.body}',
      );
      debugPrint(
        '=======================================================',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 202) {
        clearServiceForm();

        await getServiceHistory();

        if (!mounted) return true;

        setState(() {
          isServiceSubmitting = false;
        });

        showSuccessSnackBar(
          'Vehicle service updated successfully',
        );

        return true;
      }

      if (!mounted) return false;

      setState(() {
        isServiceSubmitting = false;
      });

      showErrorSnackBar(
        getApiErrorMessage(response),
      );

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'UPDATE SERVICE HISTORY ERROR: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return false;

      setState(() {
        isServiceSubmitting = false;
      });

      showErrorSnackBar(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );

      return false;
    }
  }

  void searchServiceHistory(
    String query,
  ) {
    if (query.trim().isEmpty) {
      setState(() {
        filteredServiceHistory =
            serviceHistory;
      });
      return;
    }

    final String search =
        query.toLowerCase().trim();

    setState(() {
      filteredServiceHistory =
          serviceHistory.where(
        (service) {
          final String vehicleName =
              getServiceVehicleName(
            service,
          ).toLowerCase();

          final String registration =
              getServiceVehicleRegistration(
            service,
          ).toLowerCase();

          final String serviceType =
              service['service_type']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final String serviceCenter =
              service['service_center']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final String description =
              service['description']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final String serviceDate =
              service['service_date']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          return vehicleName.contains(
                search,
              ) ||
              registration.contains(
                search,
              ) ||
              serviceType.contains(
                search,
              ) ||
              serviceCenter.contains(
                search,
              ) ||
              description.contains(
                search,
              ) ||
              serviceDate.contains(
                search,
              );
        },
      ).toList();
    });
  }

  String getServiceVehicleName(
    Map<String, dynamic> service,
  ) {
    final String name =
        service['vehicle_name']?.toString() ?? '';

    if (name.trim().isNotEmpty) {
      return name;
    }

    final Map<String, dynamic>? vehicle =
        getVehicleById(
      parseInt(
        service['vehicle'],
      ),
    );

    return vehicle?['name']?.toString() ??
        'Unknown Vehicle';
  }

  String getServiceVehicleRegistration(
    Map<String, dynamic> service,
  ) {
    final String registration =
        service['registration_number']
                ?.toString() ??
            '';

    if (registration.trim().isNotEmpty) {
      return registration;
    }

    final Map<String, dynamic>? vehicle =
        getVehicleById(
      parseInt(
        service['vehicle'],
      ),
    );

    return vehicle?['registration_number']
            ?.toString() ??
        '';
  }

  void clearServiceForm() {
    selectedServiceVehicleId = null;
    selectedServiceDate = null;
    selectedNextServiceDate = null;
    editingServiceHistoryId = null;

    serviceTypeController.clear();
    serviceCenterController.clear();
    serviceOdometerController.clear();
    serviceCostController.clear();
    serviceDescriptionController.clear();
  }

  Future<void> openServiceForm({
    Map<String, dynamic>? service,
  }) async {
    if (vehicles.isEmpty) {
      showErrorSnackBar(
        'Please add a vehicle first.',
      );
      return;
    }

    debugPrint(
      '================ OPEN SERVICE FORM =====================',
    );
    debugPrint(
      'OPEN SERVICE FORM INPUT: $service',
    );

    final bool isEditing =
        service != null;

    Map<String, dynamic>? serviceForEdit;

    if (isEditing) {
      final int? serviceId =
          parseInt(
            service['id'],
          ) ??
          parseInt(
            service['service_id'],
          ) ??
          parseInt(
            service['service_history_id'],
          ) ??
          parseInt(
            service['pk'],
          );

      debugPrint(
        'OPEN SERVICE FORM RESOLVED SERVICE ID: $serviceId',
      );

      if (serviceId == null) {
        debugPrint(
          'OPEN SERVICE FORM ERROR: Service record has no valid ID.',
        );

        showErrorSnackBar(
          'Service history ID missing in API response.',
        );
        return;
      }

      final Map<String, dynamic>? latestService =
          await getServiceHistoryDetail(
        serviceId,
      );

      if (!mounted) return;

      debugPrint(
        'OPEN SERVICE FORM FETCHED DETAIL: $latestService',
      );

      if (latestService == null) {
        return;
      }

      serviceForEdit =
          latestService;

      editingServiceHistoryId =
          serviceId;

      selectedServiceVehicleId =
          parseInt(
            latestService['vehicle'],
          ) ??
          parseInt(
            latestService['vehicle_id'],
          );

      selectedServiceDate =
          DateTime.tryParse(
        latestService['service_date']
                ?.toString() ??
            '',
      );

      selectedNextServiceDate =
          DateTime.tryParse(
        latestService['next_service_date']
                ?.toString() ??
            '',
      );

      serviceTypeController.text =
          latestService['service_type']
                  ?.toString() ??
              '';

      serviceCenterController.text =
          latestService['service_center']
                  ?.toString() ??
              '';

      final int? odometer =
          parseInt(
        latestService['odometer_km'],
      );

      serviceOdometerController.text =
          odometer?.toString() ?? '';

      final dynamic rawCost =
          latestService['service_cost'];

      if (rawCost == null ||
          rawCost.toString().trim().isEmpty ||
          rawCost.toString().toLowerCase() ==
              'null') {
        serviceCostController.clear();
      } else {
        serviceCostController.text =
            formatNumber(
          parseDouble(
            rawCost,
          ),
        );
      }

      serviceDescriptionController.text =
          latestService['description']
                  ?.toString() ??
              '';

      debugPrint(
        'OPEN SERVICE FORM PREFILL -> '
        'serviceId=$editingServiceHistoryId, '
        'vehicle=$selectedServiceVehicleId, '
        'serviceDate=$selectedServiceDate, '
        'serviceType=${serviceTypeController.text}, '
        'serviceCenter=${serviceCenterController.text}, '
        'odometer=${serviceOdometerController.text}, '
        'cost=${serviceCostController.text}, '
        'description=${serviceDescriptionController.text}, '
        'nextServiceDate=$selectedNextServiceDate',
      );
    } else {
      clearServiceForm();

      selectedServiceDate =
          DateTime.now();

      if (vehicles.isNotEmpty) {
        selectedServiceVehicleId =
            parseInt(
          vehicles.first['id'],
        );
      }

      debugPrint(
        'OPEN SERVICE FORM NEW -> '
        'vehicle=$selectedServiceVehicleId, '
        'serviceDate=$selectedServiceDate',
      );
    }

    final Map<String, dynamic>?
        editServiceData =
        serviceForEdit;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        bottomSheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            Widget dateSelector({
              required String title,
              required DateTime? value,
              required ValueChanged<DateTime?>
                  onChanged,
              required bool allowClear,
            }) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  InkWell(
                    onTap: () async {
                      final DateTime?
                          pickedDate =
                          await showDatePicker(
                        context: context,
                        initialDate:
                            value ??
                                DateTime.now(),
                        firstDate:
                            DateTime(2000),
                        lastDate:
                            DateTime(2100),
                      );

                      if (pickedDate !=
                          null) {
                        setModalState(
                          () {
                            onChanged(
                              pickedDate,
                            );
                          },
                        );
                      }
                    },
                    child: Container(
                      height: 53,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 15,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFF9FAFB,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFFE5E7EB,
                          ),
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .calendar_today_outlined,
                            size: 19,
                            color:
                                Color(
                              0xFF6B7280,
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Text(
                              value == null
                                  ? 'Select date'
                                  : DateFormat(
                                      'dd-MM-yyyy',
                                    ).format(
                                      value,
                                    ),
                              style:
                                  TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight
                                        .w600,
                                color: value ==
                                        null
                                    ? const Color(
                                        0xFF9CA3AF,
                                      )
                                    : const Color(
                                        0xFF111827,
                                      ),
                              ),
                            ),
                          ),
                          if (allowClear &&
                              value != null)
                            IconButton(
                              padding:
                                  EdgeInsets
                                      .zero,
                              constraints:
                                  const BoxConstraints(),
                              onPressed:
                                  () {
                                setModalState(
                                  () {
                                    onChanged(
                                      null,
                                    );
                                  },
                                );
                              },
                              icon:
                                  const Icon(
                                Icons.close,
                                size: 18,
                                color:
                                    Color(
                                  0xFF6B7280,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons
                                  .keyboard_arrow_down,
                              color:
                                  Color(
                                0xFF6B7280,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Container(
              constraints:
                  BoxConstraints(
                maxHeight:
                    MediaQuery.of(
                          context,
                        ).size.height *
                        0.95,
              ),
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top:
                      Radius.circular(
                    25,
                  ),
                ),
              ),
              child:
                  SingleChildScrollView(
                padding:
                    EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 15,
                  bottom: MediaQuery.of(
                            context,
                          )
                              .viewInsets
                              .bottom +
                      25,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration:
                            BoxDecoration(
                          color: Colors
                              .grey.shade300,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 22,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFFFF7ED,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .build_circle_outlined,
                            color:
                                Color(
                              0xFFEA580C,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Edit Vehicle Service'
                                    : 'Add Vehicle Service',
                                style:
                                    const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      Color(
                                    0xFF111827,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                isEditing
                                    ? 'Update service information'
                                    : 'Add vehicle service history',
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color:
                                      Color(
                                    0xFF6B7280,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    const Text(
                      'Vehicle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    DropdownButtonFormField<
                        int>(
                      value: vehicles.any(
                        (vehicle) =>
                            parseInt(
                              vehicle['id'],
                            ) ==
                            selectedServiceVehicleId,
                      )
                          ? selectedServiceVehicleId
                          : null,
                      isExpanded: true,
                      decoration:
                          inputDecoration(
                        labelText:
                            'Select vehicle',
                        icon: Icons
                            .directions_car_outlined,
                      ),
                      items: vehicles.map(
                        (vehicle) {
                          final int? id =
                              parseInt(
                            vehicle['id'],
                          );

                          return DropdownMenuItem<
                              int>(
                            value: id,
                            child: Text(
                              [
                                vehicle['name']
                                        ?.toString()
                                        .trim() ??
                                    '',
                                vehicle['model']
                                        ?.toString()
                                        .trim() ??
                                    '',
                                vehicle[
                                            'registration_number']
                                        ?.toString()
                                        .trim() ??
                                    '',
                              ]
                                  .where(
                                    (value) =>
                                        value
                                            .isNotEmpty,
                                  )
                                  .join(
                                    ' - ',
                                  ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          (value) {
                        setModalState(
                          () {
                            selectedServiceVehicleId =
                                value;
                          },
                        );
                      },
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    dateSelector(
                      title:
                          'Service Date',
                      value:
                          selectedServiceDate,
                      onChanged:
                          (value) {
                        selectedServiceDate =
                            value;
                      },
                      allowClear: true,
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    const Text(
                      'Service Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    TextField(
                      controller:
                          serviceTypeController,
                      textCapitalization:
                          TextCapitalization
                              .words,
                      decoration:
                          inputDecoration(
                        labelText:
                            'Enter service type',
                        icon: Icons
                            .build_outlined,
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    const Text(
                      'Service Center',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    TextField(
                      controller:
                          serviceCenterController,
                      textCapitalization:
                          TextCapitalization
                              .words,
                      decoration:
                          inputDecoration(
                        labelText:
                            'Enter service center',
                        icon: Icons
                            .location_city_outlined,
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'Odometer KM',
                                style:
                                    TextStyle(
                                  fontSize:
                                      13,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              TextField(
                                controller:
                                    serviceOdometerController,
                                keyboardType:
                                    TextInputType
                                        .number,
                                decoration:
                                    inputDecoration(
                                  labelText:
                                      'Odometer',
                                  icon: Icons
                                      .speed_outlined,
                                  suffixText:
                                      'KM',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'Service Cost',
                                style:
                                    TextStyle(
                                  fontSize:
                                      13,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              TextField(
                                controller:
                                    serviceCostController,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    inputDecoration(
                                  labelText:
                                      'Cost',
                                  icon: Icons
                                      .currency_rupee_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    TextField(
                      controller:
                          serviceDescriptionController,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization:
                          TextCapitalization
                              .sentences,
                      decoration:
                          inputDecoration(
                        labelText:
                            'Enter service description',
                        icon: Icons
                            .description_outlined,
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    dateSelector(
                      title:
                          'Next Service Date',
                      value:
                          selectedNextServiceDate,
                      onChanged:
                          (value) {
                        selectedNextServiceDate =
                            value;
                      },
                      allowClear: true,
                    ),
                    if (isEditing) ...[
                      const SizedBox(
                        height: 16,
                      ),
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF8FAFC,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFE5E7EB,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            if ((editServiceData?[
                                            'created_by_name']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty)
                              Text(
                                'Created by: ${editServiceData?['created_by_name']}',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      11,
                                  color:
                                      Color(
                                    0xFF6B7280,
                                  ),
                                ),
                              ),
                            if ((editServiceData?[
                                            'created_at']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                'Created: ${formatDateTimeValue(editServiceData?['created_at'])}',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      11,
                                  color:
                                      Color(
                                    0xFF6B7280,
                                  ),
                                ),
                              ),
                            ],
                            if ((editServiceData?[
                                            'updated_at']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                'Updated: ${formatDateTimeValue(editServiceData?['updated_at'])}',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      11,
                                  color:
                                      Color(
                                    0xFF6B7280,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 25,
                    ),
                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          ElevatedButton(
                        onPressed:
                            isServiceSubmitting
                                ? null
                                : () async {
                                    final bool
                                        success =
                                        isEditing
                                            ? await updateServiceHistory()
                                            : await addServiceHistory();

                                    if (success &&
                                        bottomSheetContext
                                            .mounted) {
                                      Navigator.pop(
                                        bottomSheetContext,
                                      );
                                    } else {
                                      setModalState(
                                        () {},
                                      );
                                    }
                                  },
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              const Color(
                            0xFFEA580C,
                          ),
                          foregroundColor:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                        child: isServiceSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Update Service'
                                    : 'Save Service',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(
      () {
        clearServiceForm();

        if (mounted) {
          setState(
            () {
              isServiceSubmitting =
                  false;
            },
          );
        }
      },
    );
  }

  // ===========================================================================
  // INPUT DECORATION
  // ===========================================================================

  InputDecoration inputDecoration({
    required String labelText,
    required IconData icon,
    String? suffixText,
    Color fillColor = const Color(0xFFF9FAFB),
  }) {
    return InputDecoration(
      hintText: labelText,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF6B7280),
        size: 20,
      ),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 12,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 1.4,
        ),
      ),
    );
  }

  // ===========================================================================
  // SNACKBARS
  // ===========================================================================

  void showSuccessSnackBar(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(0xFF16A34A),
          behavior:
              SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
        ),
      );
  }

  void showErrorSnackBar(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(0xFFDC2626),
          behavior:
              SnackBarBehavior.floating,
          content: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ===========================================================================
  // UTILITY
  // ===========================================================================

  int? parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  double parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  String formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(
          RegExp(r'\.?0+$'),
          '',
        );
  }

  String numberToApi(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  // ===========================================================================
  // TOTALS
  // ===========================================================================

  double get totalUsedKm {
    if (kmSummary.containsKey('total_used_km')) {
      return parseDouble(
        kmSummary['total_used_km'],
      );
    }

    double total = 0;

    for (final entry in kmEntries) {
      total += parseDouble(
        entry['used_km'],
      );
    }

    return total;
  }

  double get totalPetrol {
    if (kmSummary.containsKey('total_petrol')) {
      return parseDouble(
        kmSummary['total_petrol'],
      );
    }

    double total = 0;

    for (final entry in kmEntries) {
      total += parseDouble(
        entry['petrol'],
      );
    }

    return total;
  }

  Map<String, dynamic>? getVehicleKmSummary(
    int? vehicleId,
  ) {
    if (vehicleId == null) {
      return null;
    }

    for (final Map<String, dynamic> item
        in kmVehicleSummary) {
      if (parseInt(
            item['vehicle_id'],
          ) ==
          vehicleId) {
        return item;
      }
    }

    return null;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(
        242,
        255,
        255,
        255,
      ),

      // =======================================================================
      // APP BAR
      // =======================================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor:
            Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            _navigateBack();
          },
        ),

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    Color(0xFF111827),
              ),
            ),
            Text(
              'Vehicle & KM Tracking',
              style: TextStyle(
                fontSize: 11,
                color:
                    Color(0xFF6B7280),
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              await getVehicles();
              await getKmEntries();
              await getServiceHistory();
            },
            icon: const Icon(
              Icons.refresh,
            ),
          ),

          PopupMenuButton<String>(
            icon: Image.asset(
              'lib/assets/profile.png',
              width: 30,
              height: 30,
            ),
            onSelected: (value) {
              if (value == 'logout') {
                logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      'Logout',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            width: 5,
          ),
        ],
      ),

      // =======================================================================
      // BODY
      // =======================================================================

      body: Column(
        children: [
          // ===================================================================
          // SUMMARY CARDS
          // ===================================================================

          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.fromLTRB(
              15,
              10,
              15,
              15,
            ),
            child: Row(
              children: [
                Expanded(
                  child: summaryCard(
                    title: 'Vehicles',
                    value:
                        vehicles.length.toString(),
                    icon: Icons
                        .directions_car_filled,
                    backgroundColor:
                        const Color(
                      0xFFEFF6FF,
                    ),
                    iconColor:
                        const Color(
                      0xFF2563EB,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: summaryCard(
                    title: 'Total KM',
                    value:
                        formatNumber(
                      totalUsedKm,
                    ),
                    icon:
                        Icons.route,
                    backgroundColor:
                        const Color(
                      0xFFECFDF5,
                    ),
                    iconColor:
                        const Color(
                      0xFF059669,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: summaryCard(
                    title: 'Petrol',
                    value:
                        formatNumber(
                      totalPetrol,
                    ),
                    icon: Icons
                        .local_gas_station,
                    backgroundColor:
                        const Color(
                      0xFFFFF7ED,
                    ),
                    iconColor:
                        const Color(
                      0xFFEA580C,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===================================================================
          // TAB
          // ===================================================================

          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.fromLTRB(
              15,
              0,
              15,
              15,
            ),
            child: Container(
              padding:
                  const EdgeInsets.all(
                4,
              ),
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF3F4F6,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: tabButton(
                      index: 0,
                      text: 'Vehicles',
                      icon: Icons
                          .directions_car_outlined,
                    ),
                  ),
                  Expanded(
                    child: tabButton(
                      index: 1,
                      text: 'KM Entries',
                      icon: Icons
                          .speed_outlined,
                    ),
                  ),
                  Expanded(
                    child: tabButton(
                      index: 2,
                      text: 'Service',
                      icon: Icons
                          .build_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===================================================================
          // TAB BODY
          // ===================================================================

          Expanded(
            child: selectedTab == 0
                ? buildVehiclesSection()
                : selectedTab == 1
                    ? buildKmSection()
                    : buildServiceSection(),
          ),
        ],
      ),

      // =======================================================================
      // FLOATING BUTTON
      // =======================================================================

      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor:
            selectedTab == 0
                ? const Color(
                    0xFF2563EB,
                  )
                : selectedTab == 1
                    ? const Color(
                        0xFF059669,
                      )
                    : const Color(
                        0xFFEA580C,
                      ),
        foregroundColor:
            Colors.white,
        onPressed: () {
          if (selectedTab == 0) {
            openVehicleForm();
          } else if (selectedTab == 1) {
            openKmForm();
          } else {
            openServiceForm();
          }
        },
        icon: const Icon(
          Icons.add,
        ),
        label: Text(
          selectedTab == 0
              ? 'Add Vehicle'
              : selectedTab == 1
                  ? 'Add KM Entry'
                  : 'Add Service',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUMMARY CARD
  // ===========================================================================

  Widget summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor,
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF111827),
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
              color:
                  Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB BUTTON
  // ===========================================================================

  Widget tabButton({
    required int index,
    required String text,
    required IconData icon,
  }) {
    bool selected =
        selectedTab == index;

    return InkWell(
      borderRadius:
          BorderRadius.circular(
        10,
      ),
      onTap: () {
        FocusScope.of(context)
            .unfocus();

        setState(() {
          selectedTab = index;
        });
      },
      child: Container(
        decoration:
            BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(
                      0.05,
                    ),
                    blurRadius: 5,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? const Color(
                      0xFF111827,
                    )
                  : const Color(
                      0xFF6B7280,
                    ),
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.w600,
                color: selected
                    ? const Color(
                        0xFF111827,
                      )
                    : const Color(
                        0xFF6B7280,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VEHICLES SECTION
  // ===========================================================================

  Widget buildVehiclesSection() {
    return RefreshIndicator(
      onRefresh: getVehicles,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          15,
          15,
          15,
          100,
        ),
        children: [
          // ===================================================================
          // SEARCH
          // ===================================================================

          TextField(
            controller:
                vehicleSearchController,
            onChanged:
                searchVehicles,
            decoration:
                InputDecoration(
              hintText:
                  'Search vehicle, model or registration...',
              prefixIcon:
                  const Icon(
                Icons.search,
              ),
              suffixIcon:
                  vehicleSearchController
                          .text
                          .isNotEmpty
                      ? IconButton(
                          onPressed:
                              () {
                            vehicleSearchController
                                .clear();

                            searchVehicles(
                              '',
                            );
                          },
                          icon:
                              const Icon(
                            Icons.close,
                          ),
                        )
                      : null,
              filled: true,
              fillColor:
                  Colors.white,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color: Color(
                    0xFFE5E7EB,
                  ),
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color: Color(
                    0xFFE5E7EB,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          if (isVehicleLoading)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 80,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (filteredVehicles
              .isEmpty)
            emptyState(
              icon: Icons
                  .directions_car_outlined,
              title:
                  'No vehicles found',
              subtitle:
                  'Add your first vehicle to start KM tracking.',
            )
          else
            for (int i = 0;
                i <
                    filteredVehicles
                        .length;
                i++)
              vehicleCard(
                filteredVehicles[i],
              ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VEHICLE CARD
  // ===========================================================================

  Widget vehicleCard(
    Map<String, dynamic> vehicle,
  ) {
    int? vehicleId = parseInt(
      vehicle['id'],
    );

    final Map<String, dynamic>? vehicleKmSummary =
        getVehicleKmSummary(
      vehicleId,
    );

    int entryCount = parseInt(
          vehicleKmSummary?['total_entries'],
        ) ??
        kmEntries
            .where(
              (entry) =>
                  parseInt(
                    entry['vehicle'],
                  ) ==
                  vehicleId,
            )
            .length;

    double vehicleKm;

    if (vehicleKmSummary != null &&
        vehicleKmSummary.containsKey(
          'total_used_km',
        )) {
      vehicleKm = parseDouble(
        vehicleKmSummary['total_used_km'],
      );
    } else {
      vehicleKm = 0;

      for (final entry in kmEntries) {
        if (parseInt(
              entry['vehicle'],
            ) ==
            vehicleId) {
          vehicleKm += parseDouble(
            entry['used_km'],
          );
        }
      }
    }

    final String vehicleName =
        vehicle['name']?.toString().trim() ?? '';

    final String registration =
        vehicle['registration_number']?.toString().trim() ?? '';

    final String model =
        vehicle['model']?.toString().trim() ?? '';

    final String imageUrl =
        vehicle['image']?.toString().trim() ?? '';

    final String createdBy =
        vehicle['created_by']?.toString().trim() ?? '';

    final String updatedAt =
        formatDateTimeValue(vehicle['updated_at']);

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        openVehicleForm(
          vehicle: vehicle,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 12,
        ),
        padding: const EdgeInsets.all(
          15,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            15,
          ),
          border: Border.all(
            color: const Color(
              0xFFE5E7EB,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: const Color(
                      0xFFEFF6FF,
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            loadingBuilder: (
                              context,
                              child,
                              loadingProgress,
                            ) {
                              if (loadingProgress == null) {
                                return child;
                              }

                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              debugPrint(
                                'VEHICLE CARD IMAGE LOAD ERROR: '
                                '$imageUrl - $error',
                              );

                              return const Icon(
                                Icons.directions_car_filled,
                                color: Color(
                                  0xFF2563EB,
                                ),
                                size: 29,
                              );
                            },
                          )
                        : const Icon(
                            Icons.directions_car_filled,
                            color: Color(
                              0xFF2563EB,
                            ),
                            size: 29,
                          ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName.isNotEmpty
                            ? vehicleName
                            : 'Unnamed Vehicle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(
                            0xFF111827,
                          ),
                        ),
                      ),

                      if (model.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],

                      if (registration.isNotEmpty) ...[
                        const SizedBox(
                          height: 7,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF3F4F6,
                            ),
                            borderRadius: BorderRadius.circular(
                              6,
                            ),
                          ),
                          child: Text(
                            registration,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Edit Vehicle',
                  onPressed: () {
                    openVehicleForm(
                      vehicle: vehicle,
                    );
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(
                      0xFF6B7280,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$entryCount entries',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${formatNumber(vehicleKm)} KM',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  if (createdBy.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          createdBy,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            if (updatedAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Updated $updatedAt',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // KM SECTION
  // ===========================================================================

  Widget buildKmSection() {
    return RefreshIndicator(
      onRefresh: () async {
        await getVehicles();
        await getKmEntries();
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          15,
          15,
          15,
          100,
        ),
        children: [
          TextField(
            controller:
                kmSearchController,
            onChanged:
                searchKmEntries,
            decoration:
                InputDecoration(
              hintText:
                  'Search KM entries...',
              prefixIcon:
                  const Icon(
                Icons.search,
              ),
              suffixIcon:
                  kmSearchController
                          .text
                          .isNotEmpty
                      ? IconButton(
                          onPressed:
                              () {
                            kmSearchController
                                .clear();

                            searchKmEntries(
                              '',
                            );
                          },
                          icon:
                              const Icon(
                            Icons.close,
                          ),
                        )
                      : null,
              filled: true,
              fillColor:
                  Colors.white,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color: Color(
                    0xFFE5E7EB,
                  ),
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color: Color(
                    0xFFE5E7EB,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          if (isKmLoading)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 80,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (filteredKmEntries
              .isEmpty)
            emptyState(
              icon:
                  Icons.speed_outlined,
              title:
                  'No KM entries found',
              subtitle:
                  'Add your first KM entry.',
            )
          else ...[
            for (int i = 0;
                i <
                    filteredKmEntries
                        .length;
                i++)
              kmEntryCard(
                filteredKmEntries[i],
              ),

            if (kmPreviousUrl != null ||
                kmNextUrl != null ||
                kmTotalCount >
                    filteredKmEntries.length)
              buildKmPagination(),
          ],
        ],
      ),
    );
  }

  Widget buildKmPagination() {
    return Container(
      margin: const EdgeInsets.only(
        top: 4,
        bottom: 8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: kmPreviousUrl == null ||
                      isKmPageLoading
                  ? null
                  : loadPreviousKmPage,
              icon: const Icon(
                Icons.chevron_left,
                size: 19,
              ),
              label: const Text(
                'Previous',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size(
                  0,
                  42,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              children: [
                if (isKmPageLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
                  Text(
                    'Page $kmCurrentPage',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(
                        0xFF111827,
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '$kmTotalCount entries',
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        Color(
                      0xFF6B7280,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: OutlinedButton.icon(
              onPressed: kmNextUrl == null ||
                      isKmPageLoading
                  ? null
                  : loadNextKmPage,
              icon: const Icon(
                Icons.chevron_right,
                size: 19,
              ),
              label: const Text(
                'Next',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size(
                  0,
                  42,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KM ENTRY CARD
  // ===========================================================================

  Widget kmEntryCard(
    Map<String, dynamic> entry,
  ) {
    String vehicleName =
        getVehicleName(
      entry,
    );

    String registration =
        getVehicleRegistration(
      entry,
    );

    DateTime? date =
        DateTime.tryParse(
      entry['date']?.toString() ?? '',
    );

    String formattedDate =
        date != null
            ? DateFormat(
                'dd-MM-yyyy',
              ).format(
                date,
              )
            : entry['date']
                    ?.toString() ??
                '';

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFECFDF5,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.speed,
                  color:
                      Color(
                    0xFF059669,
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleName,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      registration
                              .isNotEmpty
                          ? '$registration • $formattedDate'
                          : formattedDate,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            Color(
                          0xFF6B7280,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip:
                    'Edit KM Entry',
                onPressed: () {
                  openKmForm(
                    entry: entry,
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  color:
                      Color(
                    0xFF6B7280,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF9FAFB,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: kmValue(
                    title:
                        'Starting',
                    value:
                        '${formatNumber(parseDouble(entry['starting_km']))} KM',
                  ),
                ),

                Container(
                  width: 1,
                  height: 30,
                  color:
                      const Color(
                    0xFFE5E7EB,
                  ),
                ),

                Expanded(
                  child: kmValue(
                    title:
                        'Ending',
                    value:
                        '${formatNumber(parseDouble(entry['end_km']))} KM',
                  ),
                ),

                Container(
                  width: 1,
                  height: 30,
                  color:
                      const Color(
                    0xFFE5E7EB,
                  ),
                ),

                Expanded(
                  child: kmValue(
                    title:
                        'Used',
                    value:
                        '${formatNumber(parseDouble(entry['used_km']))} KM',
                    valueColor:
                        const Color(
                      0xFF059669,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .local_gas_station_outlined,
                size: 18,
                color:
                    Color(
                  0xFFEA580C,
                ),
              ),

              const SizedBox(
                width: 6,
              ),

              const Text(
                'Petrol',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Color(
                    0xFF6B7280,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                formatNumber(
                  parseDouble(
                    entry['petrol'],
                  ),
                ),
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KM VALUE
  // ===========================================================================

  Widget kmValue({
    required String title,
    required String value,
    Color valueColor =
        const Color(0xFF111827),
  }) {
    return Column(
      children: [
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 10,
            color:
                Color(
              0xFF9CA3AF,
            ),
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          value,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }


  // ===========================================================================
  // SERVICE HISTORY SECTION
  // ===========================================================================

  Widget buildServiceSection() {
    return RefreshIndicator(
      onRefresh: () async {
        await getVehicles();
        await getServiceHistory();
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          15,
          15,
          15,
          100,
        ),
        children: [
          TextField(
            controller:
                serviceSearchController,
            onChanged:
                searchServiceHistory,
            decoration:
                InputDecoration(
              hintText:
                  'Search service history...',
              prefixIcon:
                  const Icon(
                Icons.search,
              ),
              suffixIcon:
                  serviceSearchController
                          .text
                          .isNotEmpty
                      ? IconButton(
                          onPressed:
                              () {
                            serviceSearchController
                                .clear();

                            searchServiceHistory(
                              '',
                            );
                          },
                          icon:
                              const Icon(
                            Icons.close,
                          ),
                        )
                      : null,
              filled: true,
              fillColor:
                  Colors.white,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(
                    0xFFE5E7EB,
                  ),
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(
                    0xFFE5E7EB,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          if (isServiceLoading)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 80,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (filteredServiceHistory
              .isEmpty)
            emptyState(
              icon:
                  Icons.build_outlined,
              title:
                  'No service history found',
              subtitle:
                  'Add the first vehicle service record.',
            )
          else
            for (int i = 0;
                i <
                    filteredServiceHistory
                        .length;
                i++)
              serviceHistoryCard(
                filteredServiceHistory[i],
              ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SERVICE HISTORY CARD
  // ===========================================================================

  Widget serviceHistoryCard(
    Map<String, dynamic> service,
  ) {
    final String vehicleName =
        getServiceVehicleName(
      service,
    );

    final String registration =
        getServiceVehicleRegistration(
      service,
    );

    final String serviceType =
        service['service_type']
                ?.toString()
                .trim() ??
            '';

    final String serviceCenter =
        service['service_center']
                ?.toString()
                .trim() ??
            '';

    final String description =
        service['description']
                ?.toString()
                .trim() ??
            '';

    final int? odometer =
        parseInt(
      service['odometer_km'],
    );

    final dynamic rawServiceCost =
        service['service_cost'];

    final double? serviceCost =
        rawServiceCost == null ||
                rawServiceCost.toString().trim().isEmpty ||
                rawServiceCost.toString().toLowerCase() == 'null'
            ? null
            : parseDouble(
                rawServiceCost,
              );

    final DateTime? serviceDate =
        DateTime.tryParse(
      service['service_date']
              ?.toString() ??
          '',
    );

    final DateTime? nextServiceDate =
        DateTime.tryParse(
      service['next_service_date']
              ?.toString() ??
          '',
    );

    final String formattedServiceDate =
        serviceDate == null
            ? (service['service_date']
                    ?.toString() ??
                '')
            : DateFormat(
                'dd-MM-yyyy',
              ).format(
                serviceDate,
              );

    final String formattedNextDate =
        nextServiceDate == null
            ? ''
            : DateFormat(
                'dd-MM-yyyy',
              ).format(
                nextServiceDate,
              );

    final String createdBy =
        service['created_by_name']
                ?.toString()
                .trim() ??
            '';

    final String updatedAt =
        formatDateTimeValue(
      service['updated_at'],
    );

    return InkWell(
      borderRadius:
          BorderRadius.circular(
        15,
      ),
      onTap: () {
        debugPrint(
          'SERVICE CARD TAPPED: $service',
        );

        openServiceForm(
          service: service,
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.all(
          15,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          border: Border.all(
            color:
                const Color(
              0xFFE5E7EB,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFFFF7ED,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .build_circle_outlined,
                    color:
                        Color(
                      0xFFEA580C,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        vehicleName,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Color(
                            0xFF111827,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        [
                          registration,
                          formattedServiceDate,
                        ]
                            .where(
                              (value) =>
                                  value
                                      .trim()
                                      .isNotEmpty,
                            )
                            .join(
                              ' • ',
                            ),
                        style:
                            const TextStyle(
                          fontSize: 11,
                          color:
                              Color(
                            0xFF6B7280,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:
                      'Edit Service',
                  onPressed: () {
                    debugPrint(
                      'SERVICE CARD EDIT CLICKED: $service',
                    );

                    openServiceForm(
                      service: service,
                    );
                  },
                  icon:
                      const Icon(
                    Icons
                        .edit_outlined,
                    color:
                        Color(
                      0xFF6B7280,
                    ),
                  ),
                ),
              ],
            ),
            if (serviceType.isNotEmpty ||
                serviceCenter
                    .isNotEmpty) ...[
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  if (serviceType
                      .isNotEmpty)
                    Expanded(
                      child:
                          serviceInfoBox(
                        title:
                            'Service Type',
                        value:
                            serviceType,
                        icon: Icons
                            .build_outlined,
                      ),
                    ),
                  if (serviceType
                          .isNotEmpty &&
                      serviceCenter
                          .isNotEmpty)
                    const SizedBox(
                      width: 10,
                    ),
                  if (serviceCenter
                      .isNotEmpty)
                    Expanded(
                      child:
                          serviceInfoBox(
                        title:
                            'Service Center',
                        value:
                            serviceCenter,
                        icon: Icons
                            .location_city_outlined,
                      ),
                    ),
                ],
              ),
            ],
            if (odometer != null ||
                serviceCost != null) ...[
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        serviceInfoBox(
                      title:
                          'Odometer',
                      value: odometer ==
                              null
                          ? '-'
                          : '$odometer KM',
                      icon: Icons
                          .speed_outlined,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child:
                        serviceInfoBox(
                      title:
                          'Service Cost',
                      value:
                          serviceCost == null
                              ? '-'
                              : '₹${formatNumber(serviceCost)}',
                      icon: Icons
                          .currency_rupee_outlined,
                    ),
                  ),
                ],
              ),
            ],
            if (description
                .isNotEmpty) ...[
              const SizedBox(
                height: 12,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF9FAFB,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
                child: Text(
                  description,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color:
                        Color(
                      0xFF4B5563,
                    ),
                  ),
                ),
              ),
            ],
            if (formattedNextDate
                .isNotEmpty) ...[
              const SizedBox(
                height: 12,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFFFBEB,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFFFDE68A,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .event_repeat_outlined,
                      size: 17,
                      color:
                          Color(
                        0xFFD97706,
                      ),
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    const Text(
                      'Next Service',
                      style:
                          TextStyle(
                        fontSize: 11,
                        color:
                            Color(
                          0xFF92400E,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formattedNextDate,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .bold,
                        color:
                            Color(
                          0xFF92400E,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (createdBy.isNotEmpty ||
                updatedAt
                    .isNotEmpty) ...[
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  if (createdBy
                      .isNotEmpty) ...[
                    const Icon(
                      Icons
                          .person_outline,
                      size: 14,
                      color:
                          Color(
                        0xFF9CA3AF,
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Expanded(
                      child: Text(
                        createdBy,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 9,
                          color:
                              Color(
                            0xFF9CA3AF,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (updatedAt
                      .isNotEmpty)
                    Text(
                      'Updated $updatedAt',
                      style:
                          const TextStyle(
                        fontSize: 9,
                        color:
                            Color(
                          0xFF9CA3AF,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget serviceInfoBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        11,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF9FAFB,
        ),
        borderRadius:
            BorderRadius.circular(
          11,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
                const Color(
              0xFF9CA3AF,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        Color(
                      0xFF9CA3AF,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight
                            .bold,
                    color:
                        Color(
                      0xFF111827,
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

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 70,
        left: 25,
        right: 25,
      ),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF3F4F6,
              ),
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
            ),
            child: Icon(
              icon,
              size: 35,
              color:
                  const Color(
                0xFF9CA3AF,
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            title,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF6B7280,
              ),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}