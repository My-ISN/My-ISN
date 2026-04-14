import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../widgets/secondary_app_bar.dart';
import '../providers/quick_menu_provider.dart';
import 'staff/widgets/menu_registry.dart';
import 'dashboard_page.dart';

class AllMenusPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool Function(String) hasPermission;

  const AllMenusPage({
    super.key,
    required this.userData,
    required this.hasPermission,
  });

  @override
  State<AllMenusPage> createState() => _AllMenusPageState();
}

class _AllMenusPageState extends State<AllMenusPage> {
  bool _isEditing = false;
  List<String>? _tempPinnedKeys;

  void _startEditing(List<String>? currentKeys) {
    setState(() {
      _isEditing = true;
      _tempPinnedKeys = currentKeys != null ? List.from(currentKeys) : [];
    });
  }

  void _togglePinned(String key) {
    setState(() {
      if (_tempPinnedKeys!.contains(key)) {
        _tempPinnedKeys!.remove(key);
      } else if (_tempPinnedKeys!.length < 5) {
        _tempPinnedKeys!.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quickMenuProvider = Provider.of<QuickMenuProvider>(context);

    final allModules = MenuRegistry.getModules(widget.userData);
    final permittedModules = allModules.where((m) {
      if (m.permission == null) return true;
      return widget.hasPermission(m.permission!);
    }).toList();

    // Group modules by category
    final Map<String, List<AppModule>> groupedModules = {};
    for (var module in permittedModules) {
      groupedModules.putIfAbsent(module.categoryKey, () => []).add(module);
    }

    // Define category order
    final categoryOrder = [
      'main.xin_dashboard',
      'side_drawer.work',
      'side_drawer.financial',
      'side_drawer.support',
    ];

    return Scaffold(
      appBar: SecondaryAppBar(
        title: _isEditing
            ? 'dashboard.quick_menu'.tr(context)
            : 'dashboard.quick_menu'.tr(context),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => _startEditing(quickMenuProvider.pinnedKeys),
              tooltip: 'dashboard.edit'.tr(context),
            )
          else ...[
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: Text(
                'main.xin_cancel'.tr(context),
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                quickMenuProvider.setPinnedKeys(_tempPinnedKeys);
                quickMenuProvider.save();
                setState(() => _isEditing = false);
              },
              child: Text(
                'main.save'.tr(context),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'dashboard.edit_quick_menu_info'.tr(context),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _tempPinnedKeys = [];
                        });
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        'dashboard.reset'.tr(context),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...categoryOrder.map((catKey) {
            final modules = groupedModules[catKey];
            if (modules == null || modules.isEmpty) return const SizedBox();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        catKey.tr(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 0,
                        mainAxisSpacing: 0,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        return _buildMenuTile(
                          context,
                          modules[index],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    AppModule m,
  ) {
    final pinnedIndex = _isEditing ? _tempPinnedKeys!.indexOf(m.titleKey) : -1;
    final isPinned = _isEditing
        ? pinnedIndex != -1
        : Provider.of<QuickMenuProvider>(context, listen: false)
            .isPinned(m.titleKey);

    final bool isMaxReached =
        _isEditing && !isPinned && _tempPinnedKeys!.length >= 5;

    return Opacity(
      opacity: isMaxReached ? 0.3 : 1.0,
      child: InkWell(
        onTap: () {
          if (_isEditing) {
            _togglePinned(m.titleKey);
          } else {
            if (m.tabTag != null) {
              DashboardPage.switchTab(m.tabTag!);
              Navigator.pop(context);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => m.pageBuilder(context, widget.userData),
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isEditing && isPinned
                            ? m.color.withValues(alpha: 0.2)
                            : m.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: _isEditing && isPinned
                            ? Border.all(color: m.color, width: 2)
                            : null,
                      ),
                      child: Icon(
                        m.icon,
                        color: m.color,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m.titleKey.tr(context),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          _isEditing && isPinned ? FontWeight.w900 : FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (_isEditing && isPinned)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${pinnedIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else if (_isEditing && !isMaxReached)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 14,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
