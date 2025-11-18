import 'package:flutter/material.dart';

/// Application color configuration - professional color scheme designed for medical applications
class AppColors {
  // Primary color - medical blue
  static const Color primary = Color(0xFF1976D2); // Professional medical blue
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD3E3FD);
  static const Color onPrimaryContainer = Color(0xFF001C38);

  // Secondary color - tech green
  static const Color secondary = Color(0xFF2E7D57); // Health green
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFB8F2D1);
  static const Color onSecondaryContainer = Color(0xFF002114);

  // Tertiary color - warning orange
  static const Color tertiary = Color(0xFFFF8F00); // Monitoring warning color
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFE0B2);
  static const Color onTertiaryContainer = Color(0xFF2D1600);

  // Error color - medical red
  static const Color error = Color(0xFFD32F2F); // Emergency/danger red
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  // Warning color
  static const Color warning = Color(0xFFF57C00); // Warning orange
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFFE0B2);
  static const Color onWarningContainer = Color(0xFF2D1600);

  // Success color
  static const Color success = Color(0xFF388E3C); // Success green
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFC8E6C9);
  static const Color onSuccessContainer = Color(0xFF1B5E20);

  // Info color
  static const Color info = Color(0xFF0288D1); // Info blue
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFB3E5FC);
  static const Color onInfoContainer = Color(0xFF01579B);

  // Light theme surface colors - optimized for brighter color scheme
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF2D3748);
  static const Color lightOnSurfaceVariant = Color(0xFF4A5568);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightOnBackground = Color(0xFF2D3748);
  static const Color lightSurfaceVariant = Color(0xFFE7E0EC);
  static const Color lightInverseSurface = Color(0xFF313033);
  static const Color lightInverseOnSurface = Color(0xFFF4EFF4);
  static const Color lightInversePrimary = Color(0xFFBAC3FF);
  static const Color lightShadow = Color(0xFF000000);
  static const Color lightScrim = Color(0xFF000000);
  static const Color lightOutline = Color(0xFF79747E);
  static const Color lightOutlineVariant = Color(0xFFCAC4D0);
  static const Color lightDivider = Color(0xFFE0E0E0);

  // Dark theme surface colors
  static const Color darkSurface = Color(0xFF141218);
  static const Color darkOnSurface = Color(0xFFE6E1E5);
  static const Color darkOnSurfaceVariant = Color(0xFFCAC4D0);
  static const Color darkBackground = Color(0xFF101014);
  static const Color darkOnBackground = Color(0xFFE6E1E5);
  static const Color darkSurfaceVariant = Color(0xFF49454F);
  static const Color darkInverseSurface = Color(0xFFE6E1E5);
  static const Color darkInverseOnSurface = Color(0xFF313033);
  static const Color darkInversePrimary = Color(0xFF1976D2);
  static const Color darkShadow = Color(0xFF000000);
  static const Color darkScrim = Color(0xFF000000);
  static const Color darkOutline = Color(0xFF938F99);
  static const Color darkOutlineVariant = Color(0xFF49454F);
  static const Color darkDivider = Color(0xFF2C2C2C);

  // Universal system colors
  static const Color outline = Color(0xFF79747E);
  static const Color shadow = Color(0xFF000000);
  static const Color surfaceTint = primary;
  static const Color inverseSurface = Color(0xFF313033);
  static const Color inverseOnSurface = Color(0xFFF4EFF4);
  static const Color inversePrimary = Color(0xFFBAC3FF);
  static const Color onSurfaceVariant = Color(0xFF49454F);

  // Colors dedicated to medical data visualization
  static const List<Color> chartColors = [
    Color(0xFF1976D2), // Primary blue
    Color(0xFF2E7D57), // Green
    Color(0xFFFF8F00), // Orange
    Color(0xFF7B1FA2), // Purple
    Color(0xFFD32F2F), // Red
    Color(0xFF388E3C), // Dark green
    Color(0xFF1976D2), // Dark blue
    Color(0xFF795548), // Brown
  ];

  // Tremor level colors
  static const Color lowTremor = Color(0xFF4CAF50); // Low level - green
  static const Color mediumTremor = Color(0xFFFF9800); // Medium level - orange
  static const Color highTremor = Color(0xFFF44336); // High level - red
  static const Color criticalTremor = Color(0xFF9C27B0); // Critical level - purple

  // Patient status colors
  static const Color stablePatient = Color(0xFF4CAF50); // Stable - green
  static const Color monitoringPatient = Color(0xFF2196F3); // Monitoring - blue
  static const Color warningPatient = Color(0xFFFF9800); // Warning - orange
  static const Color criticalPatient = Color(0xFFF44336); // Critical - red
  static const Color inactivePatient = Color(0xFF9E9E9E); // Inactive - gray

  // Data quality indicator colors
  static const Color excellentData = Color(0xFF4CAF50); // Excellent data quality
  static const Color goodData = Color(0xFF8BC34A); // Good data quality
  static const Color fairData = Color(0xFFFF9800); // Fair data quality
  static const Color poorData = Color(0xFFF44336); // Poor data quality
  static const Color noData = Color(0xFF9E9E9E); // No data

  // Gradient color combinations
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFF44336), Color(0xFFD32F2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Background gradients
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFFFFBFE), Color(0xFFF5F5F5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF101014), Color(0xFF1A1A1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Text colors
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textDisabled = Color(0xFFA0AEC0);
  
  // Divider colors
  static const Color divider = Color(0xFFE2E8F0);
  
  // Primary variant
  static const Color darkPrimary = Color(0xFF1565C0);

  // Opacity variants
  static Color get primaryWithOpacity => primary.withValues(alpha: 0.12);
  static Color get secondaryWithOpacity => secondary.withValues(alpha: 0.12);
  static Color get errorWithOpacity => error.withValues(alpha: 0.12);
  static Color get warningWithOpacity => warning.withValues(alpha: 0.12);
  static Color get successWithOpacity => success.withValues(alpha: 0.12);

  // Medical level color mapping
  static Color getTremorLevelColor(double tremorLevel) {
    if (tremorLevel < 40) return lowTremor;
    if (tremorLevel < 70) return mediumTremor;
    if (tremorLevel < 90) return highTremor;
    return criticalTremor;
  }

  // Patient status color mapping
  static Color getPatientStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'stable':
        return stablePatient;
      case 'monitoring':
        return monitoringPatient;
      case 'warning':
        return warningPatient;
      case 'critical':
        return criticalPatient;
      case 'inactive':
        return inactivePatient;
      default:
        return monitoringPatient;
    }
  }

  // Data quality color mapping
  static Color getDataQualityColor(double quality) {
    if (quality >= 0.9) return excellentData;
    if (quality >= 0.7) return goodData;
    if (quality >= 0.5) return fairData;
    if (quality > 0) return poorData;
    return noData;
  }
}
