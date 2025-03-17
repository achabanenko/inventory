import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/device_id_service.dart';
import '../services/good_receipt_service.dart';

class GoodsReceiptScanItemPage extends StatefulWidget {
  final String goodReceiptId;
  final Function(Map<String, dynamic>) onItemAdded;

  const GoodsReceiptScanItemPage({
    super.key, 
    required this.goodReceiptId,
    required this.onItemAdded
  });

  @override
  State<GoodsReceiptScanItemPage> createState() =>
      _GoodsReceiptScanItemPageState();
}

class _GoodsReceiptScanItemPageState extends State<GoodsReceiptScanItemPage> {
  final GoodReceiptService _goodReceiptService = GoodReceiptService();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _priceController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController _uomController = TextEditingController(
    text: 'EA',
  );
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set focus to the barcode field when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
    
    // Add listener to select all text when quantity field receives focus
    _quantityFocusNode.addListener(() {
      if (_quantityFocusNode.hasFocus) {
        // Select all text when the field receives focus
        _quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _quantityController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _uomController.dispose();
    _barcodeFocusNode.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  void _processBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    // Parse the quantity, default to 1 if invalid
    double quantity = 1;
    try {
      quantity = double.parse(_quantityController.text);
      if (quantity <= 0) quantity = 1; // Ensure quantity is positive
    } catch (e) {
      // If parsing fails, use default quantity of 1
      _quantityController.text = '1';
    }

    // Parse the price, default to 0 if invalid
    double price = 0;
    try {
      price = double.parse(_priceController.text);
      if (price < 0) price = 0; // Ensure price is not negative
    } catch (e) {
      // If parsing fails, use default price of 0
      _priceController.text = '0.00';
    }

    // Get the device ID
    final deviceIdService = DeviceIdService();
    final deviceId = await deviceIdService.getDeviceId();

    setState(() {
      _isLoading = true;
    });

    try {
      // Use local database service to add the item to the good receipt
      final addedItem = await _goodReceiptService.createGoodReceiptItem(
        goodReceiptId: widget.goodReceiptId,
        itemCode: barcode,
        name: 'Item #$barcode', // This would be replaced with actual product lookup
        qty: quantity,
        price: price,
        uom: _uomController.text.trim(),
        deviceId: deviceId,
      );

      debugPrint('Added item with device ID: $deviceId');

      // Call the callback to update the UI
      widget.onItemAdded(addedItem);

      // Clear the input field
      _barcodeController.clear();

      // Show a snackbar to confirm the item was added
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item $barcode added to receipt (Qty: ${_quantityController.text})',
          ),
          duration: const Duration(seconds: 1),
        ),
      );

      // Reset quantity to 1 for next scan
      _quantityController.text = '1';

      // Keep focus on the barcode field for the next scan
      _barcodeFocusNode.requestFocus();
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding item: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Item'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 32, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Scan or enter an item barcode/SKU code to add it to the goods receipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Barcode input field
            TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              decoration: InputDecoration(
                labelText: 'Barcode / Item Code / SKU',
                hintText: 'Scan or type barcode here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _barcodeController.clear();
                    _barcodeFocusNode.requestFocus();
                  },
                ),
              ),
              style: const TextStyle(fontSize: 20),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _quantityFocusNode.requestFocus(),
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')), // No spaces
              ],
            ),
            const SizedBox(height: 16),

            // Quantity input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    focusNode: _quantityFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.format_list_numbered),
                    ),
                    style: const TextStyle(fontSize: 20),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _processBarcode(_barcodeController.text),
                    onTap: () {
                      // Select all text when the field receives focus
                      _quantityController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _quantityController.text.length,
                      );
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Only digits
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Quick quantity buttons
                Wrap(
                  spacing: 8,
                  children: [
                    _buildQuantityButton('1'),
                    _buildQuantityButton('5'),
                    _buildQuantityButton('10'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price input field
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                hintText: 'Enter price',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              style: const TextStyle(fontSize: 20),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // Allow decimal numbers
              ],
            ),
            const SizedBox(height: 16),

            // UOM input field
            TextField(
              controller: _uomController,
              decoration: InputDecoration(
                labelText: 'Unit of Measure',
                hintText: 'Enter UOM (e.g., EA, KG, BOX)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.straighten),
              ),
              style: const TextStyle(fontSize: 20),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _processBarcode(_barcodeController.text),
            ),
            const SizedBox(height: 16),

            // Large Add Item button
            Container(
              height: 70,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                onPressed: () => _processBarcode(_barcodeController.text),
                icon: const Icon(Icons.add_circle, size: 32),
                label: const Text(
                  'ADD ITEM',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

  // Helper method to build quick quantity selection buttons
  Widget _buildQuantityButton(String value) {
    return InkWell(
      onTap: () {
        setState(() {
          _quantityController.text = value;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
