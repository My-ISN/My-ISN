import 'package:flutter/material.dart';

class FinanceTransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onTap;

  const FinanceTransactionItem({super.key, required this.transaction, this.onTap});

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
    integerPart = integerPart.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    return "$integerPart,$decimalPart";
  }

  @override
  Widget build(BuildContext context) {
    bool isIncome = transaction['transaction_type'] == 'income';
    Color primaryColor = isIncome ? Colors.green : Colors.red;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isIncome ? Icons.north_east_rounded : Icons.south_west_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payer Name & Category
                    Builder(
                      builder: (context) {
                        final String firstName = transaction['payer_first_name'] ?? '';
                        final String lastName = transaction['payer_last_name'] ?? '';
                        final String fullName = '$firstName $lastName'.trim();
                        final String category = transaction['category_name'] ?? (isIncome ? 'Income' : 'Expense');
                        final String displayText = fullName.isEmpty ? '- $category' : '$fullName - $category';
                        
                        return Text(
                          displayText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction['transaction_date'] ?? '-',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    if (transaction['account_name'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        transaction['account_name'],
                        style: TextStyle(color: Colors.grey[400], fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} Rp ${_formatCurrency(transaction['amount'])}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: primaryColor,
                    ),
                  ),
                  if (transaction['entity_type'] != null && transaction['entity_type'].toString() != '-') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        transaction['entity_type'].toString().toUpperCase(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
