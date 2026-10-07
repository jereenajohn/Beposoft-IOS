import 'dart:convert';
import 'dart:async';

import 'package:beposoft/Sales%20Directors/SD_dashboard.dart';
import 'package:beposoft/loginpage.dart';
import 'package:beposoft/pages/ACCOUNTS/dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/dorwer.dart';
import 'package:beposoft/pages/ADMIN/ceo_dashboard.dart';
import 'package:beposoft/pages/BDM/bdm_dshboard.dart';
import 'package:beposoft/pages/BDO/bdo_dashboard.dart';
import 'package:beposoft/pages/HR/hr_dashboard.dart';
import 'package:beposoft/pages/MARKETING/marketing_dashboard.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_admin.dart';
import 'package:beposoft/pages/WAREHOUSE/warehouse_dashboard.dart';
import 'package:beposoft/pages/ACCOUNTS/performa_cart.dart';
import 'package:beposoft/pages/ACCOUNTS/csodashboard.dart';
import 'package:beposoft/pages/api.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CreatePerformaProduct_List extends StatefulWidget {
  final int? proformaOrderId;

  const CreatePerformaProduct_List({
    super.key,
    this.proformaOrderId,
  });

  @override
  State<CreatePerformaProduct_List> createState() =>
      _CreatePerformaProduct_ListState();
}

