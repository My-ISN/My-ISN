import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../localization/app_localizations.dart';
import '../../../widgets/connectivity_wrapper.dart';

class CustomerDashboardContent extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> customerDashboardData;
  final Future<void> Function() onRefresh;
  final Function(int) onProfileTap;
  final Function(String, String) onLaunchWhatsApp;
  final Function(bool)? onSearchToggle;
  final bool isSearchActive;
  final Function(String)? onLoadMore;
  final bool isLoadingMore;
  final bool hasMoreRental;
  final bool hasMorePurchase;

  const CustomerDashboardContent({
    super.key,
    required this.userData,
    required this.customerDashboardData,
    required this.onRefresh,
    required this.onProfileTap,
    required this.onLaunchWhatsApp,
    this.onSearchToggle,
    this.isSearchActive = false,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMoreRental = true,
    this.hasMorePurchase = true,
  });

  @override
  State<CustomerDashboardContent> createState() => _CustomerDashboardContentState();
}

class _CustomerDashboardContentState extends State<CustomerDashboardContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _bannerController = PageController(initialPage: 498); 
  int _currentBannerPage = 0;
  Timer? _bannerTimer;
  final ScrollController _scrollController = ScrollController();

  // Search State
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<String> _searchHistory = [];
  List<String> _searchSuggestions = [];

  final List<String> _promoImages = [
    'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentBannerPage = 498 % _promoImages.length; 
        });
      }
    });
    _currentBannerPage = 498 % _promoImages.length;
    _startBannerAutoScroll();
    _isSearchActive = widget.isSearchActive;
    _loadSearchHistory();
    _generateSuggestions();
  }

  @override
  void didUpdateWidget(CustomerDashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSearchActive != oldWidget.isSearchActive) {
      setState(() {
        _isSearchActive = widget.isSearchActive;
      });

      if (_isSearchActive) {
        _searchFocusNode.requestFocus();
      } else {
        _searchFocusNode.unfocus();
        _searchController.clear();
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!widget.isLoadingMore) {
        final type = _tabController.index == 0 ? 'rental' : 'purchase';
        final hasMore = _tabController.index == 0 ? widget.hasMoreRental : widget.hasMorePurchase;
        if (hasMore) {
          widget.onLoadMore?.call(type);
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    return _tabController.index == 0 ? const Color(0xFF673AB7) : const Color(0xFF009688);
  }

  // --- Search Logic ---
  
  void _generateSuggestions() {
    final List products = widget.customerDashboardData['products'] ?? [];
    final List purchaseProducts = widget.customerDashboardData['purchase_products'] ?? [];
    
    final Set<String> uniqueNames = {};
    
    // Mix items from both tabs for comprehensive suggestions
    for (var p in products) {
      if (p['nama_laptop'] != null) uniqueNames.add(p['nama_laptop']);
    }
    for (var p in purchaseProducts) {
      if (p['nama_laptop'] != null) uniqueNames.add(p['nama_laptop']);
    }
    
    setState(() {
      _searchSuggestions = uniqueNames.take(8).toList();
      // Simple HTML fix for suggestions
      _searchSuggestions = _searchSuggestions.map((name) {
        return name.replaceAll('&#34;', '"').replaceAll('&#39;', "'").replaceAll('&amp;', '&');
      }).toList();
    });
  }

  Future<void> _loadSearchHistory() async {
    try {
      final String? historyJson = await _storage.read(key: 'customer_search_history');
      if (historyJson != null) {
        final List<dynamic> decoded = json.decode(historyJson);
        setState(() {
          _searchHistory = decoded.cast<String>();
        });
      }
    } catch (e) {
      debugPrint('Error loading search history: $e');
    }
  }

  Future<void> _saveSearchHistory() async {
    try {
      await _storage.write(
        key: 'customer_search_history',
        value: json.encode(_searchHistory),
      );
    } catch (e) {
      debugPrint('Error saving search history: $e');
    }
  }

  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      // Move to top if exists, otherwise add to front
      _searchHistory.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
      _searchHistory.insert(0, query.trim());
      
      // Limit count
      if (_searchHistory.length > 5) {
        _searchHistory = _searchHistory.sublist(0, 5);
      }
    });
    
    _saveSearchHistory();
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
    _saveSearchHistory();
  }

  void _triggerSearch(String query) {
    _searchController.text = query;
    _addToHistory(query);
    // Here you would trigger real search logic if implemented
    setState(() {});
  }



  @override
  Widget build(BuildContext context) {
    final stats = widget.customerDashboardData['stats'] ?? {};
    final products = widget.customerDashboardData['products'] ?? [];
    final purchaseProducts = widget.customerDashboardData['purchase_products'] ?? [];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          displacement: 20,
          color: _getActiveColor(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1 & 2. Composite Header (Banner + Sticky Search Bar)
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  promoImages: _promoImages,
                  bannerController: _bannerController,
                  currentBannerPage: _currentBannerPage,
                  onPageChanged: (index) {
                    setState(() {
                      _currentBannerPage = index % _promoImages.length;
                    });
                  },
                  searchBarBuilder: (context, searchOpacity) => _buildFloatingSearchBar(
                    context,
                    searchOpacity: searchOpacity,
                    onProfileTap: () => Scaffold.of(context).openEndDrawer(),
                    onCartTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Keranjang akan segera hadir!')),
                      );
                    },
                  ),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  activeColor: _getActiveColor(),
                  statusBarHeight: MediaQuery.of(context).padding.top,
                  profilePhoto: widget.userData['profile_photo']?.toString(),
                  onProfileTap: () => Scaffold.of(context).openEndDrawer(),
                  onCartTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Keranjang akan segera hadir!')),
                    );
                  },
                ),
              ),

              // 3. The rest of the content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 32), // Re-increased since pinned header is now smaller but still needs overlap space
                    // Mini Stats/Balance Bar
                    _buildMiniStatsBar(context, stats),
                    const SizedBox(height: 24),

                    // Tab Bar Selector
                    _buildModeSelector(context),
                    const SizedBox(height: 12),

                    // Section Title
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

                    // Product Grid
                    _buildProductGrid(context, _tabController.index == 0 ? products : purchaseProducts),

                    if (widget.isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _getActiveColor(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Memuat produk lainnya...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    if (_tabController.index == 0) _buildHelpCard(context),
                    const SizedBox(height: 48), // Bottom safe area
                  ]),
                ),
              ),
            ],
          ),
        ),
        
        // Search Overlay
        if (_isSearchActive) _buildSearchOverlay(context),
      ],
    );
  }


  Widget _buildFloatingSearchBar(BuildContext context, {
    required double searchOpacity,
    required VoidCallback onProfileTap, 
    required VoidCallback onCartTap
  }) {
    // Icons only appear in the search bar once it's mostly pinned
    final double iconOpacity = (searchOpacity - 0.6).clamp(0.0, 1.0) * 2.5;
    
    return Container(
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
          Expanded(
            child: GestureDetector(
              onTap: () {
                widget.onSearchToggle?.call(true);
              },
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
                ],
              ),
            ),
          ),
          
          if (iconOpacity > 0) ...[
            // Divider
            Opacity(
              opacity: iconOpacity,
              child: Container(
                height: 20,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            
            // Action Icons
            Opacity(
              opacity: iconOpacity,
              child: Row(
                children: [
                  IconButton(
                    onPressed: onCartTap,
                    icon: Icon(Icons.shopping_cart_outlined, 
                      color: Theme.of(context).hintColor, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: onProfileTap,
                    icon: Container(
                      padding: (widget.userData['profile_photo'] != null && 
                               widget.userData['profile_photo'].toString().isNotEmpty) 
                          ? EdgeInsets.zero 
                          : const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: (widget.userData['profile_photo'] != null && 
                                 widget.userData['profile_photo'].toString().isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: '${AppConstants.serverRoot}/uploads/users/thumb/${widget.userData['profile_photo']}',
                                width: 30, // Proportional for search bar icon size
                                height: 30,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Icon(Icons.person, size: 18, color: Colors.grey),
                                errorWidget: (context, url, error) => const Icon(Icons.person, size: 18, color: Colors.grey),
                              )
                            : Icon(Icons.person_outline_rounded, 
                                color: Theme.of(context).colorScheme.primary, size: 18),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              // Search Header (Top Bar Full Width)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
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
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: theme.iconTheme.color),
                      onPressed: () {
                        widget.onSearchToggle?.call(false);
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Cari laptop impianmu...',
                            hintStyle:
                                TextStyle(color: theme.hintColor, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            _addToHistory(value);
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pencarian Terakhir',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: _clearHistory,
                            child: const Text(
                              'Hapus Semua',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
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
    return GestureDetector(
      onTap: () => _triggerSearch(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(String label) {
    return GestureDetector(
      onTap: () => _triggerSearch(label),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.trending_up_rounded, size: 18, color: Theme.of(context).hintColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
              ),
            ),
            Icon(Icons.north_west_rounded, size: 16, color: Theme.of(context).hintColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }



  Widget _buildPromoBanner(BuildContext context) {
    return SizedBox(
      height: 250, // Increased to match header
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
        childAspectRatio: 0.55, // Adjusted to 0.65 to reduce empty space (was 0.5)
      ),
      itemBuilder: (context, index) {
        return _buildProductCard(context, products[index]);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Map p) {
    final String laptopBaseUrl = '${AppConstants.serverRoot}/uploads/products/';
    final String image = p['gambar'] ?? '';
    String name = p['nama_laptop'] ?? 'Laptop';
    
    // Simple HTML unescape for common entities
    name = name.replaceAll('&#34;', '"').replaceAll('&#39;', "'").replaceAll('&amp;', '&');
    
    // Get price based on context
    double price = 0;
    if (_tabController.index == 0) {
      price = double.tryParse((p['harga_sewa_ke_1'] ?? '0').toString()) ?? 0;
    } else {
      price = double.tryParse((p['harga_beli'] ?? '0').toString()) ?? 0;
    }

    final rating = double.tryParse((p['product_rating'] ?? 0).toString()) ?? 0;
    final sold = int.tryParse((p['total_sold'] ?? 0).toString()) ?? 0;

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
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13, // Reduced from 14
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rp ${_formatPrice(price)}',
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
                        '${rating > 0 ? rating : '4.8'} | Terjual ${sold > 0 ? sold : '0'}',
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> promoImages;
  final PageController bannerController;
  final int currentBannerPage;
  final Function(int) onPageChanged;
  final Widget Function(BuildContext, double) searchBarBuilder;
  final Color backgroundColor;
  final Color activeColor;
  final double statusBarHeight;
  final String? profilePhoto;
  final VoidCallback onProfileTap;
  final VoidCallback onCartTap;

  _StickyHeaderDelegate({
    required this.promoImages,
    required this.bannerController,
    required this.currentBannerPage,
    required this.onPageChanged,
    required this.searchBarBuilder,
    required this.backgroundColor,
    required this.activeColor,
    required this.statusBarHeight,
    this.profilePhoto,
    required this.onProfileTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    const double bannerHeight = 250.0; // Increased from 220
    const double searchBarOverlap = 10.0; // Reduced overlap for lower position
    final double opacity = (1.0 - (shrinkOffset / (maxExtent - minExtent))).clamp(0.0, 1.0);
    final double searchOpacity = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Banner
        Positioned(
          top: -shrinkOffset,
          left: 0,
          right: 0,
          height: bannerHeight,
          child: Opacity(
            opacity: opacity,
            child: _buildBanner(context, bannerHeight),
          ),
        ),

        // 2. Sticky Background
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: minExtent,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor.withValues(alpha: searchOpacity),
              boxShadow: searchOpacity > 0.9 
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ] 
                : null,
            ),
          ),
        ),

        // 3. Search Bar
        Positioned(
          top: (bannerHeight - searchBarOverlap - shrinkOffset).clamp(statusBarHeight + 12.0, bannerHeight - searchBarOverlap),
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20 * (1 - searchOpacity).clamp(0.1, 1.0),
            ),
            child: searchBarBuilder(context, searchOpacity),
          ),
        ),

        // 4. Top Actions Bar (Only visible when banner is expanded)
        Positioned(
          top: statusBarHeight,
          left: 0,
          right: 0,
          child: _buildTopActions(context, searchOpacity),
        ),
      ],
    );
  }

  Widget _buildTopActions(BuildContext context, double searchOpacity) {
    // Fades out as we scroll down
    final double topOpacity = (1.0 - searchOpacity * 2).clamp(0.0, 1.0);
    
    if (topOpacity <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: topOpacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildTopIcon(
              context, 
              icon: Icons.shopping_cart_outlined, 
              onTap: onCartTap,
              searchOpacity: 0.0, 
            ),
            const SizedBox(width: 12),
            _buildTopIcon(
              context, 
              icon: Icons.person_outline_rounded, 
              onTap: onProfileTap,
              searchOpacity: 0.0,
              isProfile: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIcon(BuildContext context, {
    required IconData icon, 
    required VoidCallback onTap, 
    required double searchOpacity,
    bool isProfile = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: (isProfile && profilePhoto != null && profilePhoto!.isNotEmpty) 
            ? EdgeInsets.zero 
            : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.black.withValues(alpha: 0.2), 
            activeColor.withValues(alpha: 0.1), 
            searchOpacity
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Color.lerp(
              Colors.white.withValues(alpha: 0.3), 
              activeColor.withValues(alpha: 0.3), 
              searchOpacity
            )!,
            width: 1,
          ),
        ),
        child: ClipOval(
          child: (isProfile && profilePhoto != null && profilePhoto!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: '${AppConstants.serverRoot}/uploads/users/thumb/$profilePhoto',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                placeholder: (context, url) => Icon(icon, size: 22, color: Colors.white),
                errorWidget: (context, url, error) => Icon(icon, size: 22, color: Colors.white),
              )
            : Icon(
                icon,
                size: 22,
                color: Color.lerp(Colors.white, activeColor, searchOpacity),
              ),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, double height) {
    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: bannerController,
        onPageChanged: onPageChanged,
        itemCount: 1000,
        itemBuilder: (context, index) {
          final imageIndex = index % promoImages.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: promoImages[imageIndex],
                fit: BoxFit.cover,
              ),
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
            ],
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 280.0; // Reduced back to normal dimensions

  @override
  double get minExtent => statusBarHeight + 85.0; // Reduced head height since it's just one line now

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return currentBannerPage != oldDelegate.currentBannerPage ||
        activeColor != oldDelegate.activeColor;
  }
}
