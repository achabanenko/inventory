class GoodReceipt {
  final String id;
  final String name;
  final int status;
  final String supplierCode;
  final String whs;
  final String? delDate;
  final String createdAt;
  final String updatedAt;
  final List<GoodReceiptItem> items;

  GoodReceipt({
    required this.id,
    required this.name,
    required this.status,
    required this.supplierCode,
    required this.whs,
    this.delDate,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory GoodReceipt.fromJson(Map<String, dynamic> json) {
    List<GoodReceiptItem> items = [];
    if (json['items'] != null) {
      items = (json['items'] as List)
          .map((item) => GoodReceiptItem.fromJson(item))
          .toList();
    }

    return GoodReceipt(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      supplierCode: json['supplierCode'],
      whs: json['whs'],
      delDate: json['delDate'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'supplierCode': supplierCode,
      'whs': whs,
      'delDate': delDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // Helper method to get status text
  String get statusText {
    switch (status) {
      case 0:
        return 'Pending';
      case 1:
        return 'Received';
      case 2:
        return 'Verified';
      default:
        return 'Unknown';
    }
  }

  // Helper method to get status color
  int get statusColor {
    switch (status) {
      case 0:
        return 0xFFFF9800; // Orange
      case 1:
        return 0xFF2196F3; // Blue
      case 2:
        return 0xFF4CAF50; // Green
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}

class GoodReceiptItem {
  final String id;
  final String goodReceiptId;
  final String itemCode;
  final String name;
  final double qty;
  final double price;
  final String uom;
  final String? deviceId;

  GoodReceiptItem({
    required this.id,
    required this.goodReceiptId,
    required this.itemCode,
    required this.name,
    required this.qty,
    required this.price,
    required this.uom,
    this.deviceId,
  });

  factory GoodReceiptItem.fromJson(Map<String, dynamic> json) {
    return GoodReceiptItem(
      id: json['id'],
      goodReceiptId: json['goodReceiptId'],
      itemCode: json['itemCode'],
      name: json['name'],
      qty: json['qty'].toDouble(),
      price: json['price'].toDouble(),
      uom: json['uom'],
      deviceId: json['deviceId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goodReceiptId': goodReceiptId,
      'itemCode': itemCode,
      'name': name,
      'qty': qty,
      'price': price,
      'uom': uom,
      'deviceId': deviceId,
    };
  }
}
