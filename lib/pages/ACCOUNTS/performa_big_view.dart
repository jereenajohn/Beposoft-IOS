import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:beposoft/audit/audit_new_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:beposoft/pages/ACCOUNTS/performa_to_Order.dart';
import 'package:beposoft/pages/ACCOUNTS/new_performa_products.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_order_view.dart';
import 'package:beposoft/pages/api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PerformaInvoice_BigView_List extends StatefulWidget {
  final String invoice;
  const PerformaInvoice_BigView_List({super.key, required this.invoice});

  @override
  State<PerformaInvoice_BigView_List> createState() =>
      _PerformaInvoice_BigView_ListState();
}

class _PerformaInvoice_BigView_ListState
    extends State<PerformaInvoice_BigView_List> {
  dynamic _auditCopy(dynamic value) {
    // Detach the snapshot before any asynchronous request or UI refresh.
    return jsonDecode(
        jsonEncode(value, toEncodable: (value) => value.toString()));
  }

  Map<String, dynamic> _loadedProforma = <String, dynamic>{};

  Map<String, dynamic> _auditSnapshot(int orderId, int? itemId) {
    final matchingOrders = orders
        .where(
          (order) => order['id']?.toString() == orderId.toString(),
        )
        .toList();
    final rawItems = _loadedProforma['perfoma_items'];
    final previousItems = rawItems is List
        ? rawItems
            .where((item) =>
                item is Map && item['id']?.toString() == itemId?.toString())
            .toList()
        : <dynamic>[];
    return Map<String, dynamic>.from(_auditCopy(<String, dynamic>{
      'proforma_id': orderId,
      'invoice': widget.invoice,
      if (itemId != null) 'item_id': itemId,
      'loaded_proforma_response': _loadedProforma,
      'order_details': matchingOrders,
      if (itemId != null) 'item_details': previousItems,
    }) as Map);
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
    required int orderId,
    required int? itemId,
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
          response.statusCode >= 200 &&
          response.statusCode < 300;
      final logged = await AuditLogService.log(
        action: successful ? action : '${action}_failed',
        // A proforma ID is not an Order foreign key.
        orderId: null,
        beforeData: before,
        afterData: <String, dynamic>{
          'proforma_id': orderId,
          'invoice': widget.invoice,
          if (itemId != null) 'item_id': itemId,
          'submitted_data': submitted,
          'response_data':
              response == null ? null : _auditResponseData(response),
          'outcome': successful ? 'success' : 'failed',
          if (method == 'DELETE' && successful) 'deleted': true,
          if (error != null) 'error_type': error.runtimeType.toString(),
          'metadata': <String, dynamic>{
            'source': 'PerformaInvoice_BigView_List',
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

  Future<http.Response> _auditMutation(
    int orderId,
    int? itemId,
    String method,
    String action,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final before = _auditSnapshot(orderId, itemId);
    dynamic submitted = body;
    if (body is String) {
      try {
        submitted = jsonDecode(body);
      } catch (_) {}
    }
    submitted = _auditCopy(submitted);
    late final http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await http.post(uri,
              headers: headers, body: body, encoding: encoding);
          break;
        case 'PUT':
          response = await http.put(uri,
              headers: headers, body: body, encoding: encoding);
          break;
        case 'PATCH':
          response = await http.patch(uri,
              headers: headers, body: body, encoding: encoding);
          break;
        case 'DELETE':
          response = await http.delete(uri,
              headers: headers, body: body, encoding: encoding);
          break;
        default:
          throw ArgumentError.value(method, 'method');
      }
    } catch (error) {
      await _recordMutation(
          orderId: orderId,
          itemId: itemId,
          action: action,
          method: method,
          uri: uri,
          before: before,
          submitted: submitted,
          error: error);
      rethrow;
    }
    await _recordMutation(
        orderId: orderId,
        itemId: itemId,
        action: action,
        method: method,
        uri: uri,
        before: before,
        submitted: submitted,
        response: response);
    return response;
  }

  drower d = drower();
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> stat = [];
  List<Map<String, dynamic>> company = [];
  dynamic allocatedstates = [];
  String? department;

  bool get _canGenerateInvoice => const <String>{
        'information technology',
        'admin',
        'accounts',
        'accounting',
        'accounts / accounting',
        'ceo',
        'coo',
      }.contains(department?.trim().toLowerCase());
  bool isLoading = true;
  String? loadError;
  bool isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      department = await getdepFromPrefs();
      await getprofiledata();
      await getcompany();
      await getstate();
      await fetchperformalistData();
    } catch (e) {
      if (mounted) {
        setState(() {
          loadError = "Unable to load proforma invoice details.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
            d.navigateToSelectedPage(
                context, option); // Navigate to selected page
          },
        );
      }).toList(),
    );
  }

  Future<pw.Document> createInvoice() async {
    final pdf = pw.Document();

    for (var order in orders) {
      final items = order['perfoma_items'] as List<dynamic>;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header section
                  pw.Container(
                    color: PdfColors.blue800,
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('INVOICE',
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 30,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('Bepositive Racing Pvt Ltd',
                                style: pw.TextStyle(
                                    color: PdfColors.white, fontSize: 12)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                                'Invoice No: #${order['invoice'].toString()}',
                                style: pw.TextStyle(
                                    color: PdfColors.white, fontSize: 12)),
                            pw.Text('Date: ${order['order_date'].toString()}',
                                style: pw.TextStyle(
                                    color: PdfColors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Customer Information
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Invoice To:',
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Text(order['customer_name'].toString()),
                          pw.Text(order['address'].toString()),
                          pw.Text(order['state'].toString()),
                        ],
                      ),
                      pw.SizedBox(width: 20),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Payment Details:',
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Text('Bank Code: ${order['bank'].toString()}'),
                          pw.Text(
                              'Payment Method: ${order['payment_method'].toString()}'),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Items Table
                  pw.Container(
                    color: PdfColors.grey300,
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                            child: pw.Text('Description',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Text('Qty',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 20),
                        pw.Text('Cost',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 20),
                        pw.Text('Discount',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 20),
                        pw.Text('Subtotal',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Divider(thickness: 1),

                  // Loop to Display Items
                  for (var item in items)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text(item['name'].toString())),
                        pw.SizedBox(width: 20),
                        pw.Text(item['quantity'].toString()),
                        pw.SizedBox(width: 20),
                        pw.Text('\$${item['actual_price'].toString()}'),
                        pw.SizedBox(width: 20),
                        pw.Text(
                            '\$${(item['quantity'] * item['discount']).toStringAsFixed(2)}'),
                        pw.SizedBox(width: 20),
                        pw.Text(
                            '\$${(item['quantity'] * item['actual_price']).toStringAsFixed(2)}'),
                      ],
                    ),
                  pw.Divider(thickness: 1),

                  // Total Amount Section
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text('Subtotal: ',
                                  style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(
                                  '\$${(order['total_amount'] ?? 0 + 250).toStringAsFixed(2)}')
                            ],
                          ),
                          // pw.Row(
                          //   children: [
                          //     pw.Text('Tax: ',
                          //         style: pw.TextStyle(
                          //             fontSize: 12,
                          //             fontWeight: pw.FontWeight.bold)),
                          //     pw.Text('\$250.00'), // Example Tax value
                          //   ],
                          // ),
                          pw.SizedBox(height: 10),

                          // pw.Row(
                          //   children: [
                          //     pw.Text('Total: ',
                          //         style: pw.TextStyle(
                          //             fontSize: 14,
                          //             fontWeight: pw.FontWeight.bold,
                          //             color: PdfColors.blue800)),
                          //     pw.Text(
                          //         '\$${(order['total_amount']).toStringAsFixed(2)}',
                          //         style: pw.TextStyle(
                          //             fontSize: 14,
                          //             fontWeight: pw.FontWeight.bold,
                          //             color: PdfColors.blue800)),
                          //   ],
                          // ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Footer
                  pw.Text('Thank You!',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Please contact us if you have any questions about this invoice.',
                      style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 10),
                  pw.Text('Contact Us:',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Row(
                    children: [
                      pw.Text('+123-456-7890  |  '),
                      pw.Text('contact@bepositive.com  |  '),
                      pw.Text('123 Main St, Kochi, Kerala, India'),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf;
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

// Function to save and download the PDF
  Future<void> downloadInvoice() async {
    if (isDownloading) return;

    if (mounted) {
      setState(() {
        isDownloading = true;
      });
    }

    try {
      final pdf = await createInvoice();
      final bytes = await pdf.save();

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/invoice.pdf");
      await file.writeAsBytes(bytes);

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'invoice.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to download invoice."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
      }
    }
  }

  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> getprofiledata() async {
    try {
      final token = await getTokenFromPrefs();

      final response = await http.get(
        Uri.parse('$api/api/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final data = parsed['data'];

        if (!mounted) return;

        setState(() {
          allocatedstates = data?['allocated_states'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> getcompany() async {
    try {
      final token = await getTokenFromPrefs();

      final response = await http.get(
        Uri.parse('$api/api/company/data/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final List<dynamic> data = parsed['data'] ?? [];

        final List<Map<String, dynamic>> companyList = data
            .map<Map<String, dynamic>>(
              (item) => {
                'id': item['id'],
                'name': item['name'],
              },
            )
            .toList();

        if (!mounted) return;

        setState(() {
          company = companyList;
        });
      }
    } catch (_) {}
  }

  Future<void> getstate() async {
    try {
      final token = await getTokenFromPrefs();
      department ??= await getdepFromPrefs();

      final response = await http.get(
        Uri.parse('$api/api/states/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return;

      final parsed = jsonDecode(response.body);
      final List<dynamic> data = parsed['data'] ?? [];

      List<Map<String, dynamic>> stateList = data
          .map<Map<String, dynamic>>(
            (item) => {
              'id': item['id'],
              'name': item['name'],
            },
          )
          .toList();

      // Same permission flow used in Order Request:
      // BDM / BDO can only see their allocated states.
      if (department == "BDM" || department == "BDO") {
        final Set<String> allowedStateIds =
            (allocatedstates is List ? allocatedstates as List : const [])
                .map((e) => e.toString())
                .toSet();

        stateList = stateList
            .where(
              (state) => allowedStateIds.contains(
                state['id'].toString(),
              ),
            )
            .toList();
      }

      if (!mounted) return;

      setState(() {
        stat = stateList;
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> fetchCustomersForDropdown({
    String search = '',
  }) async {
    try {
      final token = await getTokenFromPrefs();
      department ??= await getdepFromPrefs();

      final bool staffCustomer = department == "BDO" || department == "BDM";

      final String endpoint =
          staffCustomer ? '$api/api/staff/customers/' : '$api/api/customers/';

      final Map<String, String> queryParameters = {};

      if (search.trim().isNotEmpty) {
        queryParameters['search'] = search.trim();
      }

      final uri = Uri.parse(endpoint).replace(
        queryParameters: queryParameters,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final parsed = jsonDecode(response.body);

      List<dynamic> customersData = [];

      if (parsed is Map && parsed['results'] is List) {
        customersData = parsed['results'];
      } else if (parsed is Map && parsed['data'] is List) {
        customersData = parsed['data'];
      } else if (parsed is List) {
        customersData = parsed;
      }

      return customersData
          .map<Map<String, dynamic>>(
            (item) => {
              'id': item['id'],
              'name': item['name'] ?? '',
              'phone': item['phone'] ?? '',
              'state': item['state_name'] ?? item['state'] ?? '',
              'gst': item['gst'] ?? '',
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomerAddresses(
    int customerId,
  ) async {
    try {
      final token = await getTokenFromPrefs();

      final response = await http.get(
        Uri.parse('$api/api/add/customer/address/$customerId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final parsed = jsonDecode(response.body);
      final List<dynamic> data = parsed['data'] ?? [];

      return data
          .map<Map<String, dynamic>>(
            (item) => {
              'id': item['id'],
              'name': item['name'],
              'email': item['email'],
              'zipcode': item['zipcode'],
              'address': item['address'],
              'phone': item['phone'],
              'country': item['country'],
              'city': item['city'],
              'state': item['state'],
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, String>> _saveProformaNotes(
    int proformaId,
    String note,
    String courierNote,
  ) async {
    final token = await getTokenFromPrefs();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    if (proformaId <= 0) throw Exception('Invalid proforma ID.');
    final response = await _auditMutation(
      proformaId,
      null,
      'PUT',
      'proforma_notes_updated',
      Uri.parse('$api/api/perfoma/order/$proformaId/update/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'note': note, 'parcel_note': courierNote}),
    );
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map
          ? (decoded['errors'] ??
              decoded['detail'] ??
              decoded['message'] ??
              decoded['error'] ??
              decoded)
          : null;
      throw Exception(detail?.toString() ??
          'Unable to save notes (${response.statusCode}).');
    }
    dynamic record = decoded;
    if (record is Map && record['data'] is Map) record = record['data'];
    final saved = <String, String>{
      'note': record is Map && record.containsKey('note')
          ? (record['note']?.toString() ?? '')
          : note,
      'parcel_note': record is Map && record.containsKey('parcel_note')
          ? (record['parcel_note']?.toString() ?? '')
          : courierNote,
    };
    if (mounted) {
      setState(() {
        if (_loadedProforma['id']?.toString() == proformaId.toString()) {
          _loadedProforma.addAll(saved);
        }
        for (final order in orders) {
          if (order['id']?.toString() == proformaId.toString())
            order.addAll(saved);
        }
      });
    }
    return saved;
  }

  Future<bool> updateProformaOrderDetails({
    required int orderId,
    required int companyId,
    required int stateId,
    required int customerId,
    required int billingAddressId,
  }) async {
    try {
      final String? token = await getTokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Authentication token not found.'),
            ),
          );
        }
        return false;
      }

      final response = await _auditMutation(
        orderId,
        null,
        'PUT',
        'proforma_details_updated',
        Uri.parse(
          '$api/api/perfoma/order/$orderId/update/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'company': companyId,
          'state': stateId,
          'customer': customerId,
          'billing_address': billingAddressId,
        }),
      );

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchperformalistData();

        if (!mounted) return true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF027A48),
            content: Text(
              'Proforma details updated successfully.',
            ),
          ),
        );

        return true;
      }

      String errorMessage = 'Failed to update proforma details.';

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map) {
          final dynamic errors = decoded['errors'];

          if (errors != null) {
            errorMessage = errors.toString();
          } else {
            errorMessage = decoded['message']?.toString() ??
                decoded['detail']?.toString() ??
                decoded['error']?.toString() ??
                errorMessage;
          }
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(errorMessage),
        ),
      );

      return false;
    } catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Unable to update proforma details: $error',
          ),
        ),
      );

      return false;
    }
  }

  Future<Map<String, dynamic>?> _openCustomerSelectorForEdit({
    required Map<String, dynamic>? selectedCustomer,
  }) async {
    final TextEditingController searchController = TextEditingController();
    Timer? debounce;

    try {
      return await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext bottomSheetContext) {
          bool initialLoading = true;
          bool searching = false;
          List<Map<String, dynamic>> customers = [];

          return StatefulBuilder(
            builder: (
              BuildContext modalContext,
              StateSetter modalSetState,
            ) {
              Future<void> loadCustomers({
                String search = '',
              }) async {
                final result = await fetchCustomersForDropdown(
                  search: search,
                );

                if (!bottomSheetContext.mounted) return;

                modalSetState(() {
                  customers = result;
                  initialLoading = false;
                  searching = false;
                });
              }

              if (initialLoading) {
                Future.microtask(loadCustomers);
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
                ),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0D5DD),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Select Customer',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(bottomSheetContext).pop();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          12,
                        ),
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search customer by name or phone...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            debounce?.cancel();

                            modalSetState(() {
                              searching = true;
                            });

                            debounce = Timer(
                              const Duration(
                                milliseconds: 500,
                              ),
                              () {
                                loadCustomers(
                                  search: value.trim(),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (initialLoading || searching)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (customers.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No customers found',
                              style: TextStyle(
                                color: Color(0xFF667085),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              16,
                            ),
                            itemCount: customers.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (
                              context,
                              index,
                            ) {
                              final customer = customers[index];

                              final String name =
                                  customer['name']?.toString() ?? '';

                              final String phone =
                                  customer['phone']?.toString() ?? '';

                              final String state =
                                  customer['state']?.toString() ?? '';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (phone.isNotEmpty) phone,
                                    if (state.isNotEmpty) state,
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                ),
                                onTap: () {
                                  Navigator.of(
                                    bottomSheetContext,
                                  ).pop(customer);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      debounce?.cancel();

      // Delayed disposal avoids controller lifecycle issues
      // during the bottom-sheet dismissal animation.
      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      searchController.dispose();
    }
  }

  Future<void> _showEditOrderDetailsDialog(
    Map<String, dynamic> order,
  ) async {
    final int orderId = _asInt(order['id']);

    int? selectedCompanyId =
        _asInt(order['company']) > 0 ? _asInt(order['company']) : null;

    int? selectedStateId =
        _asInt(order['state_id']) > 0 ? _asInt(order['state_id']) : null;

    int? selectedCustomerId =
        _asInt(order['customer_id']) > 0 ? _asInt(order['customer_id']) : null;

    int? selectedAddressId = _asInt(order['billing_address_id']) > 0
        ? _asInt(order['billing_address_id'])
        : null;

    Map<String, dynamic>? selectedCustomer = {
      'id': selectedCustomerId,
      'name': order['customer_name'],
    };

    List<Map<String, dynamic>> addresses = [];

    if (selectedCustomerId != null) {
      addresses = await fetchCustomerAddresses(selectedCustomerId);
    }

    if (!mounted) return;

    bool isSaving = false;

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      String? hint,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: const Color(0xFF667085),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF667085),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF98A2B3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFD0D5DD),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFEAECF0),
          ),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            final selectedAddress = addresses
                .where((item) => item['id'] == selectedAddressId)
                .cast<Map<String, dynamic>>()
                .toList();

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24101828),
                        blurRadius: 32,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            18,
                            14,
                            18,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF2563EB),
                                Color(0xFF1D4ED8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Edit Proforma Details',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Update company, state, customer and shipping address.',
                                      style: TextStyle(
                                        color: Color(0xFFDCEBFF),
                                        fontSize: 11.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        Navigator.of(dialogContext).pop();
                                      },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              18,
                              18,
                              8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFEAECF0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.receipt_long_outlined,
                                          size: 18,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Proforma',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF667085),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '#${_safeText(order['invoice'])}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF101828),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: company.any(
                                    (item) => item['id'] == selectedCompanyId,
                                  )
                                      ? selectedCompanyId
                                      : null,
                                  isExpanded: true,
                                  decoration: fieldDecoration(
                                    label: 'Company',
                                    icon: Icons.business_outlined,
                                    hint: 'Select company',
                                  ),
                                  items: company
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item['id'],
                                          child: Text(
                                            item['name']?.toString() ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF101828),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            selectedCompanyId = value;
                                          });
                                        },
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<int>(
                                  value: stat.any(
                                    (item) => item['id'] == selectedStateId,
                                  )
                                      ? selectedStateId
                                      : null,
                                  isExpanded: true,
                                  decoration: fieldDecoration(
                                    label: 'State',
                                    icon: Icons.location_on_outlined,
                                    hint: 'Select state',
                                  ),
                                  items: stat
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item['id'],
                                          child: Text(
                                            item['name']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF101828),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            selectedStateId = value;
                                          });
                                        },
                                ),
                                const SizedBox(height: 14),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: isSaving
                                      ? null
                                      : () async {
                                          final customer =
                                              await _openCustomerSelectorForEdit(
                                            selectedCustomer: selectedCustomer,
                                          );

                                          if (customer == null ||
                                              !dialogContext.mounted) {
                                            return;
                                          }

                                          final int? customerId = int.tryParse(
                                            customer['id'].toString(),
                                          );

                                          if (customerId == null) {
                                            return;
                                          }

                                          final fetchedAddresses =
                                              await fetchCustomerAddresses(
                                            customerId,
                                          );

                                          if (!dialogContext.mounted) {
                                            return;
                                          }

                                          setDialogState(() {
                                            selectedCustomer = customer;
                                            selectedCustomerId = customerId;
                                            addresses = fetchedAddresses;
                                            selectedAddressId =
                                                addresses.isNotEmpty
                                                    ? addresses.first['id']
                                                    : null;
                                          });
                                        },
                                  child: InputDecorator(
                                    decoration: fieldDecoration(
                                      label: 'Customer',
                                      icon: Icons.person_outline_rounded,
                                      hint: 'Select customer',
                                      suffixIcon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                    child: Text(
                                      _safeText(
                                        selectedCustomer?['name'],
                                        fallback: 'Select Customer',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF101828),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<int>(
                                  value: addresses.any(
                                    (item) => item['id'] == selectedAddressId,
                                  )
                                      ? selectedAddressId
                                      : null,
                                  isExpanded: true,
                                  decoration: fieldDecoration(
                                    label: 'Shipping Address',
                                    icon: Icons.home_work_outlined,
                                    hint: selectedCustomerId == null
                                        ? 'Select customer first'
                                        : addresses.isEmpty
                                            ? 'No address found'
                                            : 'Select address',
                                  ),
                                  items: addresses
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item['id'],
                                          child: Text(
                                            item['address']?.toString() ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              height: 1.3,
                                              color: Color(0xFF101828),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: isSaving || addresses.isEmpty
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            selectedAddressId = value;
                                          });
                                        },
                                ),
                                if (selectedAddress.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F7FF),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFB2CCFF),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(9),
                                          ),
                                          child: const Icon(
                                            Icons.pin_drop_outlined,
                                            size: 18,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Selected Address',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF175CD3),
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                selectedAddress.first['address']
                                                        ?.toString() ??
                                                    '',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  height: 1.4,
                                                  color: Color(0xFF344054),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            18,
                            12,
                            18,
                            18,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Color(0xFFEAECF0),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () {
                                          Navigator.of(dialogContext).pop();
                                        },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    foregroundColor: const Color(0xFF344054),
                                    side: const BorderSide(
                                      color: Color(0xFFD0D5DD),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (selectedCompanyId == null ||
                                              selectedStateId == null ||
                                              selectedCustomerId == null ||
                                              selectedAddressId == null) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                  'Please select company, state, customer and address.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          setDialogState(() {
                                            isSaving = true;
                                          });

                                          final bool success =
                                              await updateProformaOrderDetails(
                                            orderId: orderId,
                                            companyId: selectedCompanyId!,
                                            stateId: selectedStateId!,
                                            customerId: selectedCustomerId!,
                                            billingAddressId:
                                                selectedAddressId!,
                                          );

                                          if (!dialogContext.mounted) {
                                            return;
                                          }

                                          if (success) {
                                            Navigator.of(dialogContext).pop();
                                          } else {
                                            setDialogState(() {
                                              isSaving = false;
                                            });
                                          }
                                        },
                                  icon: isSaving
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_outlined,
                                          size: 18,
                                        ),
                                  label: Text(
                                    isSaving ? 'Saving...' : 'Save Changes',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    elevation: 0,
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
              ),
            );
          },
        );
      },
    );
  }

  String getStateNameById(int stateId) {
    final state = stat.firstWhere(
      (element) => element['id'] == stateId,
      orElse: () => {'name': 'Unknown'}, // Return a Map with a default 'name'
    );
    return state['name'];
  }

