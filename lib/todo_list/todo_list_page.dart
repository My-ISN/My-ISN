import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';


class TodoListPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Color _primaryColor = const Color(0xFF7E57C2);

  const TodoListPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: userData, showBackButton: true),
      endDrawer: SideDrawer(userData: userData, activePage: 'todo_list'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildHeaderCard(context),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tugas Hari Ini',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTodoItem(
                    context,
                    title: 'Review proposal proyek',
                    time: '09:00 AM',
                    isCompleted: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTodoItem(
                    context,
                    title: 'Meeting dengan tim UI/UX',
                    time: '11:00 AM',
                    isCompleted: false,
                  ),
                  const SizedBox(height: 12),
                  _buildTodoItem(
                    context,
                    title: 'Update dokumentasi API',
                    time: '02:00 PM',
                    isCompleted: false,
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.history, size: 20),
                      label: const Text('Lihat Semua Riwayat'),
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add_task, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMiniInfo(context, 'Total', '24'),
          _buildMiniInfo(context, 'Selesai', '18'),
          _buildMiniInfo(context, 'Tertunda', '6'),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTodoItem(
    BuildContext context, {
    required String title,
    required String time,
    required bool isCompleted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.more_horiz, size: 20, color: Colors.grey[400]),
        ],
      ),
    );
  }
}


