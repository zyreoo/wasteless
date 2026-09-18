import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FoodItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const FoodItemCard({super.key, required this.item, this.onTap});

  Color get _statusColor {
    switch (item['status']) {
      case 'danger':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  Color get _statusBg {
    switch (item['status']) {
      case 'danger':
        return AppColors.tagRed;
      case 'warning':
        return AppColors.tagYellow;
      default:
        return AppColors.tagGreen;
    }
  }

  Color get _statusTextColor {
    switch (item['status']) {
      case 'danger':
        return AppColors.tagRedText;
      case 'warning':
        return AppColors.tagYellowText;
      default:
        return AppColors.tagGreenText;
    }
  }

  String get _daysLabel {
    final d = item['daysLeft'] as int;
    if (d == 1) return 'Expires tomorrow';
    if (d <= 0) return 'Expired';
    return 'Expires in $d days';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Emoji / icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    item['emoji'] ?? '🍽️',
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['category'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _daysLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quantity + actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item['quantity'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
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
