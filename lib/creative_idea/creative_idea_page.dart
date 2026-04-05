import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/creative_idea_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';

class CreativeIdeaPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CreativeIdeaPage({super.key, required this.userData});

  @override
  State<CreativeIdeaPage> createState() => _CreativeIdeaPageState();
}

class _CreativeIdeaPageState extends State<CreativeIdeaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CreativeIdeaService _service = CreativeIdeaService();
  bool _isLoadingLeaderboard = true;
  bool _isLoadingIdeas = true;
  List<dynamic> _top5 = [];
  Map<String, dynamic> _userRank = {'rank': '-', 'total_approved': 0};
  List<dynamic> _allIdeas = [];
  List<dynamic> _myIdeas = [];
  String _ideaFilter = 'all'; // 'all' or 'mine'
  int _currentPage = 1;
  int _selectedLimit = 10;
  int _totalPages = 1;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLeaderboard();
    _fetchIdeas();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);
    final response = await _service.getLeaderboard();
    if (mounted) {
      if (response['status'] == true) {
        setState(() {
          _top5 = response['top5'] ?? [];
          _userRank = response['user_rank'] ?? {'rank': '-', 'total_approved': 0};
          _isLoadingLeaderboard = false;
        });
      } else {
        setState(() => _isLoadingLeaderboard = false);
      }
    }
  }

  Future<void> _fetchIdeas({int? page}) async {
    final int targetPage = page ?? _currentPage;
    setState(() => _isLoadingIdeas = true);
    final response = await _service.getIdeas(
      type: _ideaFilter,
      page: targetPage,
      limit: _selectedLimit,
    );
    if (mounted) {
      if (response['status'] == true) {
        setState(() {
          _currentPage = targetPage;
          _totalCount = response['total_count'] ?? 0;
          _totalPages = response['total_pages'] ?? 1;
          if (_ideaFilter == 'all') {
            _allIdeas = response['data'] ?? [];
          } else {
            _myIdeas = response['data'] ?? [];
          }
          _isLoadingIdeas = false;
        });
      } else {
        setState(() => _isLoadingIdeas = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'creative_idea.leaderboard'.tr(context)),
            Tab(text: 'creative_idea.all_ideas'.tr(context)),
          ],
        ),
      ),
      drawer: SideDrawer(
        userData: widget.userData,
        activePage: 'creative_idea',
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'creative_idea',
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(),
          _buildIdeasTab(),
        ],
      ),
      floatingActionButton: _hasPermission('idea2') 
        ? AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (context, child) {
              // animation.value ranges from 0.0 (Leaderboard) to 1.0 (All Ideas)
              final double value = _tabController.animation!.value;

              return TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: _isLoadingLeaderboard ? 0 : 80),
                builder: (context, baseHeight, child) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: (1.0 - value) * baseHeight),
                    child: child,
                  );
                },
                child: child,
              );
            },
            child: FloatingActionButton.extended(
              onPressed: _showAddIdeaSheet,
              backgroundColor: theme.colorScheme.primary,
              icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
              label: Text(
                'creative_idea.add_idea'.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        : null,
    );
  }

  Widget _buildLeaderboardTab() {
    if (_isLoadingLeaderboard) {
      return _buildLeaderboardShimmer();
    }

    return RefreshIndicator(
      onRefresh: _fetchLeaderboard,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 10),
              _buildPodium(),
              const SizedBox(height: 30),
              if (_top5.length > 3) ...[
                for (int i = 3; i < _top5.length; i++) _buildRankItem(_top5[i], i + 1),
              ],
              const SizedBox(height: 100), // Space for sticky footer
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildUserRankFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    // top5[0] is 1st, top5[1] is 2nd, top5[2] is 3rd
    final first = _top5.isNotEmpty ? _top5[0] : null;
    final second = _top5.length > 1 ? _top5[1] : null;
    final third = _top5.length > 2 ? _top5[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd Place
        _buildPodiumPosition(second, 2, 70),
        // 1st Place
        _buildPodiumPosition(first, 1, 90),
        // 3rd Place
        _buildPodiumPosition(third, 3, 60),
      ],
    );
  }

  Widget _buildPodiumPosition(dynamic user, int rank, double size) {
    final theme = Theme.of(context);
    final isFirst = rank == 1;
    final color = rank == 1 ? const Color(0xFFFFD700) : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size + 10,
              height: size + 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 4 : 2),
              ),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                backgroundImage: user != null && user['profile_photo'] != null && user['profile_photo'].toString().isNotEmpty
                    ? CachedNetworkImageProvider('https://foxgeen.com/HRIS/uploads/users/thumb/${user['profile_photo']}')
                    : null,
                onBackgroundImageError: (exception, stackTrace) {},
                child: (user == null || user['profile_photo'] == null || user['profile_photo'].toString().isEmpty)
                    ? Icon(Icons.person, size: size * 0.5, color: theme.colorScheme.primary)
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user != null ? '${user['first_name']}' : '---',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isFirst ? 14 : 12),
        ),
        Text(
          user != null ? '${user['total_approved']} Ideas' : '',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRankItem(dynamic user, int rank) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          backgroundImage: user['profile_photo'] != null && user['profile_photo'].toString().isNotEmpty
              ? CachedNetworkImageProvider('https://foxgeen.com/HRIS/uploads/users/thumb/${user['profile_photo']}')
              : null,
          onBackgroundImageError: (e, s) {},
          child: (user['profile_photo'] == null || user['profile_photo'].toString().isEmpty)
              ? Icon(Icons.person, size: 20, color: theme.colorScheme.primary)
              : null,
        ),
        title: Text(
          '${user['first_name']} ${user['last_name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${user['total_approved']} Ideas'),
        trailing: Text(
          '#$rank',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildUserRankFooter() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage: widget.userData['profile_photo'] != null && widget.userData['profile_photo'].toString().isNotEmpty
                ? CachedNetworkImageProvider('https://foxgeen.com/HRIS/uploads/users/thumb/${widget.userData['profile_photo']}')
                : null,
            onBackgroundImageError: (e, s) {},
            child: (widget.userData['profile_photo'] == null || widget.userData['profile_photo'].toString().isEmpty)
                ? Icon(Icons.person, size: 20, color: theme.colorScheme.primary)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'creative_idea.your_rank'.tr(context),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.userData['nama'] ?? 'User',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${_userRank['rank']}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              Text(
                '${_userRank['total_approved']} Approved',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdeasTab() {
    final theme = Theme.of(context);
    final isAll = _ideaFilter == 'all';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(15),
              border: theme.brightness == Brightness.dark
                  ? Border.all(color: Colors.white24)
                  : Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isAll ? Alignment.centerLeft : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _ideaFilter = 'all';
                            _currentPage = 1;
                          });
                          _fetchIdeas();
                        },
                        child: Center(
                          child: Text(
                            'creative_idea.all_ideas'.tr(context),
                            style: TextStyle(
                              color: isAll ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _ideaFilter = 'mine';
                            _currentPage = 1;
                          });
                          _fetchIdeas();
                        },
                        child: Center(
                          child: Text(
                            'creative_idea.my_ideas'.tr(context),
                            style: TextStyle(
                              color: !isAll ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoadingIdeas
              ? _buildIdeasShimmer()
              : RefreshIndicator(
                  onRefresh: _fetchIdeas,
                  child: (_ideaFilter == 'all' ? _allIdeas : _myIdeas).isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Text('creative_idea.empty_ideas'.tr(context)),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                          itemCount: (_ideaFilter == 'all' ? _allIdeas : _myIdeas).length + 1 + (_totalPages > 1 ? 1 : 0),
                          itemBuilder: (context, index) {
                            final listData = (_ideaFilter == 'all' ? _allIdeas : _myIdeas);
                            
                            // Item Pertama: Header Paginasi (Show & Total)
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPaginationHeader(),
                              );
                            }
                            
                            // Item Terakhir: Kontrol Paginasi (Prev/Next)
                            if (index == listData.length + 1) {
                              return _buildPaginationControls();
                            }
                            
                            // Item Data
                            final idea = listData[index - 1];
                            return _buildIdeaCard(idea);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildPaginationHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'main.show'.tr(context),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            _buildPremiumDropdown(),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'todo_list.total'.tr(
              context,
              args: {'count': _totalCount.toString()},
            ),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdown() {
    final theme = Theme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLimit,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                _currentPage = 1;
              });
              _fetchIdeas();
            }
          },
          items: _limitOptions.map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text(value.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox(height: 20);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageButton(
            icon: Icons.chevron_left_rounded,
            onPressed: _currentPage > 1 ? () => _fetchIdeas(page: _currentPage - 1) : null,
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'todo_list.page_x_of_y'.tr(
                context,
                args: {
                  'current': _currentPage.toString(),
                  'total': _totalPages.toString(),
                },
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildPageButton(
            icon: Icons.chevron_right_rounded,
            onPressed: _currentPage < _totalPages ? () => _fetchIdeas(page: _currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: onPressed == null ? (isDark ? Colors.white12 : Colors.grey[200]) : theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null ? (isDark ? Colors.white24 : Colors.grey[400]) : theme.colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _showIdeaDetail(dynamic idea) {
    final theme = Theme.of(context);
    final status = int.tryParse(idea['status'].toString()) ?? 0;
    
    Color statusColor;
    String statusLabel;
    
    if (status == 1) {
      statusColor = Colors.green;
      statusLabel = 'creative_idea.approved'.tr(context);
    } else if (status == 2) {
      statusColor = Colors.red;
      statusLabel = 'creative_idea.rejected'.tr(context);
    } else {
      statusColor = Colors.orange;
      statusLabel = 'creative_idea.pending'.tr(context);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Idea Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildIdeaMoreMenu(idea),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    idea['title'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(
              Icons.person_outline_rounded,
              'Proposed By',
              '${idea['first_name']} ${idea['last_name']}',
            ),
            const Divider(height: 32),
            _buildDetailRow(
              Icons.calendar_today_outlined,
              'Posted At',
              idea['created_at'] ?? '-',
            ),
            const Divider(height: 32),
            _buildDetailRow(
              Icons.info_outline_rounded,
              'Status',
              statusLabel,
            ),
            const SizedBox(height: 32),
            Text(
              'creative_idea.idea_description'.tr(context),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Text(
                idea['description']?.toString().isNotEmpty == true
                    ? idea['description']
                    : 'No description provided.',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildIdeaMoreMenu(dynamic idea) {
    final canEdit = _hasPermission('idea3');
    final canDelete = _hasPermission('idea4');

    if (!canEdit && !canDelete) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditIdeaSheet(idea);
        } else if (value == 'delete') {
          _confirmDeleteIdea(idea);
        }
      },
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF7E57C2)),
                const SizedBox(width: 12),
                Text('creative_idea.edit'.tr(context)),
              ],
            ),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                const SizedBox(width: 12),
                Text('creative_idea.delete'.tr(context)),
              ],
            ),
          ),
      ],
    );
  }

  void _showEditIdeaSheet(dynamic idea) {
    final titleController = TextEditingController(text: idea['title']);
    final descController = TextEditingController(text: idea['description']);
    int selectedStatus = int.tryParse(idea['status'].toString()) ?? 0;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'creative_idea.edit'.tr(context),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'creative_idea.idea_title'.tr(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'creative_idea.idea_title'.tr(context),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'main.status'.tr(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: selectedStatus,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                ),
                dropdownColor: theme.cardColor,
                items: [
                  DropdownMenuItem(value: 0, child: Text('creative_idea.pending'.tr(context))),
                  DropdownMenuItem(value: 1, child: Text('creative_idea.approved'.tr(context))),
                  DropdownMenuItem(value: 2, child: Text('creative_idea.rejected'.tr(context))),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedStatus = val);
                },
              ),
              const SizedBox(height: 20),
              Text(
                'creative_idea.idea_description'.tr(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 5,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'creative_idea.idea_description'.tr(context),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) return;
                  
                  showDialog(
                    context: context, 
                    barrierDismissible: false, 
                    builder: (_) => const Center(child: CircularProgressIndicator())
                  );
                  
                  final res = await _service.updateIdea(
                    idea['complaint_id'].toString(),
                    titleController.text,
                    descController.text,
                    selectedStatus,
                  );
                  
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    if (res['status'] == true) {
                      Navigator.pop(context); // Close edit sheet
                      Navigator.pop(context); // Close detail sheet
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('creative_idea.update_success'.tr(context)),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _fetchIdeas();
                      _fetchLeaderboard();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message'] ?? 'Error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                ),
                child: Text(
                  'main.save'.tr(context),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteIdea(dynamic idea) {
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'creative_idea.confirm_delete'.tr(context),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'creative_idea.confirm_delete_msg'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text('main.delete'.tr(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((confirm) async {
      if (confirm == true && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        
        final res = await _service.deleteIdea(idea['complaint_id'].toString());
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          if (res['status'] == true) {
            Navigator.pop(context); // Close detail sheet
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('creative_idea.delete_success'.tr(context)),
                backgroundColor: Colors.green,
              ),
            );
            _fetchIdeas();
            _fetchLeaderboard();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['message'] ?? 'Error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }


  Widget _buildDetailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const Spacer(),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildIdeaCard(dynamic idea) {
    final theme = Theme.of(context);
    final status = int.tryParse(idea['status'].toString()) ?? 0;
    
    Color statusColor;
    String statusLabel;
    
    if (status == 1) {
      statusColor = Colors.green;
      statusLabel = 'creative_idea.approved'.tr(context);
    } else if (status == 2) {
      statusColor = Colors.red;
      statusLabel = 'creative_idea.rejected'.tr(context);
    } else {
      statusColor = Colors.orange;
      statusLabel = 'creative_idea.pending'.tr(context);
    }

    return InkWell(
      onTap: () => _showIdeaDetail(idea),
      borderRadius: BorderRadius.circular(15),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  Text(
                    idea['created_at'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                idea['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                idea['description'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: idea['profile_photo'] != null && idea['profile_photo'].toString().isNotEmpty
                        ? CachedNetworkImageProvider('https://foxgeen.com/HRIS/uploads/users/thumb/${idea['profile_photo']}')
                        : null,
                    onBackgroundImageError: (e, s) {},
                    child: (idea['profile_photo'] == null || idea['profile_photo'].toString().isEmpty)
                        ? Icon(Icons.person, size: 12, color: theme.colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${idea['first_name']} ${idea['last_name']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardShimmer() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ),
    );
  }



  Widget _buildIdeasShimmer() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showAddIdeaSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'creative_idea.add_idea'.tr(context),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'creative_idea.idea_title'.tr(context),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'creative_idea.idea_title'.tr(context),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'creative_idea.idea_description'.tr(context),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              maxLines: 5,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'creative_idea.idea_description'.tr(context),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                
                showDialog(
                  context: context, 
                  barrierDismissible: false, 
                  builder: (_) => const Center(child: CircularProgressIndicator())
                );
                
                final res = await _service.submitIdea(titleController.text, descController.text);
                
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  if (res['status'] == true) {
                    Navigator.pop(context); // Close sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('creative_idea.success_msg'.tr(context)),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchIdeas();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.4),
              ),
              child: Text(
                'creative_idea.submit'.tr(context),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
