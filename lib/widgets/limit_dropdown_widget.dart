import 'package:flutter/material.dart';

class LimitDropdown extends StatelessWidget {
  final int value;
  final List<int> options;
  final ValueChanged<int?> onChanged;
  final Color? activeColor;
  final String? label;

  const LimitDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.activeColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = activeColor ?? const Color(0xFF7E57C2);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(21), // Perfect pill shape
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          icon: Padding(
            padding: const EdgeInsets.only(left: 1),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: color,
            ),
          ),
          dropdownColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          onChanged: onChanged,
          items: options.map<DropdownMenuItem<int>>((int val) {
            return DropdownMenuItem<int>(
              value: val,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  val.toString(),
                  style: TextStyle(
                    color: val == value
                        ? color
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: val == value
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
          selectedItemBuilder: (BuildContext context) {
            return options.map<Widget>((int val) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null) ...[
                    Text(
                      label!,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      height: 14,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),
                  ],
                  Text(
                    val.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
