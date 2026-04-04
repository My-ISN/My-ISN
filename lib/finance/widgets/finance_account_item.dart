import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class FinanceAccountItem extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback? onTap;

  const FinanceAccountItem({super.key, required this.account, this.onTap});

  String _formatCurrency(dynamic amount) {
    if (amount == null) return "0";
    double val = double.tryParse(amount.toString()) ?? 0;

    // If it's a whole number, don't show decimals
    if (val == val.toInt()) {
      String formatted = val.toInt().toString();
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return formatted.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    }

    // Otherwise show 2 decimals with comma
    String formatted = val.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    integerPart = integerPart.replaceAllMapped(
      reg,
      (Match match) => '${match[1]}.',
    );
    return "$integerPart,$decimalPart";
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = _formatCurrency(account['account_balance']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF7E57C2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['account_name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${account['bank'] ?? '-'} • ${account['account_number'] ?? '-'}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'finance.current_balance'.tr(context),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Rp $currencyFormat',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