class _CreatePerformaProduct_ListState
    extends State<CreatePerformaProduct_List> {
  drower d = drower();

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  List<Map<String, dynamic>> Warehouses = [];

  String? dep;
  var warehouse;

  String? selectedCategoryId;

  List<String> categories = ["All Categories"];
  String selectedCategory = "All Categories";

  int currentPage = 1;
  int totalProductCount = 0;

  String? nextPageUrl;
  String? previousPageUrl;

  bool isProductLoading = false;

  String searchQuery = "";

  Timer? _searchDebounce;

  TextEditingController searchController = TextEditingController();

  bool isDefaultWarehouse = true;
  String? defaultWarehouse;

  @override
  void initState() {
    super.initState();

    initdata();
    getwarehouse();
  }

  Future<void> _navigateBack() async {
    if (widget.proformaOrderId != null) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    final dep = await getdepFromPrefs();

    if (!mounted) return;

    if (dep == "BDO") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => bdo_dashbord(),
        ),
      );
    } else if (dep == "HR") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HrDashboard(),
        ),
      );
    } else if (dep == "Marketing") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => marketing_dashboard(),
        ),
      );
    } else if (dep == "SD") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SdDashboard(),
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
    } else if (dep == "Warehouse Admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WarehouseAdmin(),
        ),
      );
    } else if (dep == "Marketing") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => marketing_dashboard(),
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

  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getString('token');
  }

  Future<String?> getdepFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getString('department');
  }

  Future<String?> getwarehouseFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    int? warehouseId = prefs.getInt('warehouse');

    return warehouseId?.toString();
  }

  bool get canViewStock {
    final department = dep?.trim().toUpperCase();

    return department == "CEO" || department == "COO" || department == "ADMIN";
  }

  // ============================================================
  // LOCKED INVOICE PERMISSION
  // Only CEO, COO and Accounts / Accounting can see locked invoices
  // ============================================================

  bool get canViewLockedInvoices {
    final String department = dep?.trim().toUpperCase() ?? '';

    return department == "CEO" ||
        department == "COO" ||
        department == "ADMIN" ||
        department == "ACCOUNTS / ACCOUNTING";
  }

  Future<void> initdata() async {
    dep = await getdepFromPrefs();

    defaultWarehouse = await getwarehouseFromPrefs();

    warehouse = defaultWarehouse;

    await fetchProductListid(warehouse);

    if (!mounted) return;

    setState(() {
      filteredProducts = products;
      isDefaultWarehouse = true;
    });
  }

  Future<void> getwarehouse() async {
    final token = await getTokenFromPrefs();

    try {
      final response = await http.get(
        Uri.parse(
          '$api/api/warehouse/add/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(
          response.body,
        );

        List<Map<String, dynamic>> warehouselist = [];

        for (var w in parsed) {
          warehouselist.add({
            'id': w['id'],
            'name': w['name'],
            'location': w['location'],
          });
        }

        if (!mounted) return;

        setState(() {
          Warehouses = warehouselist;
        });
      }
    } catch (e) {}
  }

  Future<void> fetchProductListid(
    var warehouse, {
    int page = 1,
    String search = "",
  }) async {
    final token = await getTokenFromPrefs();

    dep = await getdepFromPrefs();

    if (mounted) {
      setState(() {
        isProductLoading = true;
      });
    }

    try {
      final uri = Uri.parse(
        "$api/api/warehouse/products/$warehouse/get/",
      ).replace(
        queryParameters: {
          'page': page.toString(),
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      debugPrint(
        "PRODUCT LIST REQUEST: $uri",
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        "PRODUCT LIST STATUS: ${response.statusCode}",
      );

      debugPrint(
        "PRODUCT LIST RESPONSE: ${response.body}",
      );

      if (response.statusCode == 200) {
        final dynamic parsed = jsonDecode(
          response.body,
        );

        // ============================================================
        // PAGINATION
        // ============================================================

        totalProductCount = parsed['count'] ?? 0;

        nextPageUrl = parsed['next'];

        previousPageUrl = parsed['previous'];

        currentPage = page;

        // ============================================================
        // API PRODUCT DATA
        // ============================================================

        final List<dynamic> productsData = parsed['results']?['data'] is List
            ? List<dynamic>.from(
                parsed['results']['data'],
              )
            : <dynamic>[];

        final List<Map<String, dynamic>> productList = [];

        final Set<String> categorySet = <String>{};

        // ============================================================
        // PROCESS PRODUCTS
        //
        // IMPORTANT:
        //
        // Variant parent approval_status is NOT used to decide
        // whether its children should be shown.
        //
        // Example:
        //
        // Parent:
        // approval_status = Disapproved
        //
        // Child variant:
        // approval_status = Approved
        //
        // The approved child MUST still be displayed.
        // ============================================================

        for (final dynamic rawProduct in productsData) {
          if (rawProduct is! Map) {
            continue;
          }

          final Map<String, dynamic> product = Map<String, dynamic>.from(
            rawProduct,
          );

          final String productType =
              product['type']?.toString().trim().toLowerCase() ?? '';

          final List<dynamic> rawVariants = product['variantIDs'] is List
              ? List<dynamic>.from(
                  product['variantIDs'],
                )
              : <dynamic>[];

          // ==========================================================
          // VARIANT PRODUCT / PRODUCT GROUP
          //
          // Do NOT check:
          //
          // product['approval_status']
          //
          // here.
          //
          // We only check approval_status of each actual variant.
          // ==========================================================

          if (productType == 'variant' || rawVariants.isNotEmpty) {
            for (final dynamic rawVariant in rawVariants) {
              if (rawVariant is! Map) {
                continue;
              }

              final Map<String, dynamic> variant = Map<String, dynamic>.from(
                rawVariant,
              );

              // ======================================================
              // ONLY APPROVED VARIANTS
              // ======================================================

              final String variantApproval =
                  variant['approval_status']?.toString().trim() ?? '';

              if (variantApproval != 'Approved') {
                continue;
              }

              // ======================================================
              // INHERIT CATEGORY FROM PARENT
              //
              // Some variant objects may not contain category details.
              // ======================================================

              final String variantCategoryName =
                  variant['product_category_name']?.toString().trim() ?? '';

              if (variantCategoryName.isEmpty) {
                variant['product_category_name'] =
                    product['product_category_name'];
              }

              if (variant['product_category'] == null) {
                variant['product_category'] = product['product_category'];
              }

              // ======================================================
              // INHERIT IMAGE FROM PARENT
              //
              // Only when variant image is unavailable.
              // ======================================================

              final String variantImage =
                  variant['image']?.toString().trim() ?? '';

              if (variantImage.isEmpty) {
                variant['image'] = product['image'];
              }

              // ======================================================
              // INHERIT OTHER SAFE DISPLAY DATA WHEN MISSING
              // ======================================================

              if (variant['brand'] == null) {
                variant['brand'] = product['brand'];
              }

              if (variant['family'] == null) {
                variant['family'] = product['family'];
              }

              // ======================================================
              // FLATTEN VARIANT
              //
              // This variant is now treated as an independent product
              // row in Flutter.
              //
              // Setting type = single means the existing UI shows:
              //
              // ADD
              //
              // instead of:
              //
              // VIEW
              // ======================================================

              variant['type'] = 'single';

              variant['variantIDs'] = <dynamic>[];

              // Keep information that this originally came
              // from a variant group if needed later.
              variant['_is_variant'] = true;

              variant['_parent_product_id'] = product['id'];

              variant['_parent_product_name'] = product['name'];

              // ======================================================
              // CATEGORY COLLECTION
              // ======================================================

              final String categoryName =
                  variant['product_category_name']?.toString().trim() ?? '';

              if (categoryName.isNotEmpty) {
                categorySet.add(
                  categoryName,
                );
              }

              // ======================================================
              // ADD VARIANT AS SEPARATE PRODUCT
              // ======================================================

              productList.add(
                variant,
              );

              debugPrint(
                "ADDED VARIANT: "
                "${variant['id']} - "
                "${variant['name']} - "
                "${variant['approval_status']}",
              );
            }

            // ========================================================
            // IMPORTANT
            //
            // Do NOT add the main/parent product.
            //
            // User requirement:
            // variants should appear separately.
            // ========================================================

            continue;
          }

          // ==========================================================
          // NORMAL SINGLE PRODUCT
          //
          // Unlike a variant parent, a normal single product must
          // itself be Approved.
          // ==========================================================

          final String productApproval =
              product['approval_status']?.toString().trim() ?? '';

          if (productApproval != 'Approved') {
            continue;
          }

          // ==========================================================
          // CATEGORY
          // ==========================================================

          final String categoryName =
              product['product_category_name']?.toString().trim() ?? '';

          if (categoryName.isNotEmpty) {
            categorySet.add(
              categoryName,
            );
          }

          // No nested variant UI is needed for single products.
          product['variantIDs'] = <dynamic>[];

          // ==========================================================
          // ADD SINGLE PRODUCT
          // ==========================================================

          productList.add(
            product,
          );

          debugPrint(
            "ADDED SINGLE PRODUCT: "
            "${product['id']} - "
            "${product['name']}",
          );
        }

        // ============================================================
        // DEBUG
        // ============================================================

        debugPrint(
          "API PARENT PRODUCT COUNT: "
          "${productsData.length}",
        );

        debugPrint(
          "FINAL FLATTENED PRODUCT COUNT: "
          "${productList.length}",
        );

        for (final item in productList) {
          debugPrint(
            "FINAL PRODUCT: "
            "${item['id']} | "
            "${item['name']} | "
            "${item['approval_status']}",
          );
        }

        if (!mounted) {
          return;
        }

        // ============================================================
        // UPDATE UI
        // ============================================================

        setState(() {
          products = productList;

          categories = [
            "All Categories",
            ...categorySet,
          ];

          // ==========================================================
          // CATEGORY RESET
          // ==========================================================

          if (!categories.contains(
            selectedCategory,
          )) {
            selectedCategory = "All Categories";
          }

          // ==========================================================
          // APPLY CATEGORY FILTER
          // ==========================================================

          filteredProducts = products.where(
            (
              Map<String, dynamic> product,
            ) {
              if (selectedCategory == "All Categories") {
                return true;
              }

              return product['product_category_name'] == selectedCategory;
            },
          ).toList();
        });

        debugPrint(
          "VISIBLE PRODUCT COUNT: "
          "${filteredProducts.length}",
        );
      } else {
        debugPrint(
          "PRODUCT LIST API FAILED",
        );

        debugPrint(
          "STATUS CODE: "
          "${response.statusCode}",
        );

        debugPrint(
          "RESPONSE: "
          "${response.body}",
        );

        if (!mounted) {
          return;
        }

        setState(() {
          products = <Map<String, dynamic>>[];

          filteredProducts = <Map<String, dynamic>>[];
        });
      }
    } catch (e, stackTrace) {
      debugPrint(
        "FETCH PRODUCT LIST ERROR: $e",
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          isProductLoading = false;
        });
      }
    }
  }
  // ============================================================
  // LOCKED INVOICE API
  // Same API used in normal order_products page
  // ============================================================

  Future<List<Map<String, dynamic>>> showlockedstockinvoice(
    int productId,
  ) async {
    try {
      final token = await getTokenFromPrefs();

      final response = await http.get(
        Uri.parse(
          '$api/api/product/$productId/locked-invoices/',
        ),
        headers: {
          "Content-Type": "application/json",
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(
          response.body,
        );

        return List<Map<String, dynamic>>.from(
          data['locked_invoices'] ?? [],
        );
      }
    } catch (e) {}

    return [];
  }

  void showCustomPopup(
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text(
                "OK",
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> addtocart(
    varid,
    quantity,
  ) async {
    final String? token = await getTokenFromPrefs();

    final Map<String, dynamic>? item = _findProductDataById(varid);

    final double productPrice = _readItemNumber(
      item,
      [
        'rate',
        'selling_price',
        'price',
        'actual_price',
        'mrp',
      ],
    );

    try {
      final http.Response response = await http.post(
        Uri.parse(
          '$api/api/cart/product/excel/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'product': varid,
          'quantity': quantity,
          'price': productPrice,
        }),
      );

      debugPrint(
        'ADD TO CART PRODUCT ID: $varid',
      );

      debugPrint(
        'ADD TO CART QUANTITY: $quantity',
      );

      debugPrint(
        'ADD TO CART PRICE: $productPrice',
      );

      debugPrint(
        'ADD TO CART PAYLOAD: ${jsonEncode({
              'product': varid,
              'quantity': quantity,
              'price': productPrice,
            })}',
      );

      debugPrint(
        'ADD TO CART STATUS: ${response.statusCode}',
      );

      debugPrint(
        'ADD TO CART RESPONSE: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return "success";
      }

      if (response.statusCode == 400) {
        return "failed";
      }

      return "error";
    } catch (e, stackTrace) {
      debugPrint(
        'ADD TO CART ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return "exception";
    }
  }

  void handleAddToCart(
    BuildContext context,
    varid,
    quantity,
  ) async {
    final result = await addtocart(
      varid,
      quantity,
    );

    if (!mounted) return;

    if (result == "success") {
      showCustomPopup(
        "Success",
        "Product added to cart successfully!",
      );
    } else if (result == "failed") {
      showCustomPopup(
        "Notice",
        "Product already in cart!",
      );
    } else {
      showCustomPopup(
        "Error",
        "Failed to add Product!",
      );
    }
  }

  void handleAddToCart2(
    BuildContext context,
    dynamic varid,
    dynamic quantity,
  ) async {
    final result = await addtocart2(
      varid,
      quantity,
    );

    if (!mounted) return;

    if (result == "success") {
      showCustomPopup(
        "Success",
        "Product added to cart successfully!",
      );
    } else if (result == "failed") {
      showCustomPopup(
        "Notice",
        "Product already in cart!",
      );
    } else {
      showCustomPopup(
        "Error",
        "Failed to add Product!",
      );
    }
  }

  Future<String> addtocart2(
    varid,
    quantity,
  ) async {
    final String? token = await getTokenFromPrefs();

    final Map<String, dynamic>? item = _findProductDataById(varid);

    final double productPrice = _readItemNumber(
      item,
      [
        'rate',
        'selling_price',
        'price',
        'actual_price',
        'mrp',
      ],
    );

    try {
      final http.Response response = await http.post(
        Uri.parse(
          '$api/api/cart/product/excel/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'product': varid,
          'quantity': quantity,
          'price': productPrice,
        }),
      );

      debugPrint(
        'ADD TO CART 2 PRODUCT ID: $varid',
      );

      debugPrint(
        'ADD TO CART 2 QUANTITY: $quantity',
      );

      debugPrint(
        'ADD TO CART 2 PRICE: $productPrice',
      );

      debugPrint(
        'ADD TO CART 2 PAYLOAD: ${jsonEncode({
              'product': varid,
              'quantity': quantity,
              'price': productPrice,
            })}',
      );

      debugPrint(
        'ADD TO CART 2 STATUS: ${response.statusCode}',
      );

      debugPrint(
        'ADD TO CART 2 RESPONSE: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return "success";
      } else if (response.statusCode == 400) {
        return "failed";
      } else {
        return "error";
      }
    } catch (e, stackTrace) {
      debugPrint(
        'ADD TO CART 2 ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return "exception";
    }
  }

  Map<String, dynamic>? _findProductDataById(dynamic productId) {
    final String targetId = productId?.toString() ?? '';

    for (final Map<String, dynamic> product in products) {
      if (product['id']?.toString() == targetId) {
        return product;
      }

      final List<dynamic> variants =
          product['variantIDs'] as List<dynamic>? ?? [];

      for (final dynamic variantData in variants) {
        final Map<String, dynamic> variant =
            Map<String, dynamic>.from(variantData);

        if (variant['id']?.toString() == targetId) {
          return variant;
        }
      }
    }

    return null;
  }

  double _readItemNumber(
    Map<String, dynamic>? item,
    List<String> keys,
  ) {
    if (item == null) return 0.0;

    for (final String key in keys) {
      final dynamic value = item[key];

      if (value == null) continue;

      if (value is num) {
        return value.toDouble();
      }

      final double? parsed = double.tryParse(value.toString());

      if (parsed != null) {
        return parsed;
      }
    }

    return 0.0;
  }

  Future<bool> _addProductDirectlyToProforma({
    required dynamic productId,
    required int quantity,
  }) async {
    final int? orderId = widget.proformaOrderId;

    if (orderId == null || orderId <= 0) {
      return false;
    }

    final String? token = await getTokenFromPrefs();

    if (token == null || token.trim().isEmpty) {
      if (mounted) {
        showCustomPopup(
          "Error",
          "Authentication token not found.",
        );
      }
      return false;
    }

    final Map<String, dynamic>? item = _findProductDataById(productId);

    final double rate = _readItemNumber(
      item,
      [
        'rate',
        'selling_price',
        'price',
        'actual_price',
        'mrp',
      ],
    );

    final double discount = _readItemNumber(
      item,
      ['discount'],
    );

    final double tax = _readItemNumber(
      item,
      ['tax'],
    );

    final String rawDescription = item?['description']?.toString().trim() ?? '';

    final String description =
        rawDescription.isNotEmpty ? rawDescription : 'Additional product';

    try {
      final http.Response response = await http.post(
        Uri.parse(
          '$api/api/perfoma/order/$orderId/item/add/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'product': productId,
          'quantity': quantity,
          'rate': rate,
          'discount': discount,
          'tax': tax,
          'description': description,
        }),
      );

      debugPrint(
        "ADD PRODUCT STATUS: ${response.statusCode}",
      );

      debugPrint(
        "ADD PRODUCT RESPONSE: ${response.body}",
      );

      debugPrint(
        "ADD PRODUCT PAYLOAD: ${jsonEncode({
              'product': productId,
              'quantity': quantity,
              'rate': rate,
              'discount': discount,
              'tax': tax,
              'description': description,
            })}",
      );

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      String message = "Failed to add Product!";

      try {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map) {
          message = decoded['message']?.toString() ??
              decoded['detail']?.toString() ??
              decoded['error']?.toString() ??
              message;
        }
      } catch (_) {}

      showCustomPopup(
        "Error",
        message,
      );

      return false;
    } catch (_) {
      if (mounted) {
        showCustomPopup(
          "Error",
          "Failed to add Product!",
        );
      }

      return false;
    }
  }

  // ============================================================
  // QUANTITY DIALOG
  // Added locked invoice fetching without changing cart logic
  // ============================================================

  Future<void> showSizeDialog3(
    BuildContext context,
    dynamic mainid,
    dynamic availableStockValue,
    dynamic stockValue,
    String productName,
  ) async {
    final num stock = stockValue is num
        ? stockValue
        : num.tryParse(
              stockValue?.toString() ?? "0",
            ) ??
            0;

    final num rawAvailableStock = availableStockValue is num
        ? availableStockValue
        : num.tryParse(
              availableStockValue?.toString() ?? "0",
            ) ??
            0;

    final num availableStock =
        stock <= 0 || rawAvailableStock <= 0 ? 0 : rawAvailableStock;

    // Locked invoices are fetched only for permitted departments.
    List<Map<String, dynamic>> lockedInvoices = [];

    if (canViewLockedInvoices) {
      lockedInvoices = await showlockedstockinvoice(
        int.tryParse(
              mainid.toString(),
            ) ??
            0,
      );
    }

    if (!mounted) return;

    final int? quantity = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _PerformaQuantityDialog(
          productName: productName,
          availableStock: availableStock,
          stock: stock,
          canViewStock: canViewStock,
          canAddToCart: isDefaultWarehouse,
          canViewLockedInvoices: canViewLockedInvoices,
          lockedInvoices: lockedInvoices,
        );
      },
    );

    if (quantity == null || !mounted) {
      return;
    }

    if (widget.proformaOrderId != null) {
      final bool added = await _addProductDirectlyToProforma(
        productId: mainid,
        quantity: quantity,
      );

      if (!mounted || !added) return;

      Navigator.of(this.context).pop(true);
      return;
    }

    handleAddToCart2(
      this.context,
      mainid,
      quantity,
    );
  }

  void _applyFilters() {
    searchQuery = searchController.text.trim();

    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(
      const Duration(
        milliseconds: 500,
      ),
      () {
        if (!mounted) return;

        fetchProductListid(
          warehouse,
          page: 1,
          search: searchQuery,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return WillPopScope(
      onWillPop: () async {
        await _navigateBack();

        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Product List",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
            ),
            onPressed: () async {
              if (widget.proformaOrderId != null) {
                Navigator.of(context).pop(false);
                return;
              }

              final dep = await getdepFromPrefs();

              if (dep == "BDO") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => bdo_dashbord(),
                  ),
                );
              } else if (dep == "HR") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HrDashboard(),
                  ),
                );
              } else if (dep == "SD") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SdDashboard(),
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
              } else if (dep == "Warehouse Admin") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WarehouseAdmin(),
                  ),
                );
              } else if (dep == "Marketing") {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => marketing_dashboard(),
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
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.shopping_cart,
                color: Colors.grey,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Performa_Cart(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(
                8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Select Warehouse",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            30.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                      value: warehouse,
                      items: Warehouses.map(
                        (wh) {
                          return DropdownMenuItem<String>(
                            value: wh['id'].toString(),
                            child: Text(
                              "${wh['name']} (${wh['location']})",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (selectedId) async {
                        if (selectedId != null) {
                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            warehouse = selectedId;

                            selectedCategory = "All Categories";

                            categories = ["All Categories"];

                            products = [];

                            filteredProducts = [];

                            isDefaultWarehouse = selectedId == defaultWarehouse;
                          });

                          searchQuery = searchController.text.trim();

                          await fetchProductListid(
                            selectedId,
                            page: 1,
                            search: searchQuery,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Select Category",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            30.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                      value: selectedCategory,
                      items: categories.map(
                        (cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(
                              cat,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            selectedCategory = value;
                          });

                          filteredProducts = products.where(
                            (product) {
                              if (selectedCategory == "All Categories") {
                                return true;
                              }

                              return product['product_category_name'] ==
                                  selectedCategory;
                            },
                          ).toList();

                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(
                8,
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search products...",
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      30.0,
                    ),
                  ),
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: previousPageUrl == null || isProductLoading
                        ? null
                        : () {
                            fetchProductListid(
                              warehouse,
                              page: currentPage - 1,
                              search: searchQuery,
                            );
                          },
                    child: const Text(
                      "Previous",
                    ),
                  ),
                  Text(
                    "Page $currentPage",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: nextPageUrl == null || isProductLoading
                        ? null
                        : () {
                            fetchProductListid(
                              warehouse,
                              page: currentPage + 1,
                              search: searchQuery,
                            );
                          },
                    child: const Text(
                      "Next",
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => fetchProductListid(
                  warehouse,
                  page: currentPage,
                  search: searchQuery,
                ),
                child: ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    return Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        left: 10,
                        right: 10,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 90,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(
                                255,
                                210,
                                209,
                                209,
                              ).withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: product['image'] != null &&
                                  product['image'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    '$api${product['image']}',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) =>
                                        const Icon(
                                      Icons.image_not_supported,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.image_not_supported,
                                ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                                softWrap: true,
                              ),
                              if (product['color'] != null &&
                                  product['color'].toString().isNotEmpty)
                                Text(
                                  "Color: ${product['color']}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (canViewStock)
                                Text(
                                  "Stock: ${product['stock'] ?? 0}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              Text(
                                "Available Stock: ${product['available_stock'] ?? 0}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () {
                              showSizeDialog3(
                                context,
                                product['id'],
                                product['available_stock'] ?? 0,
                                product['stock'] ?? 0,
                                product['name']?.toString() ?? '',
                              );
                            },
                            icon: const Icon(
                              Icons.add,
                              size: 14,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Add",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(60, 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
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

// ============================================================================
// PERFORMA QUANTITY DIALOG
// ============================================================================

class _PerformaQuantityDialog extends StatefulWidget {
  final String productName;

  final num availableStock;
  final num stock;

  final bool canViewStock;
  final bool canAddToCart;

  final bool canViewLockedInvoices;

  final List<Map<String, dynamic>> lockedInvoices;

  const _PerformaQuantityDialog({
    required this.productName,
    required this.availableStock,
    required this.stock,
    required this.canViewStock,
    required this.canAddToCart,
    required this.canViewLockedInvoices,
    required this.lockedInvoices,
  });

  @override
  State<_PerformaQuantityDialog> createState() =>
      _PerformaQuantityDialogState();
}

class _PerformaQuantityDialogState extends State<_PerformaQuantityDialog> {
  late final TextEditingController _quantityController;

  String? _validationMessage;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _quantityController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();

    super.dispose();
  }

  void _submit() {
    if (_isSubmitting || !widget.canAddToCart) {
      return;
    }

    final int? quantity = int.tryParse(
      _quantityController.text.trim(),
    );

    String? validationMessage;

    if (quantity == null || quantity <= 0) {
      validationMessage = "Please enter a valid quantity!";
    } else if (widget.availableStock <= 0) {
      validationMessage = "No stock available";
    } else if (quantity > widget.availableStock) {
      validationMessage = "Quantity exceeds available stock!";
    }

    if (validationMessage != null) {
      setState(() {
        _validationMessage = validationMessage;
      });

      return;
    }

    setState(() {
      _isSubmitting = true;

      _validationMessage = null;
    });

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      quantity,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 40,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),

      // =========================================================
      // FIX:
      // Do NOT add MediaQuery.viewInsets.bottom here.
      //
      // Dialog already handles the keyboard inset.
      // Adding viewInsets.bottom again was creating the huge
      // blank space and pushing the dialog content upward.
      // =========================================================

      child: Padding(
        padding: const EdgeInsets.all(
          20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add Product",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              if (widget.productName.trim().isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    widget.productName,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
              ],

              const SizedBox(
                height: 16,
              ),

              if (widget.canViewStock) ...[
                Text(
                  "Stock: ${widget.stock}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
              ],

              Text(
                "Available Stock: ${widget.availableStock}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              // ==================================================
              // LOCKED INVOICES
              // Visible ONLY for CEO, COO, Accounts / Accounting
              // ==================================================

              if (widget.canViewLockedInvoices &&
                  widget.lockedInvoices.isNotEmpty) ...[
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  "Order Invoices:",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                ...widget.lockedInvoices.map(
                  (
                    Map<String, dynamic> invoice,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 5,
                      ),
                      child: Text(
                        "🧾 ${invoice['invoice'] ?? ''} -  ${invoice['quantity_locked'] ?? 0}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(
                height: 16,
              ),

              TextField(
                controller: _quantityController,
                enabled: !_isSubmitting,

                // Keeps keyboard opening immediately.
                // Dialog will now stay compact correctly.
                autofocus: true,

                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: "Enter Quantity",
                  errorText: _validationMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      widget.canAddToCart && !_isSubmitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        widget.canAddToCart ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "ADD TO CART",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
