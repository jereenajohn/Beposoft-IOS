import 'dart:convert';
import 'package:beposoft/audit/audit_new_service.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/add_attribute.dart';
import 'package:beposoft/pages/ACCOUNTS/add_company.dart';
import 'package:beposoft/pages/ACCOUNTS/add_department.dart';
import 'package:beposoft/pages/ACCOUNTS/add_family.dart';
import 'package:beposoft/pages/ACCOUNTS/add_services.dart';
import 'package:beposoft/pages/ACCOUNTS/add_state.dart';
import 'package:beposoft/pages/ACCOUNTS/add_supervisor.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ACCOUNTS/new_performa_products.dart';
import 'package:beposoft/pages/ACCOUNTS/order_products.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_order_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'package:beposoft/pages/ACCOUNTS/add_bank.dart';
import 'package:beposoft/pages/ACCOUNTS/new_grv.dart';
import 'package:beposoft/pages/ACCOUNTS/transfer.dart';

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
import 'package:beposoft/pages/api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';

class proforma_to_order_request extends StatefulWidget {
  var invoice;
  proforma_to_order_request({super.key, required this.invoice});

  @override
  State<proforma_to_order_request> createState() =>
      _proforma_to_order_requestState();
}

class _proforma_to_order_requestState extends State<proforma_to_order_request> {
  // Diagnostic output only; business logic and API payloads are unchanged.
  void _printDetails(String label, dynamic value) {
    if (!kDebugMode) return;
    String output;
    try {
      output = JsonEncoder.withIndent('  ', (item) => item.toString())
          .convert(value);
    } catch (_) {
      output = value.toString();
    }
    debugPrint('[PROFORMA CONVERSION] $label');
    // Chunk long lines so large product responses remain readable in logs.
    for (final line in output.split('\n')) {
      if (line.isEmpty) {
        debugPrint('');
        continue;
      }
      for (int start = 0; start < line.length; start += 800) {
        final end = start + 800 < line.length ? start + 800 : line.length;
        debugPrint(line.substring(start, end));
      }
    }
    debugPrint('[PROFORMA CONVERSION] END $label');
  }

