import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../providers/cart_provider.dart';
import '../../../rent_plan/client/cart_checkout_page.dart';
import 'purchase_checkout_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  String _formatPrice(double price) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(price)
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cart = context.watch<CartProvider>();
    final rentalItems = cart.items.where((i) => i.isRental).toList();
    final purchaseItems = cart.items.where((i) => !i.isRental).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (cart.items.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
                child: Text('${cart.itemCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearConfirmation(context, cart),
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
              label: const Text('Hapus Semua', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? _buildEmptyCart(context, primaryColor)
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    children: [
                      if (rentalItems.isNotEmpty) ...[
                        _buildGroupHeader('Sewa Laptop', Icons.laptop_mac_rounded, const Color(0xFF673AB7)),
                        const SizedBox(height: 10),
                        ...rentalItems.map((item) => _buildCartItem(context, item, cart, isDark)),
                        const SizedBox(height: 16),
                      ],
                      if (purchaseItems.isNotEmpty) ...[
                        _buildGroupHeader('Beli Laptop', Icons.shopping_bag_rounded, const Color(0xFF009688)),
                        const SizedBox(height: 10),
                        ...purchaseItems.map((item) => _buildCartItem(context, item, cart, isDark)),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                _buildSummary(context, cart, primaryColor, isDark),
              ],
            ),
    );
  }

  Widget _buildGroupHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }

  Widget _buildEmptyCart(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined, size: 64, color: primaryColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          const Text('Keranjang Kosong', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Tambahkan produk ke keranjang\nuntuk melanjutkan belanja.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Kembali Belanja'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, CartProvider cart, bool isDark) {
    final Color typeColor = item.isRental ? const Color(0xFF673AB7) : const Color(0xFF009688);

    return Dismissible(
      key: Key('${item.id}_${item.isRental}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => cart.updateQuantity(item.id, item.isRental, 0),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Hapus', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: '${AppConstants.serverRoot}/uploads/products/${item.image}',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 88,
                        height: 88,
                        color: Colors.grey[100],
                        child: Icon(Icons.laptop_mac_rounded, color: Colors.grey[300], size: 30),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 88,
                        height: 88,
                        color: Colors.grey[100],
                        child: Icon(Icons.laptop_mac_rounded, color: Colors.grey[300], size: 30),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(item.isRental ? 'SEWA' : 'BELI',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.type != null && item.type!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(item.type!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatPrice(item.price),
                          style: TextStyle(fontWeight: FontWeight.w900, color: typeColor, fontSize: 15),
                        ),
                        _buildQtyControls(item, cart, typeColor),
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

  Widget _buildQtyControls(CartItem item, CartProvider cart, Color color) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQtyBtn(
            icon: item.quantity <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            color: item.quantity <= 1 ? Colors.redAccent : color,
            onTap: () => cart.updateQuantity(item.id, item.isRental, item.quantity - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('${item.quantity}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ),
          _buildQtyBtn(
            icon: Icons.add_rounded,
            color: color,
            onTap: () => cart.updateQuantity(item.id, item.isRental, item.quantity + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, size: 16, color: color)),
    );
  }

  Widget _buildSummary(BuildContext context, CartProvider cart, Color primaryColor, bool isDark) {
    final rentalCount = cart.items.where((i) => i.isRental).length;
    final purchaseCount = cart.items.where((i) => !i.isRental).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -6))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                if (rentalCount > 0) _buildCountChip('$rentalCount Sewa', const Color(0xFF673AB7)),
                if (rentalCount > 0 && purchaseCount > 0) const SizedBox(width: 8),
                if (purchaseCount > 0) _buildCountChip('$purchaseCount Beli', const Color(0xFF009688)),
                const Spacer(),
                Text('${cart.itemCount} item', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Pembayaran', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      _formatPrice(cart.totalAmount),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _handleCheckout(context, cart),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                  label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _handleCheckout(BuildContext context, CartProvider cart) async {
    final storage = const FlutterSecureStorage();
    final userDataStr = await storage.read(key: 'user_data');
    if (userDataStr == null) return;
    
    if (!context.mounted) return;

    final userData = json.decode(userDataStr);

    if (cart.items.isEmpty) return;

    if (cart.hasMixedItems) {
      _showMixedCheckoutOptions(context, cart, userData);
    } else if (cart.hasRentalItems) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CartCheckoutPage(userData: userData, items: cart.items),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseCheckoutPage(userData: userData, items: cart.items),
        ),
      );
    }
  }

  void _showMixedCheckoutOptions(BuildContext context, CartProvider cart, dynamic userData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilih Metode Checkout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Keranjang Anda berisi item Sewa dan Beli. Silakan pilih salah satu untuk diproses sekarang.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            _buildMixedOption(
              context: context,
              title: 'Checkout Sewa Laptop',
              subtitle: '${cart.items.where((i) => i.isRental).length} item sewa',
              icon: Icons.laptop_mac_rounded,
              color: const Color(0xFF673AB7),
              onTap: () {
                Navigator.pop(context);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CartCheckoutPage(
                      userData: userData,
                      items: cart.items.where((i) => i.isRental).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMixedOption(
              context: context,
              title: 'Checkout Beli Laptop',
              subtitle: '${cart.items.where((i) => !i.isRental).length} item beli',
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFF009688),
              onTap: () {
                Navigator.pop(context);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseCheckoutPage(
                      userData: userData,
                      items: cart.items.where((i) => !i.isRental).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMixedOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Kosongkan Keranjang'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin menghapus semua item dari keranjang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              cart.clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }
}