// Fetch performa list data and map state ID to state name
  Future<void> fetchperformalistData() async {
    try {
      final token = await getTokenFromPrefs();
      final response = await http.get(
        Uri.parse('$api/api/perfoma/${widget.invoice}/invoice/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        _loadedProforma = Map<String, dynamic>.from(_auditCopy(parsed) as Map);

        List<Map<String, dynamic>> performaInvoiceList = [];

        List<Map<String, dynamic>> perfomaItemsWithImages =
            (parsed['perfoma_items'] as List<dynamic>?)?.map((item) {
                  return {
                    'id': item['id'],
                    'product_id': item['product_id'] ??
                        item['product'] ??
                        item['productID'],
                    'name': item['name'],
                    'quantity': item['quantity'],
                    'actual_price': item['actual_price'],
                    'first_image': item['images'],
                    'discount': item['discount'],
                    'rate': item['rate'],
                    'tax': item['tax'],
                    'description': item['description'],
                  };
                }).toList() ??
                [];

        // Get state name from ID
        final stateName = getStateNameById(parsed['state']);

        performaInvoiceList.add({
          'id': parsed['id'],
          'invoice': parsed['invoice'],
          'manage_staff': parsed['manage_staff'],
          "maneger": parsed['manage_staff_name'],
          'company': parsed['company'],
          'company_name': parsed['company_name'],
          'customer_id': parsed['customer']?['id'],
          'customer_name': parsed['customer']?['name'] ?? 'Unknown',
          'family': parsed['family'],
          'family_name': parsed['familyname'],
          'state_id':
              parsed['state'] is Map ? parsed['state']['id'] : parsed['state'],
          'state': stateName, // Use state name instead of ID
          'billing_address_id': parsed['billing_address']?['id'],
          'address': parsed['billing_address']?['address'] ?? 'Unknown',
          'note': parsed['note']?.toString() ?? '',
          'parcel_note': parsed['parcel_note']?.toString() ?? '',
          'payment_status': parsed['payment_status'],
          'bank': parsed['bank']?['name'] ?? 'Unknown',
          'payment_method': parsed['payment_method'],
          'status': parsed['status'],
          'total_amount': parsed['total_amount'],
          'order_date': parsed['order_date'],
          'created_at': parsed['customer']?['created_at'] ?? 'Unknown',
          'perfoma_items': perfomaItemsWithImages,
        });

        setState(() {
          orders = performaInvoiceList;
          ;
        });
      } else {
        // Handle error response
      }
    } catch (error) {
      ;
      // Handle exception
    }
  }

  Future<String?> getwarehouseFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int? warehouseId = prefs.getInt('warehouse');

    return warehouseId?.toString();
  }

  num _normalizedAvailableStock({
    required dynamic stockValue,
    required dynamic availableStockValue,
  }) {
    final num stock = stockValue is num
        ? stockValue
        : num.tryParse(
              stockValue?.toString() ?? '0',
            ) ??
            0;

    final num rawAvailableStock = availableStockValue is num
        ? availableStockValue
        : num.tryParse(
              availableStockValue?.toString() ?? '0',
            ) ??
            0;

    // Same normalization used in CreatePerformaProduct_List.
    if (stock <= 0 || rawAvailableStock <= 0) {
      return 0;
    }

    return rawAvailableStock;
  }

  Map<String, dynamic>? _findWarehouseProductById(
    List<dynamic> products,
    int productId,
  ) {
    for (final dynamic rawProduct in products) {
      if (rawProduct is! Map) continue;

      final Map<String, dynamic> product =
          Map<String, dynamic>.from(rawProduct);

      if (_asInt(product['id']) == productId) {
        return product;
      }

      final List<dynamic> variants =
          product['variantIDs'] as List<dynamic>? ?? [];

      for (final dynamic rawVariant in variants) {
        if (rawVariant is! Map) continue;

        final Map<String, dynamic> variant =
            Map<String, dynamic>.from(rawVariant);

        if (_asInt(variant['id']) == productId) {
          return variant;
        }
      }
    }

    return null;
  }

  Future<num?> fetchAvailableStockForProduct({
    required int productId,
    required String productName,
  }) async {
    try {
      final String? token = await getTokenFromPrefs();
      final String? warehouseId = await getwarehouseFromPrefs();

      if (token == null ||
          token.trim().isEmpty ||
          warehouseId == null ||
          warehouseId.trim().isEmpty) {
        return null;
      }

      Future<Map<String, dynamic>?> fetchPage(
        int page, {
        String search = '',
      }) async {
        final Uri uri = Uri.parse(
          '$api/api/warehouse/products/$warehouseId/get/',
        ).replace(
          queryParameters: {
            'page': page.toString(),
            if (search.trim().isNotEmpty) 'search': search.trim(),
          },
        );

        final http.Response response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode != 200) {
          return null;
        }

        final dynamic parsed = jsonDecode(response.body);

        if (parsed is! Map) {
          return null;
        }

        final dynamic results = parsed['results'];
        final List<dynamic> data = results is Map && results['data'] is List
            ? List<dynamic>.from(results['data'])
            : const [];

        final Map<String, dynamic>? found = _findWarehouseProductById(
          data,
          productId,
        );

        if (found != null) {
          return found;
        }

        return {
          '_next': parsed['next'],
        };
      }

      // First use product name as search. This keeps the request light,
      // while matching the search-enabled warehouse API used by
      // CreatePerformaProduct_List.
      if (productName.trim().isNotEmpty) {
        final Map<String, dynamic>? searched = await fetchPage(
          1,
          search: productName.trim(),
        );

        if (searched != null && !searched.containsKey('_next')) {
          return _normalizedAvailableStock(
            stockValue: searched['stock'],
            availableStockValue: searched['available_stock'],
          );
        }
      }

      // Fallback: walk warehouse product pages until the product/variant
      // is found. This prevents an incorrect stock result when search
      // text does not match exactly.
      int page = 1;
      while (page <= 100) {
        final Map<String, dynamic>? result = await fetchPage(page);

        if (result == null) {
          return null;
        }

        if (!result.containsKey('_next')) {
          return _normalizedAvailableStock(
            stockValue: result['stock'],
            availableStockValue: result['available_stock'],
          );
        }

        final dynamic next = result['_next'];

        if (next == null) {
          break;
        }

        page++;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showStockVerificationErrorDialog({
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext popupContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2B101828),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFB42318),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Stock Verification Failed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          popupContext,
                          rootNavigator: true,
                        ).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFB42318),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInsufficientStockDialog({
    required String productName,
    required int requestedQuantity,
    required num availableStock,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 440,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24101828),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFFB42318),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Insufficient Stock',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _safeText(productName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFEC84B),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Requested Quantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ),
                            Text(
                              requestedQuantity.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF101828),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Available Stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ),
                            Text(
                              availableStock.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB42318),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'There is not enough available stock for this product. '
                    'Please contact the Accounts department before updating the quantity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFB42318),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'OK, I Understand',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> updateProformaItem({
    required int orderId,
    required int itemId,
    required int quantity,
    required double rate,
    required double discount,
    required double tax,
    required String description,
  }) async {
    try {
      final String? token = await getTokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Authentication token not found.'),
            ),
          );
        }
        return false;
      }

      final String finalDescription = description.trim().isNotEmpty
          ? description.trim()
          : 'Updated product';

      final http.Response response = await _auditMutation(
        orderId,
        itemId,
        'PUT',
        'proforma_item_updated',
        Uri.parse(
          '$api/api/perfoma/order/$orderId/item/$itemId/update/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'quantity': quantity,
          'rate': rate,
          'discount': discount,
          'tax': tax,
          'description': finalDescription,
        }),
      );

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF027A48),
            content: Text(
              'Product details updated successfully.',
            ),
          ),
        );

        await fetchperformalistData();

        return true;
      }

      String errorMessage = 'Failed to update product details.';

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map) {
          final dynamic errors = decoded['errors'];

          if (errors is Map && errors.isNotEmpty) {
            final List<String> messages = [];

            errors.forEach((key, value) {
              if (value is List) {
                messages.add(
                  '${key.toString()}: ${value.join(', ')}',
                );
              } else {
                messages.add(
                  '${key.toString()}: ${value.toString()}',
                );
              }
            });

            if (messages.isNotEmpty) {
              errorMessage = messages.join('\n');
            }
          } else {
            errorMessage = decoded['message']?.toString() ??
                decoded['detail']?.toString() ??
                decoded['error']?.toString() ??
                errorMessage;
          }
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(errorMessage),
        ),
      );

      return false;
    } catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Unable to update product: $error',
          ),
        ),
      );

      return false;
    }
  }

  Future<bool> deleteProformaItem({
    required int orderId,
    required int itemId,
  }) async {
    try {
      final String? token = await getTokenFromPrefs();

      if (token == null || token.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Authentication token not found.'),
            ),
          );
        }
        return false;
      }

      final http.Response response = await _auditMutation(
        orderId,
        itemId,
        'DELETE',
        'proforma_item_deleted',
        Uri.parse(
          '$api/api/perfoma/order/$orderId/item/$itemId/delete/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return false;

      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF027A48),
            content: Text(
              'Product removed successfully.',
            ),
          ),
        );

        await fetchperformalistData();

        return true;
      }

      String errorMessage = 'Failed to remove product.';

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map) {
          errorMessage = decoded['message']?.toString() ??
              decoded['detail']?.toString() ??
              decoded['error']?.toString() ??
              errorMessage;
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(errorMessage),
        ),
      );

      return false;
    } catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Unable to remove product: $error',
          ),
        ),
      );

      return false;
    }
  }

  Future<void> _confirmDeleteProformaItem({
    required int orderId,
    required Map<String, dynamic> item,
  }) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Remove Product',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to remove ${_safeText(item['name'])} from this proforma?',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475467),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
              ),
              label: const Text('Remove'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    await deleteProformaItem(
      orderId: orderId,
      itemId: _asInt(item['id']),
    );
  }

  Future<void> _showEditProductDialog({
    required int orderId,
    required Map<String, dynamic> item,
  }) async {
    final TextEditingController quantityController = TextEditingController(
      text: _asInt(item['quantity']).toString(),
    );

    final TextEditingController rateController = TextEditingController(
      text: _asDouble(item['rate']).toString(),
    );

    final TextEditingController discountController = TextEditingController(
      text: _asDouble(item['discount']).toString(),
    );

    final TextEditingController taxController = TextEditingController(
      text: _asDouble(item['tax']).toString(),
    );

    final TextEditingController descriptionController = TextEditingController(
      text: item['description']?.toString() ?? '',
    );

    bool isUpdating = false;

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      String? prefixText,
    }) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: const Color(0xFF667085),
        ),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: Color(0xFF475467),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF667085),
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFD0D5DD),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFEAECF0),
          ),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            final int quantity = int.tryParse(quantityController.text.trim()) ??
                _asInt(item['quantity']);

            final double rate = double.tryParse(rateController.text.trim()) ??
                _asDouble(item['rate']);

            final double discount = double.tryParse(
                  discountController.text.trim(),
                ) ??
                _asDouble(item['discount']);

            final double previewTotal =
                (quantity * rate) - (quantity * discount);

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24101828),
                        blurRadius: 32,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            18,
                            14,
                            18,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF2563EB),
                                Color(0xFF1D4ED8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.white,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Edit Product',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _safeText(item['name']),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFDCEBFF),
                                        fontSize: 11.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isUpdating
                                    ? null
                                    : () {
                                        Navigator.of(dialogContext).pop();
                                      },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              18,
                              18,
                              8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF3),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFABEFC6),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.calculate_outlined,
                                          size: 19,
                                          color: Color(0xFF027A48),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Estimated Line Total',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF027A48),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Based on quantity, rate and discount',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF475467),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _currency(previewTotal),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF027A48),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: quantityController,
                                        enabled: !isUpdating,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setDialogState(() {});
                                        },
                                        decoration: fieldDecoration(
                                          label: 'Quantity',
                                          icon: Icons.shopping_bag_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: rateController,
                                        enabled: !isUpdating,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        onChanged: (_) {
                                          setDialogState(() {});
                                        },
                                        decoration: fieldDecoration(
                                          label: 'Rate',
                                          icon: Icons.currency_rupee_rounded,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: discountController,
                                        enabled: !isUpdating,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        onChanged: (_) {
                                          setDialogState(() {});
                                        },
                                        decoration: fieldDecoration(
                                          label: 'Discount',
                                          icon: Icons.discount_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: taxController,
                                        enabled: false,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: fieldDecoration(
                                          label: 'Tax',
                                          icon: Icons.percent_rounded,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: descriptionController,
                                  enabled: !isUpdating,
                                  keyboardType: TextInputType.multiline,
                                  minLines: 4,
                                  maxLines: null,
                                  decoration: fieldDecoration(
                                    label: 'Description',
                                    icon: Icons.notes_rounded,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            18,
                            12,
                            18,
                            18,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Color(0xFFEAECF0),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () {
                                          Navigator.of(dialogContext).pop();
                                        },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    foregroundColor: const Color(0xFF344054),
                                    side: const BorderSide(
                                      color: Color(0xFFD0D5DD),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: isUpdating
                                      ? null
                                      : () async {
                                          final int? quantity = int.tryParse(
                                            quantityController.text.trim(),
                                          );

                                          final double? rate = double.tryParse(
                                            rateController.text.trim(),
                                          );

                                          final double? discount =
                                              double.tryParse(
                                            discountController.text.trim(),
                                          );

                                          final double? tax = double.tryParse(
                                            taxController.text.trim(),
                                          );

                                          if (quantity == null ||
                                              quantity <= 0) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                  'Enter a valid quantity.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (rate == null || rate < 0) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                  'Enter a valid rate.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (discount == null ||
                                              discount < 0) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                  'Enter a valid discount.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (tax == null || tax < 0) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                  'Enter a valid tax.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          final int productId = _asInt(
                                            item['product_id'],
                                          );

                                          if (productId <= 0) {
                                            await _showStockVerificationErrorDialog(
                                              message:
                                                  'Unable to verify product stock. Please contact the Accounts department.',
                                            );
                                            return;
                                          }

                                          final num? availableStock =
                                              await fetchAvailableStockForProduct(
                                            productId: productId,
                                            productName: _safeText(
                                              item['name'],
                                              fallback: '',
                                            ),
                                          );

                                          if (!dialogContext.mounted) {
                                            return;
                                          }

                                          if (availableStock == null) {
                                            await _showStockVerificationErrorDialog(
                                              message:
                                                  'Unable to verify available stock. Please try again or contact the Accounts department.',
                                            );
                                            return;
                                          }

                                          if (quantity > availableStock) {
                                            await _showInsufficientStockDialog(
                                              productName: _safeText(
                                                item['name'],
                                              ),
                                              requestedQuantity: quantity,
                                              availableStock: availableStock,
                                            );
                                            return;
                                          }

                                          setDialogState(() {
                                            isUpdating = true;
                                          });

                                          final bool success =
                                              await updateProformaItem(
                                            orderId: orderId,
                                            itemId: _asInt(item['id']),
                                            quantity: quantity,
                                            rate: rate,
                                            discount: discount,
                                            tax: tax,
                                            description:
                                                descriptionController.text,
                                          );

                                          if (!mounted) return;

                                          if (!dialogContext.mounted) {
                                            return;
                                          }

                                          if (success) {
                                            Navigator.of(dialogContext).pop();
                                          } else {
                                            setDialogState(() {
                                              isUpdating = false;
                                            });
                                          }
                                        },
                                  icon: isUpdating
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_outlined,
                                          size: 18,
                                        ),
                                  label: Text(
                                    isUpdating
                                        ? 'Updating...'
                                        : 'Update Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    elevation: 0,
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  String _safeText(dynamic value, {String fallback = "—"}) {
    final text = value?.toString().trim() ?? "";
    return text.isEmpty ? fallback : text;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? "") ?? 0.0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  String _currency(dynamic value) {
    return "₹${_asDouble(value).toStringAsFixed(2)}";
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();

    if (normalized.contains("approved") ||
        normalized.contains("confirmed") ||
        normalized.contains("created")) {
      return const Color(0xFF027A48);
    }

    if (normalized.contains("rejected") ||
        normalized.contains("cancelled") ||
        normalized.contains("disapproved")) {
      return const Color(0xFFB42318);
    }

    if (normalized.contains("pending") ||
        normalized.contains("waiting") ||
        normalized.contains("progress")) {
      return const Color(0xFFB54708);
    }

    return const Color(0xFF175CD3);
  }

  Color _statusBackground(String status) {
    final normalized = status.toLowerCase();

    if (normalized.contains("approved") ||
        normalized.contains("confirmed") ||
        normalized.contains("created")) {
      return const Color(0xFFECFDF3);
    }

    if (normalized.contains("rejected") ||
        normalized.contains("cancelled") ||
        normalized.contains("disapproved")) {
      return const Color(0xFFFEF3F2);
    }

    if (normalized.contains("pending") ||
        normalized.contains("waiting") ||
        normalized.contains("progress")) {
      return const Color(0xFFFFFAEB);
    }

    return const Color(0xFFEFF8FF);
  }

  Widget _statusChip(String status) {
    final displayStatus = _safeText(status, fallback: "Unknown");

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _statusBackground(displayStatus),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: _statusColor(displayStatus),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
    bool showFullValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEAECF0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 19,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: showFullValue ? null : 2,
                  overflow: showFullValue
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF101828),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101828),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard({
    required int orderId,
    required Map<String, dynamic> item,
  }) {
    final quantity = _asInt(item['quantity']);
    final rate = _asDouble(item['rate']);
    final discountPerItem = _asDouble(item['discount']);
    final discountTotal = quantity * discountPerItem;
    final lineTotal = (quantity * rate) - discountTotal;
    final imagePath = item['first_image']?.toString() ?? "";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showEditProductDialog(
            orderId: orderId,
            item: item,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEAECF0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imagePath.isNotEmpty
                    ? Image.network(
                        "$api$imagePath",
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 76,
                            height: 76,
                            color: const Color(0xFFF2F4F7),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF98A2B3),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 76,
                        height: 76,
                        color: const Color(0xFFF2F4F7),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safeText(item['name']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _itemBadge(
                          icon: Icons.shopping_bag_outlined,
                          text: "Qty $quantity",
                        ),
                        _itemBadge(
                          icon: Icons.currency_rupee_rounded,
                          text: rate.toStringAsFixed(2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Discount: ${_currency(discountTotal)}",
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFB42318),
                            ),
                          ),
                        ),
                        Text(
                          _currency(lineTotal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF027A48),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            _confirmDeleteProformaItem(
                              orderId: orderId,
                              item: item,
                            );
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFB42318),
                            ),
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
  }

  Widget _itemBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: const Color(0xFF667085),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475467),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logReturnedProductChanges(
      int orderId, Map<String, dynamic> before) async {
    // Observe persisted changes made by the separate Add Product screen.
    // This is a before/after observation, not its original HTTP response.
    try {
      final token = await getTokenFromPrefs();
      if (token == null || token.trim().isEmpty) return;
      final response = await http.get(
        Uri.parse('$api/api/perfoma/${widget.invoice}/invoice/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return;
      final dynamic after = jsonDecode(response.body);
      if (after is! Map || after['perfoma_items'] is! List) return;
      Map<String, Map<String, dynamic>> indexItems(dynamic rows) {
        final result = <String, Map<String, dynamic>>{};
        if (rows is List) {
          for (final row in rows) {
            if (row is Map && row['id'] != null) {
              result[row['id'].toString()] = Map<String, dynamic>.from(row);
            }
          }
        }
        return result;
      }

      final previous = indexItems(before['perfoma_items']);
      final current = indexItems(after['perfoma_items']);
      for (final id in {...previous.keys, ...current.keys}) {
        final oldItem = previous[id];
        final newItem = current[id];
        if (jsonEncode(oldItem) == jsonEncode(newItem)) continue;
        final action = oldItem == null
            ? 'added'
            : newItem == null
                ? 'deleted'
                : 'updated';
        final logged = await AuditLogService.log(
          action: 'proforma_item_${action}_observed',
          orderId: null,
          beforeData: {
            'proforma_id': orderId,
            'invoice': widget.invoice,
            'item_id': id,
            'item_details': oldItem
          },
          afterData: {
            'proforma_id': orderId,
            'invoice': widget.invoice,
            'item_id': id,
            'item_details': newItem,
            'metadata': {
              'source': 'PerformaInvoice_BigView_List',
              'observation': 'after_return_from_add_product_page',
              'recorded_at': DateTime.now().toUtc().toIso8601String()
            }
          },
        );
        if (!logged) debugPrint('Product change audit log failed [$id].');
      }
    } catch (error, stackTrace) {
      debugPrint('Product change audit log failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _openAddProductPage(int orderId) async {
    final before =
        Map<String, dynamic>.from(_auditCopy(_loadedProforma) as Map);
    final bool? productAdded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePerformaProduct_List(
          proformaOrderId: orderId,
        ),
      ),
    );

    await _logReturnedProductChanges(orderId, before);
    if (!mounted || productAdded != true) return;

    await fetchperformalistData();
  }

  Future<void> _openInvoiceUrl(String invoice) async {
    final Uri url = Uri.parse('$api/performainvoice/$invoice/');

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to open the invoice."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to open the invoice."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              "Proforma Invoice",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF101828),
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Review invoice details and continue to order",
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInitialData,
                child: _buildBody(),
              ),
            ),
            if (!isLoading &&
                loadError == null &&
                orders.isNotEmpty &&
                _canGenerateInvoice)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFEAECF0),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => proforma_to_order_request(
                              invoice: widget.invoice,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.receipt_long_outlined,
                        size: 20,
                      ),
                      label: const Text(
                        "Generate Invoice",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 180),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (loadError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEAECF0),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 42,
                  color: Color(0xFFB42318),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Unable to load invoice",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadInitialData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Retry"),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEAECF0),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 44,
                  color: Color(0xFF98A2B3),
                ),
                SizedBox(height: 12),
                Text(
                  "No invoice details found",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF101828),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "The selected proforma invoice does not contain any details.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final items = (order['perfoma_items'] as List<dynamic>? ?? []);

        return Column(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "PROFORMA INVOICE",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Color(0xFFDCEBFF),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "#${_safeText(order['invoice'])}",
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: "Open invoice",
                        onPressed: () => _openInvoiceUrl(
                          _safeText(order['invoice'], fallback: ""),
                        ),
                        icon: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _safeText(order['order_date']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _statusChip(
                          _safeText(order['status'], fallback: "Unknown"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  _sectionTitle(
                    icon: Icons.person_outline_rounded,
                    title: "Customer & Order Details",
                    subtitle:
                        "Invoice ownership, customer and delivery information.",
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showEditOrderDetailsDialog(
                          Map<String, dynamic>.from(order),
                        );
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 17,
                      ),
                      label: const Text(
                        "Edit Details",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(
                          color: Color(0xFFB2CCFF),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _summaryTile(
                    icon: Icons.person_outline_rounded,
                    label: "Customer",
                    value: _safeText(order['customer_name']),
                  ),
                  const SizedBox(height: 10),
                  _summaryTile(
                    icon: Icons.business_outlined,
                    label: "Company",
                    value: _safeText(order['company_name']),
                  ),
                  const SizedBox(height: 10),
                  _summaryTile(
                    icon: Icons.manage_accounts_outlined,
                    label: "Managed By",
                    value: _safeText(order['maneger']),
                  ),
                  const SizedBox(height: 10),
                  _summaryTile(
                    icon: Icons.category_outlined,
                    label: "Family",
                    value: _safeText(order['family_name']),
                  ),
                  const SizedBox(height: 10),
                  _summaryTile(
                    icon: Icons.location_on_outlined,
                    label: "State",
                    value: _safeText(order['state']),
                  ),
                  const SizedBox(height: 10),
                  _summaryTile(
                    icon: Icons.home_work_outlined,
                    label: "Address",
                    value: _safeText(order['address']),
                    showFullValue: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  _sectionTitle(
                    icon: Icons.inventory_2_outlined,
                    title: "Invoice Items",
                    subtitle:
                        "${items.length} product${items.length == 1 ? "" : "s"} included in this proforma.",
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _openAddProductPage(
                        _asInt(order['id']),
                      ),
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        "Add Product",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(
                          color: Color(0xFF2563EB),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        "No products are available in this invoice.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF667085),
                        ),
                      ),
                    )
                  else
                    ...items.map(
                      (item) => _buildItemCard(
                        orderId: _asInt(order['id']),
                        item: Map<String, dynamic>.from(item),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFABEFC6),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF027A48),
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Invoice Total",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF027A48),
                            ),
                          ),
                        ),
                        Text(
                          _currency(order['total_amount']),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF027A48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProformaPaymentSlips(
              key: ValueKey(_asInt(order['id'])),
              proformaId: _asInt(order['id']),
              invoice: widget.invoice.toString(),
              getToken: getTokenFromPrefs,
            ),
            const SizedBox(height: 16),
            _ProformaNotes(
              key: ValueKey('notes-${order['id']}'),
              note: order['note']?.toString() ?? '',
              courierNote: order['parcel_note']?.toString() ?? '',
              onSave: (note, courierNote) => _saveProformaNotes(
                _asInt(order['id']),
                note,
                courierNote,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProformaPaymentSlips extends StatefulWidget {
  final int proformaId;
  final String invoice;
  final Future<String?> Function() getToken;
  const _ProformaPaymentSlips(
      {super.key, required this.proformaId, required this.invoice, required this.getToken});

  @override
  State<_ProformaPaymentSlips> createState() => _ProformaPaymentSlipsState();
}

class _ProformaPaymentSlipsState extends State<_ProformaPaymentSlips> {
  final ImagePicker _picker = ImagePicker();
  final http.Client _client = http.Client();
  List<XFile> _selected = [];
  List<String> _images = [];
  bool _loading = false;
  bool _uploading = false;
  bool _picking = false;
  String? _error;
  Map<String, String> _imageHeaders = {};

  @override
  void initState() {
    super.initState();
    _loadSlips();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Uri _endpoint(String path) =>
      Uri.parse('${api.toString().replaceFirst(RegExp(r'/+$'), '')}$path');

  Future<String> _token() async {
    final token = await widget.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    return token;
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  List<String> _parseImages(dynamic payload) {
    dynamic rows = payload;
    for (var depth = 0; depth < 5 && rows is Map; depth++) {
      dynamic nested;
      for (final key in [
        'results',
        'data',
        'payment_slips',
        'slips',
        'files'
      ]) {
        if (rows[key] is List || rows[key] is Map) {
          nested = rows[key];
          break;
        }
      }
      if (nested == null) {
        rows = [rows];
        break;
      }
      rows = nested;
    }
    if (rows is! List)
      throw const FormatException('Unexpected payment slips response.');
    final urls = <String>[];
    for (final row in rows) {
      dynamic value = row;
      if (row is Map) {
        value = row['file_url'] ??
            row['image_url'] ??
            row['file'] ??
            row['image'] ??
            row['payment_slip'] ??
            row['slip'] ??
            row['url'];
      }
      if (value is Map) value = value['url'] ?? value['file'] ?? value['image'];
      if (value is! String || value.trim().isEmpty) continue;
      final base = _endpoint('/');
      final uri = base.resolve(value.trim());
      if (uri.scheme == 'http' || uri.scheme == 'https')
        urls.add(uri.toString());
    }
    if (rows.isNotEmpty && urls.isEmpty) {
      throw const FormatException(
          'Payment slips received, but no image URL was found.');
    }
    return urls.toSet().toList();
  }

  Future<void> _loadSlips() async {
    if (_loading || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (widget.proformaId <= 0) throw Exception('Invalid proforma ID.');
      final response = await _client.get(
        _endpoint('/api/perfoma/payment/slips/${widget.proformaId}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception(
            'Unable to load payment slips (${response.statusCode}).');
      }
      final images = _parseImages(jsonDecode(response.body));
      if (!mounted) return;
      setState(() {
        _images = images;
        _imageHeaders = {'Authorization': 'Bearer $token'};
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
        });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _pickImages() async {
    if (_picking || _uploading) return;
    setState(() {
      _picking = true;
    });
    try {
      final images = await _picker.pickMultiImage();
      if (!mounted || images.isEmpty) return;
      setState(() {
        final existing = _selected.map((file) => file.path).toSet();
        _selected.addAll(images.where((file) => existing.add(file.path)));
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Unable to select images. Please check photo access.')),
        );
    } finally {
      if (mounted)
        setState(() {
          _picking = false;
        });
    }
  }

  Future<http.Response> _sendAuditedUpload(
      http.MultipartRequest request) async {
    final before = <String, dynamic>{
      'proforma_id': widget.proformaId,
      'invoice': widget.invoice,
      'payment_slip_urls': List<String>.from(_images),
    };
    final submitted = <String, dynamic>{
      'fields': Map<String, String>.from(request.fields),
      'files': request.files
          .map((file) => <String, dynamic>{
                'field': file.field,
                'filename': file.filename,
                'size_bytes': file.length,
                'content_type': file.contentType.toString(),
              })
          .toList(),
    };
    Future<void> record({http.Response? response, Object? error}) async {
      try {
        final success = response != null &&
            response.statusCode >= 200 &&
            response.statusCode < 300;
        dynamic responseData;
        if (response != null && response.body.trim().isNotEmpty) {
          try {
            responseData = jsonDecode(response.body);
          } catch (_) {
            responseData = response.body;
          }
        }
        final logged = await AuditLogService.log(
          action: success
              ? 'proforma_payment_slips_uploaded'
              : 'proforma_payment_slips_uploaded_failed',
          orderId: null,
          beforeData: before,
          afterData: {
            'proforma_id': widget.proformaId,
      'invoice': widget.invoice,
            'submitted_data': submitted,
            'response_data': responseData,
            'outcome': success ? 'success' : 'failed',
            if (error != null) 'error_type': error.runtimeType.toString(),
            'metadata': {
              'source': 'PerformaInvoice_BigView_List',
              'method': request.method,
              'endpoint': request.url.path,
              if (response != null) 'http_status': response.statusCode,
              'recorded_at': DateTime.now().toUtc().toIso8601String(),
            },
          },
        );
        if (!logged) debugPrint('Payment slip audit log creation failed.');
      } catch (error, stackTrace) {
        debugPrint('Payment slip audit log creation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    late final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (error) {
      await record(error: error);
      rethrow;
    }
    await record(response: response);
    return response;
  }

  Future<void> _uploadImages() async {
    if (_uploading || _selected.isEmpty || widget.proformaId <= 0) return;
    setState(() {
      _uploading = true;
    });
    try {
      final token = await _token();
      final request = http.MultipartRequest(
          'POST', _endpoint('/api/perfoma/payment/slips/upload/'))
        ..headers.addAll(
            {'Authorization': 'Bearer $token', 'Accept': 'application/json'})
        ..fields['proforma'] = widget.proformaId.toString();
      for (final file in List<XFile>.of(_selected)) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty)
          throw Exception(
              '${file.name} is empty. Please select another image.');
        final extension = file.name.split('.').last.toLowerCase();
        final mime = file.mimeType ??
            const {
              'jpg': 'image/jpeg',
              'jpeg': 'image/jpeg',
              'png': 'image/png',
              'webp': 'image/webp',
              'gif': 'image/gif',
              'heic': 'image/heic',
              'heif': 'image/heif',
            }[extension];
        if (mime == null || !mime.startsWith('image/')) {
          throw Exception('Please select supported image files.');
        }
        request.files.add(http.MultipartFile.fromBytes('files', bytes,
            filename: file.name, contentType: MediaType.parse(mime)));
      }
      final response = await _sendAuditedUpload(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Payment slip upload failed (${response.statusCode}).');
      }
      if (!mounted) return;
      setState(() {
        _selected = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment slips uploaded successfully.')),
      );
      await _loadSlips();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message(error))),
        );
    } finally {
      if (mounted)
        setState(() {
          _uploading = false;
        });
    }
  }

  Map<String, String> _headersFor(String url) =>
      Uri.parse(url).origin == _endpoint('/').origin
          ? _imageHeaders
          : <String, String>{};

  void _preview(String url) {
    showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
              child: SizedBox(
                height: MediaQuery.of(dialogContext).size.height * 0.75,
                child: Column(children: [
                  Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      )),
                  Expanded(
                      child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5,
                          child: Image.network(url,
                              headers: _headersFor(url),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Unable to display image.'))))),
                ]),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEAECF0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Payment Slips',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828)))),
          IconButton(
              tooltip: 'Refresh payment slips',
              onPressed: _loading || _uploading ? null : _loadSlips,
              icon: const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height: 6),
        const Text('Upload payment images for this proforma.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF667085))),
        const SizedBox(height: 14),
        OutlinedButton.icon(
            onPressed: _uploading || _picking ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_picking ? 'Selecting images…' : 'Select Images')),
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._selected.asMap().entries.map((entry) => Row(children: [
                const Icon(Icons.image_outlined,
                    size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(entry.value.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                IconButton(
                    tooltip: 'Remove selected image',
                    onPressed: _uploading
                        ? null
                        : () => setState(() {
                              _selected.removeAt(entry.key);
                            }),
                    icon: const Icon(Icons.close, size: 18)),
              ])),
          ElevatedButton.icon(
              onPressed: _uploading || _loading ? null : _uploadImages,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white),
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_uploading
                  ? 'Uploading…'
                  : 'Upload ${_selected.length} Image${_selected.length == 1 ? '' : 's'}')),
        ],
        const SizedBox(height: 14),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: _loading || _uploading ? null : _loadSlips,
                  child: const Text('Retry'))),
        ],
        if (!_loading && _error == null && _images.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No payment slips uploaded yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF667085)))),
        if (_images.isNotEmpty)
          Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _images
                  .map((url) => InkWell(
                      onTap: () => _preview(url),
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            headers: _headersFor(url),
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                        width: 110,
                                        height: 110,
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))),
                            errorBuilder: (_, __, ___) => Container(
                                width: 110,
                                height: 110,
                                color: const Color(0xFFF2F4F7),
                                child: const Icon(Icons.broken_image_outlined)),
                          ))))
                  .toList()),
      ]),
    );
  }
}

