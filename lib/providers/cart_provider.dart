import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final String image;
  final bool isRental;
  int quantity;
  final String? type; // Notebook, Aksesoris, dll
  final Map<String, dynamic> rawData; // Store original data for reference

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    required this.isRental,
    this.quantity = 1,
    this.type,
    required this.rawData,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'image': image,
        'isRental': isRental,
        'quantity': quantity,
        'type': type,
        'rawData': rawData,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'],
        name: json['name'],
        price: json['price'],
        image: json['image'],
        isRental: json['isRental'],
        quantity: json['quantity'] ?? 1,
        type: json['type'],
        rawData: Map<String, dynamic>.from(json['rawData'] ?? {}),
      );
}

class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<CartItem> get items => [..._items];

  int get itemCount => _items.length;

  double get totalAmount {
    var total = 0.0;
    for (var item in _items) {
      total += item.price * item.quantity;
    }
    return total;
  }

  bool get hasRentalItems {
    return _items.any((item) => item.isRental);
  }

  CartProvider() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      final savedCart = await _storage.read(key: 'user_cart');
      if (savedCart != null) {
        final decoded = json.decode(savedCart) as List;
        _items = decoded.map((item) => CartItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      final encoded = json.encode(_items.map((item) => item.toJson()).toList());
      await _storage.write(key: 'user_cart', value: encoded);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  void addItem(Map<String, dynamic> product, {bool isRental = false}) {
    final productId = isRental 
        ? (product['laptop_id']?.toString() ?? product['id']?.toString() ?? '')
        : (product['product_id']?.toString() ?? product['id']?.toString() ?? '');
    
    final existingIndex = _items.indexWhere((item) => item.id == productId && item.isRental == isRental);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(
        CartItem(
          id: productId,
          name: isRental ? (product['nama_laptop'] ?? '') : (product['product_name'] ?? product['nama_laptop'] ?? ''),
          price: double.tryParse((isRental ? product['harga_sewa_ke_1'] : product['harga_jual'])?.toString() ?? '0') ?? 0,
          image: product['gambar'] ?? '',
          isRental: isRental,
          type: product['tipe_laptop'] ?? product['category_name'],
          rawData: product,
        ),
      );
    }
    _saveCart();
    notifyListeners();
  }

  void removeItem(String id, bool isRental) {
    _items.removeWhere((item) => item.id == id && item.isRental == isRental);
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(String id, bool isRental, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(id, isRental);
      return;
    }
    
    final index = _items.indexWhere((item) => item.id == id && item.isRental == isRental);
    if (index >= 0) {
      _items[index].quantity = newQuantity;
      _saveCart();
      notifyListeners();
    }
  }

  void clearByType({required bool isRental}) {
    _items.removeWhere((item) => item.isRental == isRental);
    _saveCart();
    notifyListeners();
  }

  void clear() {
    _items = [];
    _storage.delete(key: 'user_cart');
    notifyListeners();
  }
}
