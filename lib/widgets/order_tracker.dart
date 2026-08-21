import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Visual live order tracking with orange route progress line.
class OrderTracker extends StatelessWidget {
  const OrderTracker({
    super.key,
    required this.status,
    this.statusLabel,
  });

  final String status;
  final String? statusLabel;

  static const _steps = [
  ('pending', Icons.receipt_long_outlined, 'طلب'),
  ('confirmed', Icons.check_circle_outline, 'تأكيد'),
  ('preparing', Icons.restaurant_outlined, 'تحضير'),
  ('on_the_way', Icons.delivery_dining_outlined, 'في الطريق'),
  ('delivered', Icons.home_outlined, 'تسليم'),
  ];

  int _activeIndex(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('deliver') || lower.contains('complete')) return 4;
    if (lower.contains('way') || lower.contains('ship') || lower.contains('out')) {
      return 3;
    }
    if (lower.contains('prepar') || lower.contains('process')) return 2;
    if (lower.contains('confirm') || lower.contains('accept')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex(status);
  final progress = active / (_steps.length - 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: AppTheme.accentOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel ?? status,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Route progress line
          LayoutBuilder(
            builder: (context, constraints) {
              final lineWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background track
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Active orange progress
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 4,
                    width: lineWidth * progress,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentOrange.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  // Step dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_steps.length, (i) {
                      final done = i <= active;
                      final current = i == active;
                      return Column(
                        children: [
                          const SizedBox(height: -10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: current ? 28 : 22,
                            height: current ? 28 : 22,
                            decoration: BoxDecoration(
                              color: done
                                  ? AppTheme.accentOrange
                                  : AppTheme.surfaceGrey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: done
                                    ? AppTheme.accentOrange
                                    : AppTheme.primaryNavy
                                        .withValues(alpha: 0.2),
                                width: 2,
                              ),
                              boxShadow: current
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.accentOrange
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              _steps[i].$2,
                              size: current ? 14 : 11,
                              color: done
                                  ? AppTheme.backgroundWhite
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _steps[i].$3,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  current ? FontWeight.w700 : FontWeight.w400,
                              color: done
                                  ? AppTheme.accentOrange
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