  Future<http.Response> _debugGet(Uri uri, {
    Map<String, String>? headers,
  }) async {
    _printDetails('GET REQUEST', {
      'url': uri.toString(),
      'headers': {
        for (final entry in (headers ?? <String, String>{}).entries)
          entry.key: entry.key.toLowerCase() == 'authorization'
              ? '[REDACTED]' : entry.value,
      },
    });
    try {
      final response = await http.get(uri, headers: headers);
      _printDetails('GET RESPONSE', {
        'url': uri.toString(),
        'status_code': response.statusCode,
        'body': _auditResponseData(response),
      });
      return response;
    } catch (error, stackTrace) {
      _printDetails('GET ERROR', {
        'url': uri.toString(),
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  Map<String, dynamic> _loadedAuditOrder = <String, dynamic>{};

  dynamic _auditCopy(dynamic value) {
    // Detach the snapshot before any asynchronous request or UI refresh.
    return jsonDecode(jsonEncode(value, toEncodable: (value) => value.toString()));
  }

  Map<String, dynamic> _auditSnapshot() {
    return Map<String, dynamic>.from(_auditCopy(<String, dynamic>{
      'proforma_invoice': widget.invoice,
      'loaded_proforma_response': _loadedAuditOrder,
      'proforma_details': orders,
    }) as Map);
  }

  int? _createdOrderId(dynamic data) {
    if (data is! Map) return null;
    final nestedData = data['data'];
    final nestedOrder = data['order'];
    final value = data['order_id'] ?? data['id'] ??
        (nestedOrder is Map ? nestedOrder['id'] ?? nestedOrder['order_id'] : null) ??
        (nestedData is Map ? nestedData['order_id'] ?? nestedData['id'] : null);
    return int.tryParse(value?.toString() ?? '');
  }

  dynamic _auditResponseData(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  Future<void> _recordMutation({
    required String action,
    required String method,
    required Uri uri,
    required Map<String, dynamic> before,
    required dynamic submitted,
    http.Response? response,
    Object? error,
  }) async {
    // Keep logging errors separate from the completed business operation.
    try {
      final successful = response != null &&
          response.statusCode >= 200 && response.statusCode < 300;
      final logged = await AuditLogService.log(
        action: successful ? action : '${action}_failed',
        orderId: action == 'order_created_from_proforma' && successful
            ? _createdOrderId(_auditResponseData(response!)) : null,
        beforeData: before,
        afterData: <String, dynamic>{
          'proforma_invoice': widget.invoice,
          if (action == 'order_created_from_proforma' && successful)
            'created_order_id': _createdOrderId(_auditResponseData(response!)),
          'submitted_data': submitted,
          if (action == 'order_created_from_proforma' && successful)
            'product_details': before['conversion_product_details'],
          'response_data': response == null ? null : _auditResponseData(response),
          'outcome': successful ? 'success' : 'failed',
          if (method == 'DELETE' && successful) 'deleted': true,
          if (error != null) 'error_type': error.runtimeType.toString(),
          'metadata': <String, dynamic>{
            'source': 'proforma_to_order_request',
            'method': method,
            'endpoint': uri.path,
            if (response != null) 'http_status': response.statusCode,
            'recorded_at': DateTime.now().toUtc().toIso8601String(),
            // submitted_data is the request, response_data is server output.
            // Do not pretend a partial response is a full refreshed record.
          },
        },
      );
      if (!logged) debugPrint('Audit log creation failed [$action].');
    } catch (auditError, stackTrace) {
      debugPrint('Audit log creation failed [$action]: $auditError');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<http.Response> _auditMultipart(http.MultipartRequest request, String action) async {
    final before = _auditSnapshot();
    if (action == 'order_created_from_proforma') {
      // Capture saved proforma products before conversion deletes the proforma.
      // Keep product snapshots separate from the unmodified API response.
      before['conversion_product_details'] = _auditCopy(<String, dynamic>{
        'source': 'pre_conversion_snapshot',
        'proforma_items': _loadedAuditOrder['perfoma_items'] ??
            perfomaItemsWithImages,
      });
    }
    final submitted = <String, dynamic>{
      'fields': Map<String, String>.from(request.fields),
      'proforma_payment_slip_ids': proformaPaymentSlips
          .map((slip) => slip['id']).where((id) => id != null).toList(),
      'files': request.files.map((file) => <String, dynamic>{
        'field': file.field,
        'filename': file.filename,
        'size_bytes': file.length,
        'content_type': file.contentType.toString(),
      }).toList(),
    };
    _printDetails('CONVERSION REQUEST', {
      'method': request.method,
      'url': request.url.toString(),
      'fields_and_file_metadata': submitted,
      'before_snapshot': before,
      'existing_payment_slips': proformaPaymentSlips,
      // File contents and authorization credentials are intentionally excluded.
    });
    late final http.Response response;
    try {
      response = await http.Response.fromStream(await request.send());
      _printDetails('CONVERSION RESPONSE', {
        'url': request.url.toString(),
        'status_code': response.statusCode,
        'body': _auditResponseData(response),
      });
    } catch (error) {
      _printDetails('PAGE ERROR', error.toString());
      await _recordMutation(action: action,
          method: 'POST', uri: request.url, before: before,
          submitted: submitted, error: error);
      rethrow;
    }
    await _recordMutation(action: action,
        method: 'POST', uri: request.url, before: before,
        submitted: submitted, response: response);
    return response;
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

  List<Map<String, dynamic>> products = [];
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> filteredProducts = [];
  List<Map<String, dynamic>> manager = [];
  String selectmanager = "jeshiya";
  List<String> address = [
    "empty",
  ];
  String selectaddress = "empty";
  List<Map<String, dynamic>> fam = [];
  List<Map<String, dynamic>> customer = [];
  List<Map<String, dynamic>> warehousecusomer1 = [];
  String selectcodtype = "select type";
  List<String> codtype = [
    "select type",
    "FULL_COD",
    'PARTIAL_COD',
  ];
  final TextEditingController codamountcontroller = TextEditingController();
  final TextEditingController advancecodamount = TextEditingController();
  List<Map<String, dynamic>> warehousecusomer2 = [];

  List<Map<String, dynamic>> variant = [];
  int? selectedFamilyId;
  int? selectedCompanyId;
  int? selectedwarehouseId; // Variable to store the selected department's ID
  String? selectedwarehouseName;

  var Discount;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> stat = [];

  int? selectedbankId;
  String selectedstaff = '';
  int? selectedstaffId;
  int? selectedstateId;
  int? selectedAddressId; // Variable to store the selected address ID
  String? selectedAddressName; // Variable to store the selected address name
  List<Map<String, dynamic>> bank = [];

  List<Map<String, dynamic>> courierdata = [];
  int? selectedCourierServiceId;
  final TextEditingController parcelServiceNoteController =
      TextEditingController();
final TextEditingController accountsNoteController =
    TextEditingController();
  double total = 0.0;
  Set<int> expandedRows = {};
  var famid;
  var staffid;

  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> paymentReceiptImages = [];
  bool isCreatingOrder = false;
  List<Map<String, dynamic>> proformaPaymentSlips = [];
  bool _isLoadingConversionData = true;
  String? _conversionDataError;
  bool _proformaReady = false;

  bool get _hasExistingPaymentSlip => proformaPaymentSlips.any(
      (slip) => slip['id'] != null && _existingPaymentSlipUrl(slip) != null);

  bool get _isFullCOD =>
      selectpaystatus == 'COD' && selectcodtype == 'FULL_COD';

  Future<void> _fetchProformaPaymentSlips(dynamic proformaId) async {
    final token = await gettokenFromPrefs();
    final response = await _debugGet(
      Uri.parse('$api/api/perfoma/payment/slips/$proformaId/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to load existing proforma payment slips.');
    }
    final decoded = jsonDecode(response.body);
    final dynamic slips = decoded is List
        ? decoded
        : decoded is Map ? decoded['data'] ?? decoded['results'] : null;
    if (slips is! List) {
      throw Exception('Invalid proforma payment slips response.');
    }
    if (!mounted) return;
    setState(() {
      proformaPaymentSlips = slips.whereType<Map>().map((item) =>
          Map<String, dynamic>.from(item as Map))
          .where((slip) => slip['id'] != null &&
              _existingPaymentSlipUrl(slip) != null).toList();
    });
  }

  String? _existingPaymentSlipUrl(Map<String, dynamic> slip) {
    dynamic value = slip['file_url'] ?? slip['image_url'] ??
        slip['file'] ?? slip['image'] ?? slip['payment_slip'] ??
        slip['slip'] ?? slip['url'];
    if (value is Map) value = value['url'] ?? value['file'] ?? value['image'];
    if (value is! String || value.trim().isEmpty) return null;
    final base = Uri.tryParse('${api.toString().replaceFirst(RegExp(r'/+$'), '')}/');
    final uri = base?.resolve(value.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.toString();
  }

  Widget _existingPaymentSlipImage(String? url, {bool expanded = false}) {
    if (url == null) {
      return const Center(child: Icon(Icons.broken_image_outlined,
          color: Color(0xFF98A2B3)));
    }
    return Image.network(
      url,
      fit: expanded ? BoxFit.contain : BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF98A2B3)),
      ),
    );
  }

  void _previewExistingPaymentSlip(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(dialogContext).size.height * 0.75,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: _existingPaymentSlipImage(url, expanded: true),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingPaymentSlipPreviews() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: proformaPaymentSlips.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final url = _existingPaymentSlipUrl(proformaPaymentSlips[index]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: url == null ? null : () => _previewExistingPaymentSlip(url),
                  child: _existingPaymentSlipImage(url),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'From Proforma • ${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF027A48)),
            ),
          ],
        );
      },
    );
  }

  String? _conversionValidationError() {
    if (_isLoadingConversionData) return 'Please wait for proforma data to load.';
    if (_conversionDataError != null) return _conversionDataError;
    if (!_proformaReady || perfomaItemsWithImages.isEmpty) {
      return 'Proforma products are not ready.';
    }
    if (paymentReceiptImages.isEmpty &&
        !_hasExistingPaymentSlip) {
      return 'At least one payment slip is required.';
    }
    if (selectpaystatus == 'Paid' || selectpaystatus == 'credit') {
      if (selectpaymethod.isEmpty) return 'Please select a payment method.';
      if (selectedbankId == null) return 'Please select a bank.';
    }
    if (selectpaystatus == 'COD') {
      if (selectcodtype != 'FULL_COD' && selectcodtype != 'PARTIAL_COD') {
        return 'Please select COD type.';
      }
      final amount = double.tryParse(codamountcontroller.text.trim());
      if (amount == null || !amount.isFinite || amount < 0) {
        return 'Please enter a valid COD amount.';
      }
      if (selectcodtype == 'PARTIAL_COD') {
        final advance = double.tryParse(advancecodamount.text.trim());
        if (advance == null || !advance.isFinite || advance < 0) {
          return 'Please enter a valid Advance COD amount.';
        }
      }
    }
    return null;
  }

  String _conversionErrorMessage(dynamic value) {
    if (value is List) {
      return value.map((item) {
        if (item is Map && item['message'] != null) {
          return '${item['product_name'] ?? item['product_id'] ?? 'Product'}: ${item['message']}';
        }
        return _conversionErrorMessage(item);
      }).join(' | ');
    }
    if (value is Map) {
      if (value['errors'] != null) return _conversionErrorMessage(value['errors']);
      return value.entries.map((entry) =>
          '${entry.key}: ${_conversionErrorMessage(entry.value)}').join(' | ');
    }
    return value?.toString() ?? 'Order creation failed.';
  }
  bool _isConversionDialogOpen = false;
  final ValueNotifier<bool> _conversionBusy = ValueNotifier<bool>(false);


  Future<void> _selectPaymentReceiptImages() async {
    final List<XFile> selectedImages =
        await _imagePicker.pickMultiImage(
      imageQuality: 85,
    );

    if (selectedImages.isEmpty || !mounted) return;

    setState(() {

      for (final image in selectedImages) {
        final alreadyAdded = paymentReceiptImages.any(
          (existingImage) => existingImage.path == image.path,
        );

        if (!alreadyAdded) {
          paymentReceiptImages.add(image);
        }
      }
    });
  }

  void _removePaymentReceiptImage(int index) {
    if (index < 0 || index >= paymentReceiptImages.length) return;

    setState(() {
      paymentReceiptImages.removeAt(index);
    });
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

  @override
  void initState() {
    super.initState();
    initdata();
  }

  var dep;
  void initdata() async {
    dep = await getdepFromPrefs();
    if (!mounted) return;

    selectedFamilyId = famid;

    selectedstaffId = staffid;

    searchController.addListener(() {});
    getstate();
    getcourierservices();

    getbank();
    fetchperformalistData();
  }

  Future<void> getcourierservices() async {
    try {
      final token = await gettokenFromPrefs();

      final response = await _debugGet(
        Uri.parse('$api/api/parcal/service/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);

        final List<Map<String, dynamic>> courierList = [];

        if (parsed is Map &&
            parsed['data'] != null &&
            parsed['data'] is List) {
          for (final dynamic item in parsed['data']) {
            courierList.add({
              'id': item['id'],
              'name': item['name'],
            });
          }
        }

        if (!mounted) return;

        setState(() {
          courierdata = courierList;
        });
      } else {
        debugPrint(
          'Courier service fetch failed: '
          '${response.statusCode} - ${response.body}',
        );
      }
    } catch (error) {
      _printDetails('PAGE ERROR', error.toString());
      debugPrint('Courier service fetch error: $error');
    }
  }

  Future<void> getstate() async {
    try {
      final token = await gettokenFromPrefs();
      var response = await _debugGet(
        Uri.parse('$api/api/states/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        List<Map<String, dynamic>> statelist = productsData
            .map<Map<String, dynamic>>((productData) => {
                  'id': productData['id'],
                  'name': productData['name'],
                })
            .toList();

        if (!mounted) return;
        setState(() {
          stat = statelist;
        });
      }
    } catch (error) {
      _printDetails('PAGE ERROR', error.toString());}
  }

  String getStateNameById(int stateId) {
    final state = stat.firstWhere(
      (element) => element['id'] == stateId,
      orElse: () => {'name': 'Unknown'}, // Return a Map with a default 'name'
    );
    return state['name'];
  }

  List<Map<String, dynamic>> perfomaItemsWithImages = [];
  Future<void> fetchperformalistData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingConversionData = true;
      _conversionDataError = null;
      _proformaReady = false;
    });
    try {
      final token = await gettokenFromPrefs();
      final response = await _debugGet(
        Uri.parse('$api/api/perfoma/${widget.invoice}/invoice/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        _loadedAuditOrder = Map<String, dynamic>.from(_auditCopy(parsed) as Map);

        List<Map<String, dynamic>> performaInvoiceList = [];

        perfomaItemsWithImages =
            (parsed['perfoma_items'] as List<dynamic>?)?.map((item) {
                  return {
                    'id': item['id'],
                    'product': item['product'],
                    'name': item['name'],
                    'quantity': item['quantity'],
                    'actual_price': item['rate'],
                    'first_image': item['images'],
                    'discount': item['discount'],
                  };
                }).toList() ??
                [];

        if (perfomaItemsWithImages.isEmpty) {
          throw Exception('No proforma products available to convert.');
        }
        for (final item in perfomaItemsWithImages) {
          final quantity = int.tryParse(item['quantity']?.toString() ?? '');
          if (item['product'] == null || quantity == null || quantity <= 0) {
            throw Exception('The proforma contains an invalid product or quantity.');
          }
        }
        final savedTotal = double.tryParse(parsed['total_amount']?.toString() ?? '');
        if (savedTotal == null || !savedTotal.isFinite || savedTotal < 0) {
          throw Exception('The proforma total is invalid.');
        }

        performaInvoiceList.add({
          'id': parsed['id'],
          'invoice': parsed['invoice'],
          'manage_staff': parsed['manage_staff'],
          'company': parsed['company'],
          'company_name': parsed['company_name'],
          'customer_name': parsed['customer']?['name'] ?? 'Unknown',
          'customerID': parsed['customer']?['id'] ?? 'Unknown',

          'family': parsed['family'],
          'state': parsed['state'], // Use state name instead of ID
          'address': parsed['billing_address']?['address'] ?? 'Unknown',
          'billing_id': parsed['billing_address']?['id'],
          'payment_status': parsed['payment_status'],
          'bank': parsed['bank'] is Map ? parsed['bank']['name'] : parsed['bank'],
          'payment_method': parsed['payment_method'],
          'status': parsed['status'],
          'total_amount': parsed['total_amount'],
          'order_date': parsed['order_date'],
          'created_at': parsed['customer']?['created_at'] ?? 'Unknown',
          'perfoma_items': perfomaItemsWithImages,
          'warehouse_id': parsed['warehouse_id']
        });

        if (!mounted) return;

        setState(() {
          orders = performaInvoiceList;
          _printDetails('MAPPED PROFORMA AND PRODUCTS', {
            'orders': orders,
            'products': perfomaItemsWithImages,
            'product_line_count': perfomaItemsWithImages.length,
          });
          accountsNoteController.text =
              (parsed['note'] ?? parsed['accounts_note'] ?? '').toString();
          parcelServiceNoteController.text =
              (parsed['parcel_note'] ?? parsed['parcel_service_note'] ?? '').toString();
          final courier = parsed['parcel_service'];
          selectedCourierServiceId = int.tryParse(
              (courier is Map ? courier['id'] : courier)?.toString() ?? '');
        });

        await _fetchProformaPaymentSlips(parsed['id']);
        if (mounted) setState(() => _proformaReady = true);
      } else {
        throw Exception('Unable to load proforma details.');
      }
    } catch (error) {
      _printDetails('PAGE ERROR', error.toString());
      if (mounted) setState(() => _conversionDataError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingConversionData = false);
    }
  }

  Future<void> ordercreate(
    BuildContext scaffoldContext,
  ) async {
    if (!mounted || isCreatingOrder) return;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD92D20),
          content: Text(
            'Proforma details are not loaded yet. Please try again.',
          ),
        ),
      );
      return;
    }

