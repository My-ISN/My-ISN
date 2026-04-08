import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants.dart';
import '../../../localization/app_localizations.dart';
import '../../../widgets/connectivity_wrapper.dart';
import 'package:intl/intl.dart';

class CustomerDashboardContent extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> customerDashboardData;
  final Future<void> Function() onRefresh;
  final Function(int) onProfileTap;
  final Function(String, String) onLaunchWhatsApp;

  const CustomerDashboardContent({
    super.key,
    required this.userData,
    required this.customerDashboardData,
    required this.onRefresh,
    required this.onProfileTap,
    required this.onLaunchWhatsApp,
  });

  @override
  State<CustomerDashboardContent> createState() => _CustomerDashboardContentState();
}

class _CustomerDashboardContentState extends State<CustomerDashboardContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _bannerController = PageController(initialPage: 498); 
  int _currentBannerPage = 0;
  Timer? _bannerTimer;

  // Search State
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _searchHistory = [
    'Lenovo Thinkpad',
    'Laptop Gaming i7',
    'Macbook Pro 2020',
    'Charger Asus',
  ];

  final List<String> _searchSuggestions = [
    'Lenovo T460s',
    'Dell Latitude',
    'HP Elitebook',
    'Asus ROG',
  ];

  final List<String> _promoImages = [
    'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentBannerPage = 498 % _promoImages.length; // Reset banner on tab change maybe?
        });
      }
    });
    _currentBannerPage = 498 % _promoImages.length;
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        _bannerController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(double.tryParse(price.toString()) ?? 0);
  }

  Color _getActiveColor() {
    return _tabController.index == 0 ? const Color(0xFF673AB7) : const Color(0xFF00897B);
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.customerDashboardData['stats'] ?? {};
    final products = widget.customerDashboardData['products'] ?? [];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          displacement: 20,
          color: _getActiveColor(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner and Floating Search Bar Section
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildPromoBanner(context), // Carousel Redesign
                    Positioned(
                      bottom: -28,
                      left: 20,
                      right: 20,
                      child: _buildFloatingSearchBar(context),
                    ),
                  ],
                ),

                const SizedBox(height: 52), // space for floating search bar

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3. Mini Stats/Balance Bar (Gopay/Ovo Style)
                      _buildMiniStatsBar(context, stats),
                      const SizedBox(height: 24),

                      // Tab Bar Selector (Sewa vs Beli)
                      _buildModeSelector(context),
                      const SizedBox(height: 12), // Reduced from 32 to 12

                      // 5. Section Title: For You / Rekomendasi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tabController.index == 0 
                                ? 'Rekomendasi Sewa' 
                                : 'Katalog Pembelian',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'dashboard.see_all'.tr(context) == 'dashboard.see_all' 
                                  ? 'Lihat Semua' 
                                  : 'dashboard.see_all'.tr(context),
                              style: TextStyle(color: _getActiveColor(), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 6. 2-Column Product Grid
                      _buildProductGrid(context, products),

                      const SizedBox(height: 20), // Adjusted to 16 for better balance

                      // Help Section at the bottom
                      _buildHelpCard(context),

                      ValueListenableBuilder<double>(
                        valueListenable: ConnectivityStatus.bottomPadding,
                        builder: (context, padding, _) =>
                            SizedBox(height: padding.clamp(20.0, double.infinity)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isSearchActive) _buildSearchOverlay(context),
      ],
    );
  }


  Widget _buildFloatingSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSearchActive = true;
          _searchFocusNode.requestFocus();
        });
      },
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30), // Pill Shape
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8), // More depth
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF7E57C2), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'dashboard.search_placeholder'.tr(context),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 24,
              width: 1,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 12),
            Icon(Icons.camera_alt_outlined, color: Colors.grey[500], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Search Header (Top Bar Full Width)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: Colors.black87),
                      onPressed: () {
                        setState(() {
                          _isSearchActive = false;
                        });
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Cari laptop impianmu...',
                            hintStyle:
                                TextStyle(color: Colors.grey[400], fontSize: 14),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            // Implement real search if needed
                          },
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),

              // Suggestions & History Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // History Section
                    if (_searchHistory.isNotEmpty) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pencarian Terakhir',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Hapus Semua',
                            style: TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _searchHistory
                            .map((item) => _buildHistoryChip(item))
                            .toList(),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Suggestions Section
                    const Text(
                      'Mungkin Kamu Suka',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: _searchSuggestions
                          .map((item) => _buildSuggestionTile(item))
                          .toList(),
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

  Widget _buildHistoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.grey[700], fontSize: 12),
      ),
    );
  }

  Widget _buildSuggestionTile(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
            ),
          ),
          Icon(Icons.north_west_rounded, size: 16, color: Colors.grey[300]),
        ],
      ),
    );
  }



  Widget _buildPromoBanner(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() {
                _currentBannerPage = index % _promoImages.length;
              });
            },
            itemCount: 1000, 
            itemBuilder: (context, index) {
              final imageIndex = index % _promoImages.length;
              return Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _promoImages[imageIndex],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF673AB7).withValues(alpha: 0.1),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error),
                    ),
                  ),
                  // Dark Overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  // Placeholder Text Content
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF673AB7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            imageIndex == 0 ? 'NEW ARRIVAL' : (imageIndex == 1 ? 'BEST DEAL' : 'LIMITED'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          imageIndex == 0 
                            ? 'Laptop Generasi Baru\nSiap Disewa!' 
                            : (imageIndex == 1 ? 'Diskon Akhir Pekan\nHingga 30%!' : 'Stok Terbatas\nAmankan Unitmu!'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Dot Indicators
          Positioned(
            bottom: 40, // Above the search bar overlap
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _promoImages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: _currentBannerPage == index ? 20 : 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _currentBannerPage == index ? 1.0 : 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatsBar(BuildContext context, Map stats) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildMiniStatItem(
              context,
              Icons.laptop_mac_rounded,
              'dashboard.rental_active'.tr(context),
              '${stats['active_rentals'] ?? 0}',
              const Color(0xFF4CAF50),
            ),
            Container(
              height: 30,
              width: 1,
              color: Colors.grey.withValues(alpha: 0.1),
            ),
            _buildMiniStatItem(
              context,
              Icons.account_balance_wallet_rounded,
              'dashboard.total_unpaid'.tr(context),
              'Rp ${_formatPrice(stats['total_unpaid'] ?? 0)}',
              const Color(0xFFF44336),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildModeSelector(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: _getActiveColor(),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _getActiveColor().withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'Penyewaan'),
          Tab(text: 'Pembelian'),
        ],
        onTap: (index) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildMiniStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildProductGrid(BuildContext context, List products) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('Belum ada produk tersedia', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero, // Explicitly zero padding to remove space
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.6, // Adjusted from 0.68 to 0.6 to fix overflow
      ),
      itemBuilder: (context, index) {
        return _buildProductCard(context, products[index]);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Map p) {
    final String laptopBaseUrl = '${AppConstants.serverRoot}/uploads/products/';
    final String image = p['gambar'] ?? '';
    final String name = p['nama_laptop'] ?? 'Laptop';
    final double price = double.tryParse((p['harga_sewa_ke_1'] ?? '0').toString()) ?? 0;

    return GestureDetector(
      onTap: () => _showProductSpecs(context, p),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: '$laptopBaseUrl$image',
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 140,
                      color: Colors.grey.withValues(alpha: 0.05),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 140,
                      color: Colors.grey.withValues(alpha: 0.05),
                      child: const Icon(Icons.laptop, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getActiveColor(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _tabController.index == 0 ? 'SEWA' : 'BARU',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tabController.index == 0 ? 'Rp ${_formatPrice(price)}' : 'Rp ${_formatPrice(price * 25)}', // Mock higher price for buying
                    style: TextStyle(
                      color: _getActiveColor(),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced from 10 to 6
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.orangeAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '4.8 | Terjual 100+',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.grey[400], size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Bandung',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
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

  Widget _buildHelpCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3F51B5),
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: const NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'),
          opacity: 0.1,
          repeat: ImageRepeat.repeat,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Butuh Bantuan?',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hubungi CS kami untuk bantuan teknis dan ketersediaan unit.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => widget.onLaunchWhatsApp('0895384314416', 'Halo ISN, saya butuh bantuan...'),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                  label: const Text('Chat di WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.support_agent_rounded, size: 80, color: Colors.white24),
        ],
      ),
    );
  }

  void _showProductSpecs(BuildContext context, Map p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: '${AppConstants.serverRoot}/uploads/products/${p['gambar']}',
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['nama_laptop'] ?? '',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p['tipe_laptop'] ?? 'Notebook',
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Rp ${_formatPrice(double.tryParse(p['harga_sewa_ke_1'].toString()) ?? 0)}',
                            style: const TextStyle(
                              color: Color(0xFF7E57C2),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Spesifikasi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildSpecTile(Icons.memory_rounded, 'Processor', p['procesor']),
                    _buildSpecTile(Icons.memory_rounded, 'RAM', p['ram']),
                    _buildSpecTile(Icons.storage_rounded, 'Storage', p['hdd']),
                    _buildSpecTile(Icons.display_settings_rounded, 'VGA', p['vga']),
                    _buildSpecTile(Icons.screenshot_rounded, 'Screen', p['layar']),
                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecTile(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF7E57C2)),
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
