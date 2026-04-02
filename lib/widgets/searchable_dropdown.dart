import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class SearchableDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<Map<String, String>> options;
  final Function(String) onSelected;
  final IconData? icon;
  final bool required;
  final String? placeholder;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.icon,
    this.required = true,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => _showSearchOptions(context),
      child: IgnorePointer(
        child: TextFormField(
          controller: TextEditingController(text: value),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            prefixIcon: Icon(icon ?? Icons.search_rounded, size: 18, color: const Color(0xFF7E57C2)),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF7E57C2)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 2)),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: required ? (val) => (value.isEmpty) ? ('main.required'.tr(context)) : null : null,
        ),
      ),
    );
  }

  void _showSearchOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchPickerModal(
        title: label,
        options: options,
        onSelected: onSelected,
        placeholder: placeholder,
      ),
    );
  }
}

class _SearchPickerModal extends StatefulWidget {
  final String title;
  final List<Map<String, String>> options;
  final Function(String) onSelected;
  final String? placeholder;

  const _SearchPickerModal({
    required this.title,
    required this.options,
    required this.onSelected,
    this.placeholder,
  });

  @override
  State<_SearchPickerModal> createState() => _SearchPickerModalState();
}

class _SearchPickerModalState extends State<_SearchPickerModal> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((opt) => opt['name']!.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF7E57C2), size: 28),
                const SizedBox(width: 12),
                Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: widget.placeholder ?? 'Search...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final opt = filtered[index];
                return ListTile(
                  title: Text(opt['name']!, style: const TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                  onTap: () {
                    widget.onSelected(opt['id']!);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