    final validationError = _conversionValidationError();
    _printDetails('SUBMISSION VALIDATION', {
      'error': validationError,
      'proforma_ready': _proformaReady,
      'loading': _isLoadingConversionData,
      'load_error': _conversionDataError,
      'selected_image_count': paymentReceiptImages.length,
      'existing_slip_count': proformaPaymentSlips.length,
    });
    if (validationError != null) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
      return;
    }

    // Lock synchronously before the first await so rapid taps cannot race.
    setState(() {
      isCreatingOrder = true;
    });
    _conversionBusy.value = true;
    bool orderCreated = false;

    try {
      final String? token = await gettokenFromPrefs();
      if (!mounted) return;

      if (token == null || token.trim().isEmpty) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD92D20),
            content: Text('Authentication token not found.'),
          ),
        );
        return;
      }

      final String? warehouseId = _resolveWarehouseId();

      if (warehouseId == null || warehouseId.trim().isEmpty) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD92D20),
            content: Text('Warehouse information is missing.'),
          ),
        );
        return;
      }

      final String? codStatusToSend =
          selectpaystatus == 'COD' ? selectcodtype : null;
      final double totalAmount = _parseAmount(orders.first['total_amount']);

      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('$api/api/order/create/performa/'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields.addAll({
        'performa_id': orders.first['id'].toString(),
        'state': orders.first['state'].toString(),
        'company': orders.first['company'].toString(),
        'family': orders.first['family'].toString(),
        'customer': orders.first['customerID'].toString(),
        'manage_staff': orders.first['manage_staff'].toString(),
        'billing_address': orders.first['billing_id'].toString(),
        'accounts_note': accountsNoteController.text.trim(),
        'warehouses': warehouseId,
        'total_amount': totalAmount.toStringAsFixed(2),
        'order_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'status': 'Invoice Created',
        'payment_status': _paymentStatusForApi(),
        if (selectpaymethod.isNotEmpty) 'payment_method': selectpaymethod,
      });

      if (selectedCourierServiceId != null) {
        request.fields['parcel_service'] =
            selectedCourierServiceId.toString();
      }

      request.fields['parcel_service_note'] =
          parcelServiceNoteController.text.trim();

      if (selectedbankId != null) {
        request.fields['bank'] = selectedbankId.toString();
      }

      if (selectpaystatus == 'COD') {
        if (codStatusToSend != null) {
          request.fields['cod_status'] = codStatusToSend;
        }

        request.fields['cod_amount'] =
            codamountcontroller.text.trim().isEmpty
                ? '0'
                : codamountcontroller.text.trim();

        if (selectcodtype == 'PARTIAL_COD') {
          request.fields['adv_cod_amount'] =
              advancecodamount.text.trim().isEmpty
                  ? '0'
                  : advancecodamount.text.trim();
        }
      }

      // Repeated text parts preserve every ID, matching React FormData.append.
      for (final slip in proformaPaymentSlips) {
        if (slip['id'] != null) {
          request.files.add(http.MultipartFile.fromString(
            'proforma_payment_slip_ids', slip['id'].toString(),
          ));
        }
      }
      request.fields.removeWhere((key, value) => value.isEmpty);

      for (int index = 0;
          index < paymentReceiptImages.length;
          index++) {
        final XFile image = paymentReceiptImages[index];
        final Uint8List bytes = await _readImageBytes(image);
        final String extension =
            image.path.split('.').last.toLowerCase();

        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename:
                'receipt_${DateTime.now().millisecondsSinceEpoch}_$index.$extension',
            contentType: _resolveImageMediaType(image),
          ),
        );
      }

      final http.Response response = await _auditMultipart(request, 'order_created_from_proforma');

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        orderCreated = true;
        dynamic createdOrderData;
        dynamic createdOrderId;

        try {
          createdOrderData = jsonDecode(response.body);

          if (createdOrderData is Map) {
            createdOrderId =
                createdOrderData['id'] ??
                createdOrderData['order_id'] ??
                createdOrderData['data']?['id'] ??
                createdOrderData['order']?['id'];
          }
        } catch (_) {
          createdOrderData = response.body;
        }

        

        if (!mounted) return;

        if (Navigator.of(scaffoldContext).canPop()) {
          Navigator.of(scaffoldContext).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF027A48),
            content: Text('Order created successfully.'),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CreatePerformaProduct_List(),
          ),
        );
      } else {
        String message = 'Order creation failed.';

        try {
          final dynamic decoded = jsonDecode(response.body);

          if (decoded is Map) {
            message = decoded['errors'] != null
                ? _conversionErrorMessage(decoded['errors'])
                : decoded['message']?.toString() ??
                decoded['detail']?.toString() ??
                decoded['error']?.toString() ??
                _conversionErrorMessage(decoded);
          }
        } catch (_) {
          if (response.body.trim().isNotEmpty) {
            message = response.body;
          }
        }

        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            content: Text(message),
          ),
        );
      }
    } catch (error) {
      _printDetails('PAGE ERROR', error.toString());
      if (!mounted) return;

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD92D20),
          content: Text('Unable to create order: $error'),
        ),
      );
    } finally {
      // Allow retry after failure; retain the lock after confirmed success.
      if (mounted && !orderCreated) {
        setState(() {
          isCreatingOrder = false;
        });
        _conversionBusy.value = false;
      }
    }
  }

  String _paymentStatusForApi() {
    switch (selectpaystatus) {
      case 'Paid':
        return 'paid';
      case 'COD':
        return 'COD';
      case 'credit':
        return 'credit';
      default:
        return selectpaystatus.toLowerCase();
    }
  }

  String? _resolveWarehouseId() {
    if (orders.isEmpty) return selectedwarehouseId?.toString();

    final dynamic warehouseValue = orders.first['warehouse_id'];

    if (warehouseValue == null) {
      return selectedwarehouseId?.toString();
    }

    if (warehouseValue is List) {
      if (warehouseValue.isEmpty) {
        return selectedwarehouseId?.toString();
      }

      final dynamic firstWarehouse = warehouseValue.first;

      if (firstWarehouse is Map) {
        return firstWarehouse['id']?.toString();
      }

      return firstWarehouse.toString();
    }

    if (warehouseValue is Map) {
      return warehouseValue['id']?.toString();
    }

    return warehouseValue.toString();
  }

  Future<String?> getwarehouseFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? warehouseId = prefs.getInt('warehouse');

    // Check if warehouseId is null before converting to String
    return warehouseId?.toString();
  }

  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<String?> gettokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> getbank() async {
    final token = await gettokenFromPrefs();
    try {
      final response = await _debugGet(Uri.parse('$api/api/banks/'), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      List<Map<String, dynamic>> banklist = [];

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];

        for (var productData in productsData) {
          String imageUrl = "${productData['image']}";
          banklist.add({
            'id': productData['id'],
            'name': productData['name'],
            'branch': productData['branch']
          });
        }
        if (!mounted) return;
        setState(() {
          bank = banklist;
        });
      }
    } catch (e) {
      _printDetails('PAGE ERROR', e.toString());}
  }

  var tot;

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  void showTotalDialog(BuildContext pageContext) {
    if (!mounted || isCreatingOrder || _isConversionDialogOpen) return;
    if (orders.isEmpty) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD92D20),
          content: Text(
            'Proforma details are not loaded yet. Please try again.',
          ),
        ),
      );
      return;
    }

    _isConversionDialogOpen = true;
    double totalItemPrice = 0.0;
    double totalDiscount = 0.0;

    for (final item in perfomaItemsWithImages) {
      final int quantity =
          int.tryParse((item['quantity'] ?? 0).toString()) ?? 0;
      final double rate = _parseAmount(item['actual_price']);
      final double discountPerQuantity = _parseAmount(item['discount']);

      totalItemPrice += quantity * rate;
      totalDiscount += quantity * discountPerQuantity;
    }

    // Match the backend: the saved proforma total is authoritative.
    final double netAmount = _parseAmount(orders.first['total_amount']);

    setState(() {
      tot = netAmount;
    });

    showDialog<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ValueListenableBuilder<bool>(
          valueListenable: _conversionBusy,
          builder: (context, busy, child) {
            return PopScope(
              canPop: !busy,
              child: AlertDialog(
          title: const Text('Proforma Total'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Items Total:'),
                    const Spacer(),
                    Text(
                      '₹${totalItemPrice.toStringAsFixed(2)}',
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Text('Total Discount:'),
                    const Spacer(),
                    Text(
                      '₹${totalDiscount.toStringAsFixed(2)}',
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Text(
                      'Proforma Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${netAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 100,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
                onPressed: busy
                    ? null
                    : () => ordercreate(dialogContext),
                child: Text(busy ? 'Creating...' : 'OK'),
              ),
            ),
          ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _isConversionDialogOpen = false;
    });
  }

  String? selectedValue;
  int? selectedCustomerId;
  final TextEditingController textEditingController = TextEditingController();

@override
void dispose() {
  _conversionBusy.dispose();
  textEditingController.dispose();
  searchController.dispose();
  codamountcontroller.dispose();
  advancecodamount.dispose();
  parcelServiceNoteController.dispose();
  accountsNoteController.dispose();
  super.dispose();
}

  List<String> paystatus = ["Paid", 'COD', 'credit'];
  List<String> mode = ["request", 'invoice', 'warehouse to warehouse'];

  String selectpaystatus = "Paid";
  String selectedmode = "invoice";

  List<String> paymethod = [
    '1 Razorpay',
    "Credit Card",
    'Debit Card',
    'Net Banking',
    'PayPal',
    'Cash on Delivery (COD)',
    'Bank Transfer'
  ];
  String selectpaymethod = "1 Razorpay";

  void showInvoiceDialog(BuildContext context, double total) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Invoice",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${total?.toStringAsFixed(2) ?? '0.00'}',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${total != null ? total.toStringAsFixed(2) : '0.00'}',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discount',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${Discount.toStringAsFixed(2)}',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                      Colors.blue,
                    ),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  child: Text("Close", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }


  InputDecoration _professionalInputDecoration({
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF98A2B3),
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              size: 20,
              color: const Color(0xFF667085),
            ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE4E7EC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD92D20),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD92D20),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
          if (required)
            const Text(
              " *",
              style: TextStyle(
                color: Color(0xFFD92D20),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF2563EB),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleGenerateInvoice() {
    if (isCreatingOrder || _isConversionDialogOpen) return;
    final error = _conversionValidationError();
    _printDetails('GENERATE INVOICE VALIDATION', {'error': error});
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }
    showTotalDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          tooltip: "Back",
          onPressed: () => Navigator.pop(context),
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: Color(0xFF344054),
            ),
          ),
        ),
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Order Request",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF101828),
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Convert proforma invoice to an order",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF667085),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'lib/assets/profile.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF475467),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF1D4ED8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F2563EB),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Order Request",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Review payment details and generate the invoice.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEAECF0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D101828),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeading(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "Payment Details",
                      subtitle:
                          "Configure the payment status, bank and payment method.",
                    ),
                    const SizedBox(height: 22),

               
                    _fieldLabel("Payment Status", required: true),
                    DropdownButtonFormField<String>(
                      value: selectpaystatus,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      decoration: _professionalInputDecoration(
                        hint: "Select payment status",
                        prefixIcon: Icons.payments_outlined,
                      ),
                      items: paystatus
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectpaystatus = value;
                          if (value == 'COD') {
                            selectpaymethod = '';
                            selectedbankId = null;
                          } else {
                            selectcodtype = 'select type';
                            codamountcontroller.clear();
                            advancecodamount.clear();
                            selectpaymethod = 'Bank Transfer';
                            if (bank.isNotEmpty) selectedbankId = bank.first['id'];
                          }
                        });
                      },
                    ),

                    if (selectpaystatus == "COD") ...[
                      const SizedBox(height: 16),
                      _fieldLabel("COD Type", required: true),
                      DropdownButtonFormField<String>(
                        value: selectcodtype,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        decoration: _professionalInputDecoration(
                          hint: "Select COD type",
                          prefixIcon: Icons.local_shipping_outlined,
                        ),
                        items: codtype
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectcodtype = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel("COD Amount", required: true),
                      TextField(
                        controller: codamountcontroller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF101828),
                        ),
                        decoration: _professionalInputDecoration(
                          hint: "Enter COD amount",
                          prefixIcon: Icons.currency_rupee_rounded,
                        ),
                      ),
                    ],

                    if (selectpaystatus == "COD" && selectcodtype == "PARTIAL_COD") ...[
                      const SizedBox(height: 16),
                      _fieldLabel("Advance COD Amount", required: true),
                      TextField(
                        controller: advancecodamount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF101828),
                        ),
                        decoration: _professionalInputDecoration(
                          hint: "Enter advance amount",
                          prefixIcon: Icons.savings_outlined,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _fieldLabel("Bank"),
                    DropdownButtonFormField<int>(
                      value: selectedbankId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      decoration: _professionalInputDecoration(
                        hint: "Select bank",
                        prefixIcon: Icons.account_balance_outlined,
                      ),
                      items: bank
                          .map(
                            (bankItem) => DropdownMenuItem<int>(
                              value: bankItem['id'],
                              child: Text(
                                bankItem['name']?.toString() ?? "",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedbankId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),
                    _fieldLabel("Payment Method", required: true),
                    DropdownButtonFormField<String>(
                      value: selectpaymethod.isEmpty ? null : selectpaymethod,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      decoration: _professionalInputDecoration(
                        hint: "Select payment method",
                        prefixIcon: Icons.credit_card_outlined,
                      ),
                      items: paymethod
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectpaymethod = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                         _fieldLabel("Courier Service"),
                    DropdownButtonFormField<int>(
                      value: courierdata.any((service) =>
                              service['id'] == selectedCourierServiceId)
                          ? selectedCourierServiceId : null,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                      ),
                      decoration: _professionalInputDecoration(
                        hint: "Select courier service",
                        prefixIcon: Icons.local_shipping_outlined,
                      ),
                      items: courierdata
                          .map(
                            (service) => DropdownMenuItem<int>(
                              value: service['id'],
                              child: Text(
                                service['name']?.toString() ?? "",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCourierServiceId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),
                    _fieldLabel("Courier Service Note"),
                    TextField(
                      controller: parcelServiceNoteController,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF101828),
                      ),
                      decoration: _professionalInputDecoration(
                        hint: "Enter courier service note",
                        prefixIcon: Icons.note_alt_outlined,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _fieldLabel("Accounts Note"),
TextField(
  controller: accountsNoteController,

  // Starts with a comfortable height but can keep growing.
  minLines: 4,
  maxLines: null,

  keyboardType: TextInputType.multiline,
  textInputAction: TextInputAction.newline,

  style: const TextStyle(
    fontSize: 13,
    color: Color(0xFF101828),
    height: 1.4,
  ),

  decoration: _professionalInputDecoration(
    hint: "Enter accounts note",
    prefixIcon: Icons.sticky_note_2_outlined,
  ),
),

const SizedBox(height: 16),

                   
                    _fieldLabel(
                      "Payment Receipt Images",
                      required: true,
                    ),
                    if (_isLoadingConversionData)
                      const LinearProgressIndicator(),
                    if (_conversionDataError != null)
                      Text(_conversionDataError!, style: const TextStyle(color: Colors.red)),
                    if (proformaPaymentSlips.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${proformaPaymentSlips.length} existing proforma payment slip(s) will be attached.',
                          style: const TextStyle(color: Color(0xFF027A48)),
                        ),
                      ),
                      _buildExistingPaymentSlipPreviews(),
                      const SizedBox(height: 14),
                    ],
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _selectPaymentReceiptImages,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: paymentReceiptImages.isEmpty
                                ? const Color(0xFFE4E7EC)
                                : const Color(0xFF84ADFF),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Select receipt images",
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF101828),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "You can select multiple payment receipt images.",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: Color(0xFF667085),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF667085),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (paymentReceiptImages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            "${paymentReceiptImages.length} image${paymentReceiptImages.length == 1 ? "" : "s"} selected",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475467),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                paymentReceiptImages.clear();
                                                        });
                            },
                            child: const Text("Remove all"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        itemCount: paymentReceiptImages.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final image =
                              paymentReceiptImages[index];

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: Image.file(
                                    File(image.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return Container(
                                        color:
                                            const Color(0xFFF2F4F7),
                                        child: const Icon(
                                          Icons
                                              .broken_image_outlined,
                                          color:
                                              Color(0xFF98A2B3),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    onTap: () =>
                                        _removePaymentReceiptImage(
                                      index,
                                    ),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withOpacity(0.68),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: !_isLoadingConversionData &&
                                _conversionDataError == null &&
                                _proformaReady && !isCreatingOrder &&
                                (paymentReceiptImages.isNotEmpty ||
                                    _hasExistingPaymentSlip)
                            ? _handleGenerateInvoice
                            : null,
                        icon: isCreatingOrder
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.description_outlined, size: 20),
                        label: Text(
                          isCreatingOrder
                              ? "Creating Order..."
                              : "Generate Invoice",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD0D5DD),
                          disabledForegroundColor: const Color(0xFF667085),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFED777),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 19,
                      color: Color(0xFFB54708),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Verify all payment details before generating the invoice.",
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Color(0xFF7A2E0E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
