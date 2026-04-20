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
  final bool enabled;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.icon,
    this.required = true,
    this.placeholder,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: enabled
          ? () {
              FocusScope.of(context).unfocus();
              _showSearchOptions(context);
            }
          : null,
      borderRadius: BorderRadius.circular(20),
      child: IgnorePointer(
        child: TextFormField(
          controller: TextEditingController(text: value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled
                ? null
                : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon ?? Icons.search_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: enabled ? 0.6 : 0.3),
            ),
            suffixIcon: enabled
                ? Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark 
                ? Colors.white.withValues(alpha: 0.03) 
                : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
          ),
          validator: required
              ? (val) => (value.isEmpty) ? ('main.required'.tr(context)) : null
              : null,
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
        .where(
          (opt) =>
              opt['name']!.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: widget.placeholder ?? 'Search...',
                hintStyle: TextStyle(color: Theme.of(context).hintColor.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                  title: Text(
                    opt['name']!,
                    style: const TextStyle(fontSize: 15),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
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
