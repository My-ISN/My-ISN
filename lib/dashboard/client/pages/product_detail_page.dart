import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../providers/cart_provider.dart';
import '../../../localization/app_localizations.dart';
import 'cart_page.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isRental;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.isRental,
  });

  String _formatPrice(double price) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: '',
      decimalDigits: 0,
    ).format(price).trim();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final String name = isRental 
        ? (product['nama_laptop'] ?? '') 
        : (product['product_name'] ?? product['nama_laptop'] ?? '');
        
    final double price = double.tryParse((isRental 
        ? product['harga_sewa_ke_1'] 
        : product['harga_jual'])?.toString() ?? '0') ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero Image / App Bar
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: isDark ? Colors.black : Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'product_${product['laptop_id'] ?? product['product_id']}_$isRental',
                    child: CachedNetworkImage(
                      imageUrl: '${AppConstants.serverRoot}/uploads/products/${product['gambar']}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.laptop_chromebook_rounded, size: 50),
                      ),
                    ),
                  ),
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black26,
                      child: Consumer<CartProvider>(
                        builder: (context, cart, child) {
                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CartPage()),
                                  );
                                },
                              ),
                              if (cart.itemCount > 0)
                                Positioned(
                                  right: 5,
                                  top: 5,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '${cart.itemCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge & Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isRental ? Colors.blue : Colors.green).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRental ? 'PENYEWAAN' : 'PEMBELIAN',
                              style: TextStyle(
                                color: isRental ? Colors.blue : Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            product['tipe_laptop'] ?? 'Notebook',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rp ${_formatPrice(price)}${isRental ? " / hari" : ""}',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      const Text(
                        'Spesifikasi',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildSpecTile(Icons.memory_rounded, 'Processor', product['procesor'], primaryColor),
                      _buildSpecTile(Icons.memory_rounded, 'RAM', product['ram'], primaryColor),
                      _buildSpecTile(Icons.storage_rounded, 'Storage', product['hdd'], primaryColor),
                      _buildSpecTile(Icons.display_settings_rounded, 'VGA', product['vga'], primaryColor),
                      _buildSpecTile(Icons.screenshot_rounded, 'Screen', product['layar'], primaryColor),
                      
                      const SizedBox(height: 120), // Padding for sticky button
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky Button at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<CartProvider>().addItem(product, isRental: isRental);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name berhasil ditambahkan ke keranjang!'),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'LIHAT',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CartPage()),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Tambah ke Keranjang',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
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

  Widget _buildSpecTile(IconData icon, String label, String? value, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(
                value ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
