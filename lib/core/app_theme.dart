import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Saree Market (سريع ماركت) brand design tokens.
abstract final class AppTheme {
  static const primaryNavy = Color(0xFF0A2540);
  static const accentOrange = Color(0xFFFF6B00);
  static const backgroundWhite = Color(0xFFFFFFFF);
  static const surfaceGrey = Color(0xFFF3F4F6);
  static const textPrimary = Color(0xFF0A2540);
  static const textSecondary = Color(0xFF6B7280);

  static const brandNameAr = 'سريع ماركت';
  static const brandNameEn = 'Saree Market';

  static TextTheme _textTheme(Locale locale) {
    final base = locale.languageCode == 'ar'
        ? GoogleFonts.notoSansArabicTextTheme()
        : GoogleFonts.interTextTheme();
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: textPrimary),
      bodyMedium: base.bodyMedium?.copyWith(color: textPrimary),
      bodySmall: base.bodySmall?.copyWith(color: textSecondary),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static ThemeData build({required Locale locale}) {
    final textTheme = _textTheme(locale);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primaryNavy,
        onPrimary: backgroundWhite,
        secondary: accentOrange,
        onSecondary: backgroundWhite,
        surface: backgroundWhite,
        onSurface: textPrimary,
        error: const Color(0xFFDC2626),
        onError: backgroundWhite,
      ),
      scaffoldBackgroundColor: surfaceGrey,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: backgroundWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: backgroundWhite,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: backgroundWhite),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundWhite,
        indicatorColor: accentOrange.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? accentOrange : textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentOrange);
          }
          return const IconThemeData(color: textSecondary);
        }),
      ),
      cardTheme: CardThemeData(
        color: backgroundWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: primaryNavy.withValues(alpha: 0.08),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentOrange,
          foregroundColor: backgroundWhite,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(color: backgroundWhite),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          foregroundColor: backgroundWhite,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: surfaceGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryNavy.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentOrange, width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      chipTheme: ChipThemeData(
        selectedColor: accentOrange.withValues(alpha: 0.15),
        labelStyle: textTheme.bodySmall,
        side: BorderSide(color: primaryNavy.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: accentOrange,
        textColor: backgroundWhite,
      ),
      dividerTheme: DividerThemeData(
        color: primaryNavy.withValues(alpha: 0.08),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryNavy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: backgroundWhite,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentOrange,
        linearTrackColor: primaryNavy.withValues(alpha: 0.1),
      ),
    );
  }

  /// Horizontal slide-in page transition.
  static CustomTransitionPage<T> slidePage<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }
}

/// Branded filled button with orange ripple effect.
class BrandedButton extends StatelessWidget {
  const BrandedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.expanded = true,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool expanded;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: onPressed == null || busy
          ? AppTheme.accentOrange.withValues(alpha: 0.5)
          : AppTheme.accentOrange,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        splashColor: AppTheme.backgroundWhite.withValues(alpha: 0.2),
        highlightColor: AppTheme.backgroundWhite.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.backgroundWhite,
                  ),
                )
              else if (icon != null) ...[
                Icon(icon, color: AppTheme.backgroundWhite, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.backgroundWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (expanded) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}
