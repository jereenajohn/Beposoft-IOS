import 'dart:async';
import 'dart:convert';

import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/HR/hr_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtherReceiptListPage extends StatefulWidget {
  const OtherReceiptListPage({super.key});

  @override
  State<OtherReceiptListPage> createState() => _OtherReceiptListPageState();
}

class _OtherReceiptListPageState extends State<OtherReceiptListPage> {
  // ---------------------------------------------------------------------------
  // CONSTANTS
  // ---------------------------------------------------------------------------

  static const int _perPage = 10;

  final Color _primaryColor = const Color(0xFF024160);
  final Color _primarySoft = const Color(0xFFE3F2FD);
  final Color _accentColor = const Color(0xFF2196F3);
  final Color _pageBackground = const Color(0xFFF5F7FB);
  final Color _borderColor = const Color(0xFFE0E8F2);
  final Color _mutedTextColor = const Color(0xFF667785);

  // ---------------------------------------------------------------------------
  // PAGE STATE
  // ---------------------------------------------------------------------------

  bool _isLoading = true;
  bool _isSaving = false;

  String? _role;

  int _currentPage = 1;

  DateTime? _startDate;
  DateTime? _endDate;

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _banks = [];

  Map<String, dynamic>? _selectedReceipt;
  Map<String, dynamic>? _originalReceipt;

  // ---------------------------------------------------------------------------
  // FORM STATE
  // ---------------------------------------------------------------------------

  int? _selectedBankId;

  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedOrder;

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _receiptController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _receivedAtController = TextEditingController();
  final TextEditingController _createdByController = TextEditingController();

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadRole();

