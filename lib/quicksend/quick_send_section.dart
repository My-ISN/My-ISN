import 'package:flutter/material.dart';
import '../services/quick_send_service.dart';
import 'quick_send_card.dart';
import 'quick_send_modal.dart';

class QuickSendSection extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const QuickSendSection({super.key, this.userData});

  @override
  State<QuickSendSection> createState() => QuickSendSectionState();
}

class QuickSendSectionState extends State<QuickSendSection> {
  final QuickSendService _service = QuickSendService();
  List _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => _isLoading = true);
    final res = await _service.getQuickSendData();
    if (mounted) {
      setState(() {
        if (res['status'] == true) {
          _contacts = res['data'] ?? [];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _contacts.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading && _contacts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          const SizedBox(height: 16),
          _isLoading
              ? _buildShimmer()
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    return QuickSendCard(
                      contact: _contacts[index],
                      onTap: () => _openModal(_contacts[index]),
                    );
                  },
                ),
        ],
      ],
    );
  }

  void _openModal(Map<String, dynamic> contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickSendModal(
        contact: contact,
        userData: widget.userData,
      ),
    );
  }

  Widget _buildShimmer() {
    return Row(
      children: [
        Expanded(child: _buildShimmerBox()),
        const SizedBox(width: 16),
        Expanded(child: _buildShimmerBox()),
      ],
    );
  }

  Widget _buildShimmerBox() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