class _ProformaNotes extends StatefulWidget {
  final String note;
  final String courierNote;
  final Future<Map<String, String>> Function(String note, String courierNote)
      onSave;

  const _ProformaNotes(
      {super.key,
      required this.note,
      required this.courierNote,
      required this.onSave});

  @override
  State<_ProformaNotes> createState() => _ProformaNotesState();
}

class _ProformaNotesState extends State<_ProformaNotes> {
  late final TextEditingController _accountsController;
  late final TextEditingController _courierController;
  late String _savedNote;
  late String _savedCourierNote;
  bool _saving = false;

  bool get _hasChanges =>
      _accountsController.text != _savedNote ||
      _courierController.text != _savedCourierNote;

  @override
  void initState() {
    super.initState();
    _savedNote = widget.note;
    _savedCourierNote = widget.courierNote;
    _accountsController = TextEditingController(text: _savedNote);
    _courierController = TextEditingController(text: _savedCourierNote);
  }

  @override
  void didUpdateWidget(covariant _ProformaNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Preserve unsaved typing during unrelated page refreshes.
    if (!_saving &&
        !_hasChanges &&
        (widget.note != oldWidget.note ||
            widget.courierNote != oldWidget.courierNote)) {
      _savedNote = widget.note;
      _savedCourierNote = widget.courierNote;
      _accountsController.text = _savedNote;
      _courierController.text = _savedCourierNote;
    }
  }

  @override
  void dispose() {
    _accountsController.dispose();
    _courierController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_hasChanges) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
    });
    try {
      final saved = await widget.onSave(
          _accountsController.text, _courierController.text);
      if (!mounted) return;
      setState(() {
        _savedNote = saved['note'] ?? '';
        _savedCourierNote = saved['parcel_note'] ?? '';
        _accountsController.text = _savedNote;
        _courierController.text = _savedCourierNote;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF027A48),
          content: Text('Proforma notes updated successfully.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFFB42318),
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted)
        setState(() {
          _saving = false;
        });
    }
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0D5DD))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAECF0))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.notes_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Expanded(
                child: Text('Proforma Notes',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828)))),
          ]),
          const SizedBox(height: 18),
          TextField(
              controller: _accountsController,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Accounts Note', 'Enter accounts note')),
          const SizedBox(height: 16),
          TextField(
              controller: _courierController,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Courier Note', 'Enter courier note')),
          const SizedBox(height: 16),
          SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _saving || !_hasChanges ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 19),
                label: Text(_saving ? 'Saving…' : 'Save Notes'),
              )),
        ]),
      );
}