    await Future.wait([
      _fetchBanks(),
      _fetchReceipts(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _searchController.dispose();
    _receiptController.dispose();
    _amountController.dispose();
    _transactionController.dispose();
    _remarkController.dispose();
    _receivedAtController.dispose();
    _createdByController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SHARED PREFERENCES
  // ---------------------------------------------------------------------------

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> _getDepartment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('department');
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();

    // React uses localStorage.getItem("active").
    // Existing Flutter pages normally use department.
    final active = prefs.getString('active');
    final department = prefs.getString('department');

    if (!mounted) return;

    setState(() {
      _role = active ?? department;
    });
  }

  // ---------------------------------------------------------------------------
  // API HEADERS
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _jsonHeaders() async {
    final token = await _getToken();

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ---------------------------------------------------------------------------
  // FETCH BANKS
  // ---------------------------------------------------------------------------

  Future<void> _fetchBanks() async {
    try {
      final headers = await _jsonHeaders();

      final response = await http.get(
        Uri.parse('$api/api/banks/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final dynamic rawData = decoded is Map<String, dynamic>
            ? decoded['data']
            : null;

        final List<dynamic> data =
            rawData is List ? rawData : <dynamic>[];

        if (!mounted) return;

        setState(() {
          _banks = data
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        });
      } else {
        _showError('Failed to fetch banks.');
      }
    } catch (e) {
      debugPrint('Fetch banks error: $e');

      _showError('Error fetching banks.');
    }
  }

  // ---------------------------------------------------------------------------
  // FETCH RECEIPTS
  // ---------------------------------------------------------------------------

  Future<void> _fetchReceipts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final headers = await _jsonHeaders();

      final response = await http.get(
        Uri.parse('$api/api/bankreceipt/view/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> data = [];

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            data = decoded['data'];
          } else if (decoded['results'] is List) {
            data = decoded['results'];
          }
        }

        if (!mounted) return;

        setState(() {
          _receipts = data
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();

          _fixCurrentPage();
        });
      } else {
        debugPrint(
          'Receipt fetch failed: ${response.statusCode} ${response.body}',
        );

        _showError('Failed to fetch receipt data.');
      }
    } catch (e) {
      debugPrint('Fetch receipts error: $e');

      _showError('Error fetching receipt data.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RECEIPT DETAILS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchReceiptDetails(int id) async {
    try {
      final headers = await _jsonHeaders();

      final response = await http.get(
        Uri.parse('$api/api/bankreceipt/view/$id/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      debugPrint(
        'Receipt details failed: ${response.statusCode} ${response.body}',
      );

      _showError('Error fetching receipt details.');

      return null;
    } catch (e) {
      debugPrint('Receipt details error: $e');

      _showError('Error fetching receipt details.');

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH CUSTOMERS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _searchCustomers(
    String search,
  ) async {
    if (search.trim().isEmpty) {
      return [];
    }

    try {
      final headers = await _jsonHeaders();

      final uri = Uri.parse(
        '$api/api/customers/',
      ).replace(
        queryParameters: {
          'search': search.trim(),
        },
      );

      final response = await http.get(
        uri,
        headers: headers,
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Customer search failed: '
          '${response.statusCode} ${response.body}',
        );

        return [];
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> data = [];

      if (decoded is Map<String, dynamic>) {
        if (decoded['results'] is List) {
          data = decoded['results'];
        } else if (decoded['data'] is List) {
          data = decoded['data'];
        }
      } else if (decoded is List) {
        data = decoded;
      }

      return data
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      debugPrint('Customer search error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH ORDERS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _searchOrders(
    String search,
  ) async {
    if (search.trim().isEmpty) {
      return [];
    }

    try {
      final headers = await _jsonHeaders();

      final uri = Uri.parse(
        '$api/api/orders/',
      ).replace(
        queryParameters: {
          'search': search.trim(),
        },
      );

      final response = await http.get(
        uri,
        headers: headers,
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Order search failed: '
          '${response.statusCode} ${response.body}',
        );

        return [];
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> data = [];

      if (decoded is Map<String, dynamic>) {
        final results = decoded['results'];

        if (results is Map<String, dynamic> &&
            results['results'] is List) {
          data = results['results'];
        } else if (results is List) {
          data = results;
        } else if (decoded['data'] is List) {
          data = decoded['data'];
        }
      } else if (decoded is List) {
        data = decoded;
      }

      return data
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      debugPrint('Order search error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // OPEN RECEIPT
  // ---------------------------------------------------------------------------

  Future<void> _openReceipt(int id) async {
    _resetReceiptForm();

    _showLoadingDialog();

    final data = await _fetchReceiptDetails(id);

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    if (data == null) {
      return;
    }

    _selectedReceipt = Map<String, dynamic>.from(data);
    _originalReceipt = Map<String, dynamic>.from(data);

    _selectedBankId = _parseInt(data['bank']);

    _receiptController.text =
        _normalize(data['payment_receipt']);

    _amountController.text =
        _normalize(data['amount']);

    _transactionController.text =
        _normalize(data['transactionID']);

    _remarkController.text =
        _normalize(data['remark']);

    _receivedAtController.text =
        _normalize(data['received_at']);

    _createdByController.text =
        _normalize(data['created_by_name']);

    _selectedCustomer = null;
    _selectedOrder = null;

    await _showReceiptDialog();
  }

  // ---------------------------------------------------------------------------
  // UPDATE / CONVERT
  // ---------------------------------------------------------------------------

  Future<void> _handleUpdate() async {
    if (_selectedReceipt == null ||
        _selectedReceipt!['id'] == null) {
      _showError('Receipt not selected.');
      return;
    }

    if (_isSaving) {
      return;
    }

    if (_selectedBankId == null) {
      _showError('Please select a bank.');
      return;
    }

    final amount =
        double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount.');
      return;
    }

    if (_receivedAtController.text.trim().isEmpty) {
      _showError('Please select received date.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final Map<String, dynamic> submittedData = {
      'bank': _selectedBankId,
      'amount': _amountController.text.trim(),
      'payment_receipt': _receiptController.text.trim(),
      'created_by_name': _createdByController.text.trim(),
      'transactionID': _transactionController.text.trim(),
      'remark': _remarkController.text.trim(),
      'received_at': _receivedAtController.text.trim(),
      'customer': _selectedCustomer?['id'],
      'order': _selectedOrder?['id'],
    };

    try {
      if (_selectedCustomer != null) {
        await _convertToAdvanceReceipt(submittedData);
      } else if (_selectedOrder != null) {
        await _convertToOrderReceipt(submittedData);
      } else {
        await _updateOtherReceipt(submittedData);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // NORMAL UPDATE
  // ---------------------------------------------------------------------------

  Future<void> _updateOtherReceipt(
    Map<String, dynamic> submittedData,
  ) async {
    final receiptId = _parseInt(_selectedReceipt?['id']);

    if (receiptId == null) {
      _showError('Invalid receipt.');
      return;
    }

    try {
      final headers = await _jsonHeaders();

      final payload = {
        'payment_receipt':
            submittedData['payment_receipt'],
        'bank':
            submittedData['bank'],
        'amount':
            submittedData['amount'],
        'transactionID':
            submittedData['transactionID'],
        'received_at':
            submittedData['received_at'],
        'remark':
            submittedData['remark'],
        'created_by':
            _selectedReceipt?['created_by'],
      };

      final response = await http.put(
        Uri.parse(
          '$api/api/bankreceipt/view/$receiptId/',
        ),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        if (_originalReceipt != null) {
          final auditCreated =
              await _createOtherReceiptDataLog(
            receiptId: receiptId,
            beforeObject: _originalReceipt!,
            afterObject: submittedData,
            mode: 'update',
          );

          if (!auditCreated) {
            _showWarning(
              'Receipt updated, but logging to DataLog failed.',
            );
          }
        }

        _showSuccess('Receipt updated successfully!');

        if (mounted) {
          Navigator.of(context).pop();
        }

        _resetReceiptForm();

        await _fetchReceipts();
      } else {
        debugPrint(
          'Update receipt failed: '
          '${response.statusCode} ${response.body}',
        );

        _showApiError(
          response,
          fallback: 'Failed to update receipt.',
        );
      }
    } catch (e) {
      debugPrint('Update receipt error: $e');

      _showError('Failed to update receipt.');
    }
  }

  // ---------------------------------------------------------------------------
  // CONVERT TO ADVANCE RECEIPT
  // ---------------------------------------------------------------------------

  Future<void> _convertToAdvanceReceipt(
    Map<String, dynamic> submittedData,
  ) async {
    final receiptId = _parseInt(_selectedReceipt?['id']);

    if (receiptId == null) {
      _showError('Invalid receipt.');
      return;
    }

    final customerId =
        _parseInt(submittedData['customer']);

    if (customerId == null) {
      _showError('Please select a customer.');
      return;
    }

    try {
      final headers = await _jsonHeaders();

      final payload = {
        'bank': submittedData['bank'],
        'amount': submittedData['amount'],
        'received_at': submittedData['received_at'],
        'transactionID': submittedData['transactionID'],
        'remark': submittedData['remark'],
        'customer': customerId,
      };

      final response = await http.post(
        Uri.parse('$api/api/advancereceipt/'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        if (_originalReceipt != null) {
          final auditCreated =
              await _createOtherReceiptDataLog(
            receiptId: receiptId,
            beforeObject: _originalReceipt!,
            afterObject: submittedData,
            mode: 'toAdvance',
          );

          if (!auditCreated) {
            _showWarning(
              'Advance Receipt created, but logging to DataLog failed.',
            );
          }
        }

        final deleted =
            await _deleteOriginalReceipt(receiptId);

        if (!deleted) {
          _showWarning(
            'Advance Receipt was created, but original receipt '
            'could not be deleted.',
          );

          return;
        }

        _showSuccess(
          'Advance Receipt created successfully.',
        );

        if (mounted) {
          Navigator.of(context).pop();
        }

        _resetReceiptForm();

        await _fetchReceipts();
      } else {
        debugPrint(
          'Advance receipt creation failed: '
          '${response.statusCode} ${response.body}',
        );

        _showApiError(
          response,
          fallback: 'Failed to create Advance Receipt.',
        );
      }
    } catch (e) {
      debugPrint('Advance receipt conversion error: $e');

      _showError(
        'Failed to convert receipt to Advance Receipt.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CONVERT TO ORDER RECEIPT
  // ---------------------------------------------------------------------------

  Future<void> _convertToOrderReceipt(
    Map<String, dynamic> submittedData,
  ) async {
    final receiptId = _parseInt(_selectedReceipt?['id']);

    final orderId =
        _parseInt(submittedData['order']);

    if (receiptId == null || orderId == null) {
      _showError('Invalid receipt or order.');
      return;
    }

    try {
      final headers = await _jsonHeaders();

      final payload = {
        'bank': submittedData['bank'],
        'amount': submittedData['amount'],
        'received_at': submittedData['received_at'],
        'transactionID': submittedData['transactionID'],
        'remark': submittedData['remark'],
      };

      // "reciept" is intentionally kept because this is
      // exactly how the existing backend endpoint is named.
      final response = await http.post(
        Uri.parse(
          '$api/api/payment/$orderId/reciept/',
        ),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        if (_originalReceipt != null) {
          final auditCreated =
              await _createOtherReceiptDataLog(
            receiptId: receiptId,
            beforeObject: _originalReceipt!,
            afterObject: submittedData,
            mode: 'toOrder',
          );

          if (!auditCreated) {
            _showWarning(
              'Order Receipt created, but logging to DataLog failed.',
            );
          }
        }

        final deleted =
            await _deleteOriginalReceipt(receiptId);

        if (!deleted) {
          _showWarning(
            'Order Receipt was created, but original receipt '
            'could not be deleted.',
          );

          return;
        }

        _showSuccess(
          'Order Receipt created successfully.',
        );

        if (mounted) {
          Navigator.of(context).pop();
        }

        _resetReceiptForm();

        await _fetchReceipts();
      } else {
        debugPrint(
          'Order receipt creation failed: '
          '${response.statusCode} ${response.body}',
        );

        _showApiError(
          response,
          fallback: 'Failed to create Order Receipt.',
        );
      }
    } catch (e) {
      debugPrint('Order receipt conversion error: $e');

      _showError(
        'Failed to convert receipt to Order Receipt.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE ORIGINAL RECEIPT AFTER CONVERSION
  // ---------------------------------------------------------------------------

  Future<bool> _deleteOriginalReceipt(int receiptId) async {
    try {
      final headers = await _jsonHeaders();

      final response = await http.delete(
        Uri.parse(
          '$api/api/bankreceipt/view/$receiptId/',
        ),
        headers: headers,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        return true;
      }

      debugPrint(
        'Delete original receipt failed: '
        '${response.statusCode} ${response.body}',
      );

      return false;
    } catch (e) {
      debugPrint('Delete original receipt error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // AUDIT LOG
  // ---------------------------------------------------------------------------

  Future<bool> _createOtherReceiptDataLog({
    required int receiptId,
    required Map<String, dynamic> beforeObject,
    required Map<String, dynamic> afterObject,
    String mode = 'update',
  }) async {
    try {
      final changeSet = _buildChangeSet(
        beforeObject,
        afterObject,
        mode,
      );

      final beforeData =
          Map<String, dynamic>.from(
        changeSet['before_data'] ?? {},
      );

      final afterData =
          Map<String, dynamic>.from(
        changeSet['after_data'] ?? {},
      );

      if (beforeData.isEmpty && afterData.isEmpty) {
        return true;
      }

      String action = 'other_receipt_updated_flutter';

      if (mode == 'toAdvance') {
        action =
            'other_receipt_converted_to_advance_receipt_flutter';
      } else if (mode == 'toOrder') {
        action =
            'other_receipt_converted_to_order_receipt_flutter';
      }

      final token = await _getToken();

      final payload = <String, dynamic>{
        'before_data': {
          'action': action,
          'other_receipt_id': receiptId,
          ...beforeData,
        },
        'after_data': {
          'action': action,
          'other_receipt_id': receiptId,
          ...afterData,
        },
      };

      if (mode == 'toOrder' &&
          afterObject['order'] != null) {
        payload['order'] = afterObject['order'];
      } else {
        payload['order'] = null;
      }

      final response = await http.post(
        Uri.parse('$api/api/datalog/create/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        return true;
      }

      debugPrint(
        'Other Receipt DataLog failed: '
        '${response.statusCode} ${response.body}',
      );

      return false;
    } catch (e) {
      debugPrint(
        'Other Receipt DataLog creation error: $e',
      );

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD AUDIT CHANGE SET
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildChangeSet(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    String mode,
  ) {
    final Map<String, dynamic> beforeData = {};
    final Map<String, dynamic> afterData = {};

    final beforeBankId = _parseInt(before['bank']);
    final afterBankId = _parseInt(after['bank']);

    final beforeBankName =
        _bankNameById(beforeBankId);

    final afterBankName =
        _bankNameById(afterBankId);

    if (beforeBankName != afterBankName) {
      beforeData['bank'] = beforeBankName;
      afterData['bank'] = afterBankName;
    }

    _addChangedField(
      beforeData,
      afterData,
      'payment_receipt',
      before['payment_receipt'],
      after['payment_receipt'],
    );

    _addChangedField(
      beforeData,
      afterData,
      'amount',
      before['amount'],
      after['amount'],
    );

    _addChangedField(
      beforeData,
      afterData,
      'transactionID',
      before['transactionID'],
      after['transactionID'],
    );

    _addChangedField(
      beforeData,
      afterData,
      'received_at',
      before['received_at'],
      after['received_at'],
    );

    _addChangedField(
      beforeData,
      afterData,
      'remark',
      before['remark'],
      after['remark'],
    );

    final customerId =
        _parseInt(after['customer']);

    if (customerId != null) {
      final customerName =
          _selectedCustomer?['name']?.toString() ?? '';

      if (customerName.isNotEmpty) {
        beforeData['customer'] = '';
        afterData['customer'] = customerName;
      }
    }

    final orderId =
        _parseInt(after['order']);

    if (orderId != null) {
      final orderLabel =
          _orderLabel(_selectedOrder);

      if (orderLabel.isNotEmpty) {
        beforeData['order'] = '';
        afterData['order'] = orderLabel;
      }
    }

    if (mode == 'toAdvance') {
      beforeData['conversion'] = '';
      afterData['conversion'] = 'Advance Receipt';
    }

    if (mode == 'toOrder') {
      beforeData['conversion'] = '';
      afterData['conversion'] = 'Order Receipt';
    }

    return {
      'before_data': beforeData,
      'after_data': afterData,
    };
  }

  void _addChangedField(
    Map<String, dynamic> beforeData,
    Map<String, dynamic> afterData,
    String key,
    dynamic beforeValue,
    dynamic afterValue,
  ) {
    final before =
        _normalize(beforeValue);

    final after =
        _normalize(afterValue);

    if (before != after) {
      beforeData[key] = before;
      afterData[key] = after;
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _normalize(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  String _bankNameById(int? id) {
    if (id == null) {
      return '';
    }

    for (final bank in _banks) {
      if (_parseInt(bank['id']) == id) {
        return bank['name']?.toString() ?? '';
      }
    }

    return '';
  }

  String _customerLabel(
    Map<String, dynamic>? customer,
  ) {
    if (customer == null) {
      return '';
    }

    final name =
        customer['name']?.toString() ?? '';

    final phone =
        customer['phone']?.toString() ?? '';

    if (phone.isEmpty) {
      return name;
    }

    return '$name - $phone';
  }

  String _orderLabel(
    Map<String, dynamic>? order,
  ) {
    if (order == null) {
      return '';
    }

    final invoice =
        order['invoice']?.toString() ?? '';

    String customerName = '';

    final customer = order['customer'];

    if (customer is Map) {
      customerName =
          customer['name']?.toString() ?? '';
    }

    final amount =
        order['total_amount']?.toString() ?? '';

    final parts = <String>[];

    if (invoice.isNotEmpty) {
      parts.add(invoice);
    }

    if (customerName.isNotEmpty) {
      parts.add(customerName);
    }

    if (amount.isNotEmpty) {
      parts.add('₹$amount');
    }

    return parts.join(' - ');
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredReceipts {
    final search =
        _searchController.text.trim().toLowerCase();

    return _receipts.where((item) {
      final paymentReceipt =
          _normalize(item['payment_receipt'])
              .toLowerCase();

      final transactionId =
          _normalize(item['transactionID'])
              .toLowerCase();

      final bankName =
          _normalize(item['bank_name'])
              .toLowerCase();

      final remark =
          _normalize(item['remark'])
              .toLowerCase();

      final createdBy =
          _normalize(item['created_by_name'])
              .toLowerCase();

      final amount =
          _normalize(item['amount'])
              .toLowerCase();

      bool matchesSearch = true;

      if (search.isNotEmpty) {
        matchesSearch =
            paymentReceipt.contains(search) ||
                transactionId.contains(search) ||
                bankName.contains(search) ||
                remark.contains(search) ||
                createdBy.contains(search) ||
                amount.contains(search);

        final numericAmount =
            double.tryParse(
          item['amount']?.toString() ?? '',
        );

        if (numericAmount != null) {
          matchesSearch =
              matchesSearch ||
                  numericAmount
                      .toStringAsFixed(2)
                      .contains(search);
        }
      }

      bool matchesDate = true;

      final receivedAt =
          _tryParseDate(item['received_at']);

      if (_startDate != null) {
        if (receivedAt == null) {
          matchesDate = false;
        } else {
          final receiptDay = DateTime(
            receivedAt.year,
            receivedAt.month,
            receivedAt.day,
          );

          final startDay = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );

          if (receiptDay.isBefore(startDay)) {
            matchesDate = false;
          }
        }
      }

      if (_endDate != null) {
        if (receivedAt == null) {
          matchesDate = false;
        } else {
          final receiptDay = DateTime(
            receivedAt.year,
            receivedAt.month,
            receivedAt.day,
          );

          final endDay = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
          );

          if (receiptDay.isAfter(endDay)) {
            matchesDate = false;
          }
        }
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    final stringValue =
        value.toString().trim();

    if (stringValue.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(stringValue);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _currentReceipts {
    final filtered = _filteredReceipts;

    final start =
        (_currentPage - 1) * _perPage;

    if (start >= filtered.length) {
      return [];
    }

    final end =
        (start + _perPage) > filtered.length
            ? filtered.length
            : start + _perPage;

    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final count = _filteredReceipts.length;

    if (count == 0) {
      return 1;
    }

    return (count / _perPage).ceil();
  }

  void _fixCurrentPage() {
    final totalPages = _totalPages;

    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }

    if (_currentPage < 1) {
      _currentPage = 1;
    }
  }

  // ---------------------------------------------------------------------------
  // DATE FILTER
  // ---------------------------------------------------------------------------

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _startDate = picked;
      _currentPage = 1;
    });
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _endDate = picked;
      _currentPage = 1;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
    });
  }

  // ---------------------------------------------------------------------------
  // RECEIVED DATE
  // ---------------------------------------------------------------------------

  Future<void> _selectReceivedDate(
    StateSetter dialogSetState,
  ) async {
    DateTime initialDate = DateTime.now();

    final existing =
        _tryParseDate(_receivedAtController.text);

    if (existing != null) {
      initialDate = existing;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked == null) {
      return;
    }

    dialogSetState(() {
      _receivedAtController.text =
          DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER SEARCH DIALOG
  // ---------------------------------------------------------------------------

  Future<void> _selectCustomer(
    StateSetter parentSetState,
  ) async {
    final result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _SearchSelectionDialog(
          title: 'Select Customer',
          hintText: 'Search Customer (Name / Phone)',
          searchFunction: _searchCustomers,
          labelBuilder: _customerLabel,
        );
      },
    );

    if (result == null) {
      return;
    }

    parentSetState(() {
      _selectedCustomer = result;
      _selectedOrder = null;
    });
  }

  // ---------------------------------------------------------------------------
  // ORDER SEARCH DIALOG
  // ---------------------------------------------------------------------------

  Future<void> _selectOrder(
    StateSetter parentSetState,
  ) async {
    final result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _SearchSelectionDialog(
          title: 'Select Order',
          hintText:
              'Search Order (Invoice / Customer)',
          searchFunction: _searchOrders,
          labelBuilder: _orderLabel,
        );
      },
    );

    if (result == null) {
      return;
    }

    parentSetState(() {
      _selectedOrder = result;
      _selectedCustomer = null;
    });
  }

  // ---------------------------------------------------------------------------
  // RESET FORM
  // ---------------------------------------------------------------------------

  void _resetReceiptForm() {
    _selectedReceipt = null;
    _originalReceipt = null;

    _selectedBankId = null;
    _selectedCustomer = null;
    _selectedOrder = null;

    _receiptController.clear();
    _amountController.clear();
    _transactionController.clear();
    _remarkController.clear();
    _receivedAtController.clear();
    _createdByController.clear();
  }

  // ---------------------------------------------------------------------------
  // PERMISSION
  // ---------------------------------------------------------------------------

  bool get _canViewReceipt {
    return const [
      'ADMIN',
      'CEO',
      'COO',
      'HR',
    ].contains(_role);
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _navigateBack() async {
    final dep = await _getDepartment();

    if (!mounted) return;

    if (dep == 'BDO') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => bdo_dashbord(),
        ),
      );
    } else if (dep == 'HR') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HrDashboard(),
        ),
      );
    } else if (dep == 'BDM') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => bdm_dashbord(),
        ),
      );
    } else if (dep == 'warehouse') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WarehouseDashboard(),
        ),
      );
    } else if (dep == 'Warehouse Admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WarehouseAdmin(),
        ),
      );
    } else if (dep == 'CEO' || dep == 'COO') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ceo_dashboard(),
        ),
      );
    } else if (dep == 'CSO') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => cso_dashboard(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => dashboard(),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGES
  // ---------------------------------------------------------------------------

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(message),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  void _showWarning(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.orange,
        content: Text(message),
      ),
    );
  }

  void _showApiError(
    http.Response response, {
    required String fallback,
  }) {
    String message = fallback;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        if (decoded['message'] != null) {
          message = decoded['message'].toString();
        } else if (decoded['detail'] != null) {
          message = decoded['detail'].toString();
        } else if (decoded['errors'] != null) {
          message = decoded['errors'].toString();
        }
      }
    } catch (_) {}

    _showError(message);
  }

  // ---------------------------------------------------------------------------
  // LOADING DIALOG
  // ---------------------------------------------------------------------------

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RECEIPT EDIT DIALOG
  // ---------------------------------------------------------------------------

  Future<void> _showReceiptDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter dialogSetState,
          ) {
            return Dialog(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 20,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 820,
                  maxHeight: 820,
                ),
                child: Column(
                  children: [
                    _buildDialogHeader(
                      dialogContext,
                    ),

                    Expanded(
                      child: Container(
                        color: const Color(0xFFF7F9FD),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _buildReadOnlyField(
                              label: 'Receipt',
                              controller:
                                  _receiptController,
                            ),

                            const SizedBox(height: 14),

                            _buildBankDropdown(
                              dialogSetState,
                            ),

                            const SizedBox(height: 14),

                            _buildTextField(
                              label: 'Amount',
                              controller:
                                  _amountController,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                decimal: true,
                              ),
                            ),

                            const SizedBox(height: 14),

                            _buildTextField(
                              label: 'Transaction ID',
                              controller:
                                  _transactionController,
                            ),

                            const SizedBox(height: 14),

                            _buildReceivedDateField(
                              dialogSetState,
                            ),

                            const SizedBox(height: 14),

                            _buildTextField(
                              label: 'Remark',
                              controller:
                                  _remarkController,
                            ),

                            const SizedBox(height: 14),

                            _buildReadOnlyField(
                              label: 'Created By',
                              controller:
                                  _createdByController,
                            ),

                            const SizedBox(height: 20),

                            _buildCustomerSelector(
                              dialogSetState,
                            ),

                            const SizedBox(height: 14),

                            _buildOrderSelector(
                              dialogSetState,
                            ),

                            const SizedBox(height: 12),

                            if (_selectedCustomer != null)
                              _buildConversionInfo(
                                'Updating will convert this '
                                'Other Receipt into an '
                                'Advance Receipt.',
                              ),

                            if (_selectedOrder != null)
                              _buildConversionInfo(
                                'Updating will convert this '
                                'Other Receipt into an '
                                'Order Receipt.',
                              ),
                          ],
                        ),
                      ),
                    ),
                    ),

                    _buildDialogActions(
                      dialogContext,
                      dialogSetState,
                    ),
                  ],
                ),
              ),
            ),
            );
          },
        );
      },
    );

    _resetReceiptForm();
  }

  Widget _buildDialogHeader(
    BuildContext dialogContext,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor,
            const Color(0xFF1565C0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Review and update receipt information',
                  style: TextStyle(
                    color: Color(0xFFE3F2FD),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: _isSaving
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                    },
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDropdown(
    StateSetter dialogSetState,
  ) {
    return _buildProfessionalFieldShell(
      label: 'Bank',
      icon: Icons.account_balance_outlined,
      child: DropdownButtonFormField<int>(
        value: _banks.any(
          (item) => _parseInt(item['id']) == _selectedBankId,
        )
            ? _selectedBankId
            : null,
        isExpanded: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _mutedTextColor,
        ),
        decoration: _inputDecoration('Select Bank'),
        items: _banks.map((bank) {
          return DropdownMenuItem<int>(
            value: _parseInt(bank['id']),
            child: Text(
              bank['name']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF263946),
              ),
            ),
          );
        }).toList(),
        onChanged: _isSaving
            ? null
            : (value) {
                dialogSetState(() {
                  _selectedBankId = value;
                });
              },
      ),
    );
  }

  Widget _buildCustomerSelector(
    StateSetter dialogSetState,
  ) {
    final disabled = _selectedOrder != null;

    return _buildProfessionalFieldShell(
      label: 'Customer',
      icon: Icons.person_search_outlined,
      optionalText: 'Optional · converts to Advance Receipt',
      child: InkWell(
        onTap: disabled || _isSaving
            ? null
            : () {
                _selectCustomer(dialogSetState);
              },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: disabled
                ? const Color(0xFFF1F4F6)
                : const Color(0xFFFFFFFF),
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedCustomer != null
                      ? _customerLabel(_selectedCustomer)
                      : disabled
                          ? 'Clear selected order to choose a customer'
                          : 'Search by customer name or phone',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: _selectedCustomer != null
                        ? const Color(0xFF263946)
                        : _mutedTextColor,
                    fontWeight: _selectedCustomer != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedCustomer != null)
                InkWell(
                  onTap: _isSaving
                      ? null
                      : () {
                          dialogSetState(() {
                            _selectedCustomer = null;
                          });
                        },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _primaryColor,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: disabled
                      ? Colors.grey.shade400
                      : _primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSelector(
    StateSetter dialogSetState,
  ) {
    final disabled = _selectedCustomer != null;

    return _buildProfessionalFieldShell(
      label: 'Order',
      icon: Icons.shopping_bag_outlined,
      optionalText: 'Optional · converts to Order Receipt',
      child: InkWell(
        onTap: disabled || _isSaving
            ? null
            : () {
                _selectOrder(dialogSetState);
              },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: disabled
                ? const Color(0xFFF1F4F6)
                : const Color(0xFFFFFFFF),
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedOrder != null
                      ? _orderLabel(_selectedOrder)
                      : disabled
                          ? 'Clear selected customer to choose an order'
                          : 'Search by invoice or customer',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: _selectedOrder != null
                        ? const Color(0xFF263946)
                        : _mutedTextColor,
                    fontWeight: _selectedOrder != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedOrder != null)
                InkWell(
                  onTap: _isSaving
                      ? null
                      : () {
                          dialogSetState(() {
                            _selectedOrder = null;
                          });
                        },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _primaryColor,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: disabled
                      ? Colors.grey.shade400
                      : _primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversionInfo(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        border: Border.all(color: const Color(0xFFF2D58A)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDBF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF8B6513),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Color(0xFF6D5319),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedDateField(
    StateSetter dialogSetState,
  ) {
    return _buildProfessionalFieldShell(
      label: 'Received At',
      icon: Icons.calendar_today_outlined,
      child: TextFormField(
        controller: _receivedAtController,
        readOnly: true,
        onTap: _isSaving
            ? null
            : () {
                _selectReceivedDate(dialogSetState);
              },
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF263946),
        ),
        decoration: _inputDecoration('Select Received Date').copyWith(
          suffixIcon: Icon(
            Icons.calendar_month_rounded,
            color: _primaryColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildDialogActions(
    BuildContext dialogContext,
    StateSetter dialogSetState,
  ) {
    final actionLabel = _selectedCustomer != null
        ? 'Create Advance Receipt'
        : _selectedOrder != null
            ? 'Create Order Receipt'
            : 'Update Receipt';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _borderColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;

            final cancelButton = OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF52636F),
                side: BorderSide(color: _borderColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );

            final updateButton = ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      dialogSetState(() {});
                      await _handleUpdate();
                      if (mounted) {
                        dialogSetState(() {});
                      }
                    },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryColor.withOpacity(0.55),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            actionLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            );

            if (compact) {
              return Row(
                children: [
                  Expanded(child: cancelButton),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: updateButton),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                cancelButton,
                const SizedBox(width: 10),
                updateButton,
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMMON FORM WIDGETS
  // ---------------------------------------------------------------------------

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF344A58),
      ),
    );
  }

  Widget _buildProfessionalFieldShell({
    required String label,
    required IconData icon,
    required Widget child,
    String? optionalText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 15,
                color: _primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _fieldLabel(label)),
            if (optionalText != null)
              Flexible(
                child: Text(
                  optionalText,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: _mutedTextColor,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _accentColor,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    IconData icon = Icons.edit_note_rounded;
    if (label == 'Amount') icon = Icons.currency_rupee_rounded;
    if (label == 'Transaction ID') icon = Icons.tag_rounded;
    if (label == 'Remark') icon = Icons.notes_rounded;

    return _buildProfessionalFieldShell(
      label: label,
      icon: icon,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: !_isSaving,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF263946),
        ),
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required TextEditingController controller,
  }) {
    final isReceipt = label == 'Receipt';

    return _buildProfessionalFieldShell(
      label: label,
      icon: isReceipt
          ? Icons.receipt_outlined
          : Icons.person_outline_rounded,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        enabled: false,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF5F707B).withOpacity(0.85),
        ),
        decoration: _inputDecoration(label).copyWith(
          fillColor: const Color(0xFFF0F4F6),
          suffixIcon: Icon(
            Icons.lock_outline_rounded,
            size: 17,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER UI
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    return Column(
      children: [
        TextField(
          controller:
              _searchController,
          onChanged: (_) {
            setState(() {
              _currentPage = 1;
            });
          },
          decoration:
              _inputDecoration(
            'Search by Receipt, Amount, Transaction ID, '
            'Bank, Remark, Created By',
          ).copyWith(
            prefixIcon:
                const Icon(Icons.search),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController
                              .clear();

                          setState(() {
                            _currentPage = 1;
                          });
                        },
                        icon:
                            const Icon(
                          Icons.close,
                        ),
                      )
                    : null,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildDateFilter(
                title: 'Start Date',
                date: _startDate,
                onTap:
                    _selectStartDate,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildDateFilter(
                title: 'End Date',
                date: _endDate,
                onTap:
                    _selectEndDate,
              ),
            ),
          ],
        ),

        if (_startDate != null ||
            _endDate != null) ...[
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _clearDateFilter,
              icon: const Icon(
                Icons.filter_alt_off,
                size: 18,
              ),
              label: const Text(
                'Clear Date Filter',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateFilter({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade400,
          ),
          borderRadius:
              BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month,
              size: 19,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                date == null
                    ? title
                    : DateFormat(
                        'dd-MM-yyyy',
                      ).format(date),
                style: TextStyle(
                  fontSize: 12,
                  color: date == null
                      ? Colors.grey.shade600
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECEIPT LIST
  // ---------------------------------------------------------------------------

  Widget _buildReceiptList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(50),
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    final receipts =
        _currentReceipts;

    if (receipts.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          vertical: 60,
          horizontal: 20,
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 55,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No receipts found',
              style: TextStyle(
                fontSize: 15,
                color:
                    Colors.grey.shade700,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final firstIndex =
        (_currentPage - 1) *
            _perPage;

    return Column(
      children: [
        ...List.generate(
          receipts.length,
          (index) {
            final item =
                receipts[index];

            return _buildReceiptCard(
              item,
              firstIndex +
                  index +
                  1,
            );
          },
        ),

        const SizedBox(height: 18),

        _buildPagination(),
      ],
    );
  }

  Widget _buildReceiptCard(
    Map<String, dynamic> item,
    int serialNumber,
  ) {
    final receipt = _normalize(item['payment_receipt']);
    final amount = _normalize(item['amount']);
    final transactionId = _normalize(item['transactionID']);
    final receivedAt = _normalize(item['received_at']);
    final remark = _normalize(item['remark']);
    final bank = _normalize(item['bank_name']);
    final createdBy = _normalize(item['created_by_name']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
              decoration: BoxDecoration(
                color: _primarySoft.withOpacity(0.55),
                border: Border(
                  bottom: BorderSide(color: _borderColor),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      serialNumber.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.isEmpty ? 'Other Receipt' : receipt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172B3A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          receivedAt.isEmpty ? 'Date not available' : receivedAt,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _mutedTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${amount.isEmpty ? '0.00' : amount}',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_canViewReceipt) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            final id = _parseInt(item['id']);
                            if (id != null) {
                              _openReceipt(id);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _primaryColor.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 14,
                                  color: _primaryColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'View',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildCompactInfo(
                          icon: Icons.account_balance_outlined,
                          label: 'Bank',
                          value: bank,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactInfo(
                          icon: Icons.tag_outlined,
                          label: 'Transaction ID',
                          value: transactionId,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildCompactInfo(
                          icon: Icons.person_outline,
                          label: 'Created By',
                          value: createdBy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactInfo(
                          icon: Icons.notes_outlined,
                          label: 'Remark',
                          value: remark,
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
    );
  }

  Widget _buildCompactInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 15,
            color: _primaryColor,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF263946),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptInfoRow(
    String label,
    String value, {
    bool showBottomPadding = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            showBottomPadding ? 8 : 0,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ),

          const Text(':  '),

          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGINATION
  // ---------------------------------------------------------------------------

  Widget _buildPagination() {
    final filteredCount =
        _filteredReceipts.length;

    if (filteredCount == 0) {
      return const SizedBox.shrink();
    }

    final firstItem =
        ((_currentPage - 1) *
                _perPage) +
            1;

    final calculatedLast =
        _currentPage * _perPage;

    final lastItem =
        calculatedLast >
                filteredCount
            ? filteredCount
            : calculatedLast;

    return Column(
      children: [
        Text(
          'Showing $firstItem - $lastItem of $filteredCount',
          style: TextStyle(
            fontSize: 12,
            color:
                Colors.grey.shade600,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed:
                  _currentPage > 1
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                        }
                      : null,
              icon: const Icon(
                Icons.chevron_left,
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius:
                    BorderRadius.circular(
                  8,
                ),
              ),
              child: Text(
                '$_currentPage / $_totalPages',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),

            IconButton(
              onPressed:
                  _currentPage <
                          _totalPages
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
              icon: const Icon(
                Icons.chevron_right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryStrip() {
    final visibleCount = _filteredReceipts.length;
    final totalAmount = _filteredReceipts.fold<double>(
      0,
      (sum, item) =>
          sum + (double.tryParse(item['amount']?.toString() ?? '') ?? 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;

        final cards = [
          _buildSummaryCard(
            icon: Icons.receipt_long_outlined,
            label: 'Visible Receipts',
            value: '$visibleCount',
          ),
          _buildSummaryCard(
            icon: Icons.payments_outlined,
            label: 'Visible Amount',
            value: '₹${NumberFormat('#,##0.00').format(totalAmount)}',
          ),
          _buildSummaryCard(
            icon: Icons.calendar_month_outlined,
            label: 'Date Filter',
            value: _startDate == null && _endDate == null
                ? 'All Dates'
                : 'Applied',
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: _primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF172B3A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: Colors.black.withOpacity(0.08),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF263946),
            ),
            onPressed: _navigateBack,
          ),
          titleSpacing: 4,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Other Receipts',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF172B3A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage and reconcile unallocated receipts',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF71818D),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : _fetchReceipts,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _primarySoft,
                child: ClipOval(
                  child: Image.asset(
                    'lib/assets/profile.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return Icon(
                        Icons.person_outline_rounded,
                        color: _primaryColor,
                        size: 21,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: _primaryColor,
          onRefresh: _fetchReceipts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor,
                            const Color(0xFF1565C0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.16),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Other Receipts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Review receipts, update details, or convert them to customer and order receipts.',
                                  style: TextStyle(
                                    color: Color(0xFFE3F2FD),
                                    fontSize: 11.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSummaryStrip(),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.025),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
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
                                  color: _primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: _primaryColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Search & Filters',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF172B3A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Find receipts by details or received date',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF71818D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildFilters(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Receipt List',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172B3A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primarySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredReceipts.length} receipts',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: _primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    _buildReceiptList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// =============================================================================
// SEARCHABLE API SELECTION DIALOG
// =============================================================================

class _SearchSelectionDialog extends StatefulWidget {
  final String title;
  final String hintText;

  final Future<List<Map<String, dynamic>>> Function(
    String search,
  ) searchFunction;

  final String Function(
    Map<String, dynamic>? item,
  ) labelBuilder;

  const _SearchSelectionDialog({
    required this.title,
    required this.hintText,
    required this.searchFunction,
    required this.labelBuilder,
  });

  @override
  State<_SearchSelectionDialog> createState() =>
      _SearchSelectionDialogState();
}

class _SearchSelectionDialogState
    extends State<_SearchSelectionDialog> {
  final TextEditingController _controller =
      TextEditingController();

  Timer? _debounce;

  bool _loading = false;

  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();

    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () {
        _performSearch(value);
      },
    );
  }

  Future<void> _performSearch(
    String search,
  ) async {
    if (search.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _loading = false;
        });
      }

      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final results =
          await widget.searchFunction(
        search,
      );

      if (!mounted) return;

      setState(() {
        _results = results;
      });
    } catch (e) {
      debugPrint(
        'Search selection error: $e',
      );

      if (!mounted) return;

      setState(() {
        _results = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 40,
      ),

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 600,
          maxHeight: 600,
        ),

        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration:
                  const BoxDecoration(
                color: Color(0xFF024160),
                borderRadius:
                    BorderRadius.vertical(
                  top:
                      Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged:
                    _onSearchChanged,
                decoration:
                    InputDecoration(
                  hintText:
                      widget.hintText,
                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
              ),
            ),

            if (_loading)
              const Padding(
                padding:
                    EdgeInsets.all(20),
                child:
                    CircularProgressIndicator(),
              )
            else if (_controller
                    .text
                    .trim()
                    .isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Start typing to search',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else if (_results.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child:
                    ListView.separated(
                  padding:
                      const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 12,
                  ),

                  itemCount:
                      _results.length,

                  separatorBuilder:
                      (_, __) =>
                          const Divider(
                    height: 1,
                  ),

                  itemBuilder:
                      (context, index) {
                    final item =
                        _results[index];

                    return ListTile(
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),

                      leading:
                          CircleAvatar(
                        backgroundColor:
                            const Color
                                    .fromARGB(
                                  255,
                                  2,
                                  65,
                                  96,
                                )
                                .withOpacity(
                          0.1,
                        ),
                        child: const Icon(
                          Icons
                              .arrow_forward,
                          color: Color(0xFF024160),
                          size: 18,
                        ),
                      ),

                      title: Text(
                        widget
                            .labelBuilder(
                          item,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 13,
                        ),
                      ),

                      onTap: () {
                        Navigator.pop(
                          context,
                          item,
                        );
                      },
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