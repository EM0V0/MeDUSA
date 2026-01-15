import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/app_constants.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightOnSurface,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurfaceVariant: AppColors.lightOnSurfaceVariant,
        outline: AppColors.lightOutline,
        outlineVariant: AppColors.lightOutlineVariant,
        shadow: AppColors.lightShadow,
        scrim: AppColors.lightScrim,
        inverseSurface: AppColors.lightInverseSurface,
        onInverseSurface: AppColors.lightInverseOnSurface,
        inversePrimary: AppColors.lightInversePrimary,
        surfaceTint: AppColors.surfaceTint,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,

      // Global font size control - using new layered font protection system
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: AppConstants.baseMinTitleFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          fontSize: AppConstants.baseMinTitleFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          fontSize: AppConstants.baseMinTitleFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: TextStyle(
          fontSize: AppConstants.baseMinTitleFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontSize: AppConstants.baseMinTitleFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontSize: AppConstants.baseMinTitleFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          fontSize: AppConstants.baseMinCaptionFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          fontSize: AppConstants.baseMinCaptionFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          fontSize: AppConstants.baseMinCaptionFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w400,
        ),
      ),

      // Component themes
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        centerTitle: false,
  titleTextStyle: TextStyle(
          fontSize: AppConstants.baseMinTitleFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.bold,
          color: AppColors.onPrimary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          textStyle: const TextStyle(
            fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          textStyle: const TextStyle(
            fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          textStyle: const TextStyle(
            fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.error),
        ),
  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        labelStyle: const TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          color: AppColors.onSurfaceVariant,
        ),
        hintStyle: const TextStyle(
          fontSize: AppConstants.baseMinBodyFontSize,  // Fixed: use new constant name
          color: AppColors.onSurfaceVariant,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
  selectedLabelStyle: TextStyle(
          fontSize: AppConstants.baseMinCaptionFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w600,
        ),
  unselectedLabelStyle: TextStyle(
          fontSize: AppConstants.baseMinCaptionFontSize,  // Fixed: use new constant name
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
