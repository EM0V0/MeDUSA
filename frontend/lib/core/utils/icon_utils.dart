import 'package:flutter/material.dart';

import 'package:responsive_framework/responsive_framework.dart';

import '../constants/app_constants.dart';

/// Icon size type enum
enum IconSizeType {
  small,      // Small icon
  medium,     // Medium icon
  large,      // Large icon
  xlarge,     // Extra large icon
  xxlarge,    // Extra extra large icon
}

/// Icon purpose enum
enum IconPurpose {
  button,     // Button icon
  navigation, // Navigation icon
  action,     // Action icon
  status,     // Status icon
  menu,       // Menu icon
  card,       // Card icon
  stat,       // Statistics icon
  emptyState, // Empty state icon
  input,      // Input field icon
  visibility, // Visibility icon
}

/// Icon utility class - Refactored to eliminate duplicate code, providing a unified responsive icon system
class IconUtils {
  // ===== Responsive Icon Size Retrieval =====
  
  /// Get responsive icon size
  static double getResponsiveIconSize(IconSizeType sizeType, BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);
    final isTablet = ResponsiveBreakpoints.of(context).smallerThan(DESKTOP) && 
                     ResponsiveBreakpoints.of(context).largerThan(TABLET);
    
    double baseSize;
    switch (sizeType) {
      case IconSizeType.small:
        baseSize = AppConstants.iconSizeSmall;
        break;
      case IconSizeType.medium:
        baseSize = AppConstants.iconSizeMedium;
        break;
      case IconSizeType.large:
        baseSize = AppConstants.iconSizeLarge;
        break;
      case IconSizeType.xlarge:
        baseSize = AppConstants.iconSizeXLarge;
        break;
      case IconSizeType.xxlarge:
        baseSize = AppConstants.iconSizeXXLarge;
        break;
    }
    
    // Apply minimum size protection and mobile enhancement
    double finalSize;
    if (isMobile) {
      finalSize = baseSize * 1.2; // Increased from 1.1 to 1.2 for better visibility
      // Apply mobile minimum size protection
      if (finalSize < AppConstants.mobileMinIconSize) {
        finalSize = AppConstants.mobileMinIconSize;
      }
    } else if (isTablet) {
      finalSize = baseSize * 1.1; // Increased from 1.05 to 1.1
    } else {
      finalSize = baseSize;
    }
    
    // Critical: Absolute minimum size protection for all devices
    // Prevent icons from becoming invisible on very narrow screens
    double absoluteMinSize;
    switch (sizeType) {
      case IconSizeType.small:
        absoluteMinSize = 16.0;
        break;
      case IconSizeType.medium:
        absoluteMinSize = 20.0;
        break;
      case IconSizeType.large:
        absoluteMinSize = 24.0;
        break;
      case IconSizeType.xlarge:
        absoluteMinSize = 28.0;
        break;
      case IconSizeType.xxlarge:
        absoluteMinSize = 32.0;
        break;
    }
    
    return finalSize < absoluteMinSize ? absoluteMinSize : finalSize;
  }
  
  /// Get icon size based on purpose
  static double getIconSizeByPurpose(IconPurpose purpose, BuildContext context) {
    switch (purpose) {
      case IconPurpose.button:
        return getResponsiveIconSize(IconSizeType.medium, context);
      case IconPurpose.navigation:
        return getResponsiveIconSize(IconSizeType.medium, context);
      case IconPurpose.action:
        return getResponsiveIconSize(IconSizeType.medium, context);
      case IconPurpose.status:
        return getResponsiveIconSize(IconSizeType.small, context);
      case IconPurpose.menu:
        return getResponsiveIconSize(IconSizeType.medium, context);
      case IconPurpose.card:
        return getResponsiveIconSize(IconSizeType.medium, context);
      case IconPurpose.stat:
        return getResponsiveIconSize(IconSizeType.large, context);
      case IconPurpose.emptyState:
        return getResponsiveIconSize(IconSizeType.xxlarge, context);
      case IconPurpose.input:
        return getResponsiveIconSize(IconSizeType.medium, context);
      case IconPurpose.visibility:
        return getResponsiveIconSize(IconSizeType.medium, context);
    }
  }
  
  /// Get status indicator size (for badges, online dots, etc.)
  static double getStatusIndicatorSize(BuildContext context, {bool isLarge = false}) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);
    
    double baseSize = isLarge 
        ? AppConstants.statusIndicatorLarge 
        : AppConstants.statusIndicatorMedium;
    
    if (isMobile) {
      // Ensure minimum size for mobile touch targets
      double mobileSize = baseSize * 1.2;
      return mobileSize < AppConstants.mobileStatusIndicatorMin 
          ? AppConstants.mobileStatusIndicatorMin 
          : mobileSize;
    }
    
    return baseSize;
  }
  
  /// Get avatar size with minimum protection (for user avatars, profile pictures)
  static double getAvatarSize(BuildContext context, {
    double? desktopSize,
    double? mobileSize,
    double? minSize,
  }) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);
    
    // Default sizes if not specified
    final defaultDesktopSize = desktopSize ?? 48.0;
    final defaultMobileSize = mobileSize ?? 56.0;
    final defaultMinSize = minSize ?? 32.0; // Absolute minimum for avatars
    
    double targetSize = isMobile ? defaultMobileSize : defaultDesktopSize;
    
    // Apply ScreenUtil scaling but with minimum protection
    double scaledSize = targetSize;
    
    // Critical: Never let avatars become smaller than minimum readable size
    return scaledSize < defaultMinSize ? defaultMinSize : scaledSize;
  }
  
  /// Get protected size for any UI element (universal protection)
  static double getProtectedSize(BuildContext context, {
    required double targetSize,
    required double minSize,
    bool useScreenUtil = false, // Changed default to false for safety
  }) {
    double finalSize = targetSize;
    
    // Apply ScreenUtil if explicitly requested (but with caution)
    if (useScreenUtil) {
      final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);
      // Apply scaling more conservatively
      finalSize = isMobile ? targetSize * 0.9 : targetSize;
    }
    
    // Apply minimum protection - this is the key safeguard
    return finalSize < minSize ? minSize : finalSize;
  }
  
  /// Get protected height for containers and charts
  static double getProtectedHeight(BuildContext context, {
    required double targetHeight,
    required double minHeight,
    bool useScreenUtil = false, // Changed default to false for safety
  }) {
    double finalHeight = targetHeight;
    
    // Apply ScreenUtil if explicitly requested (but with caution)
    if (useScreenUtil) {
      final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);
      // Apply scaling more conservatively  
      finalHeight = isMobile ? targetHeight * 0.9 : targetHeight;
    }
    
    // Apply minimum protection - never smaller than minHeight
    return finalHeight < minHeight ? minHeight : finalHeight;
  }

  // ===== Responsive Icon Creation =====
  
  /// Create responsive icon
  static Widget responsiveIcon(
    IconData icon, {
    required BuildContext context,
    IconSizeType? sizeType,
    IconPurpose? purpose,
    Color? color,
    double? size,
  }) {
    double finalSize;
    if (size != null) {
      finalSize = size;
    } else if (sizeType != null) {
      finalSize = getResponsiveIconSize(sizeType, context);
    } else if (purpose != null) {
      finalSize = getIconSizeByPurpose(purpose, context);
    } else {
      finalSize = getResponsiveIconSize(IconSizeType.medium, context);
    }
    
    return Icon(
      icon,
      size: finalSize,
      color: color,
    );
  }
  
  /// Create responsive small icon
  static Widget responsiveSmallIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      sizeType: IconSizeType.small,
      color: color,
    );
  }
  
  /// Create responsive medium icon
  static Widget responsiveMediumIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      sizeType: IconSizeType.medium,
      color: color,
    );
  }
  
  /// Create responsive large icon
  static Widget responsiveLargeIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      sizeType: IconSizeType.large,
      color: color,
    );
  }
  
  /// Create responsive extra large icon
  static Widget responsiveXLargeIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      sizeType: IconSizeType.xlarge,
      color: color,
    );
  }
  
  /// Create responsive extra extra large icon
  static Widget responsiveXXLargeIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      sizeType: IconSizeType.xxlarge,
      color: color,
    );
  }

  // ===== Purpose-Specific Icon Creation =====
  
  /// Create button icon
  static Widget buttonIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.button,
      color: color,
    );
  }
  
  /// Create navigation icon
  static Widget navigationIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.navigation,
      color: color,
    );
  }
  
  /// Create action icon
  static Widget actionIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.action,
      color: color,
    );
  }
  
  /// Create status icon
  static Widget statusIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.status,
      color: color,
    );
  }
  
  /// Create menu icon
  static Widget menuIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.menu,
      color: color,
    );
  }
  
  /// Create card icon
  static Widget cardIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.card,
      color: color,
    );
  }
  
  /// Create statistics icon
  static Widget statIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.stat,
      color: color,
    );
  }
  
  /// Create empty state icon
  static Widget emptyStateIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.emptyState,
      color: color,
    );
  }
  
  /// Create input field icon
  static Widget inputIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.input,
      color: color,
    );
  }
  
  /// Create visibility icon
  static Widget visibilityIcon(
    IconData icon, {
    required BuildContext context,
    Color? color,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      purpose: IconPurpose.visibility,
      color: color,
    );
  }

  // ===== Compatibility Methods (Maintain Backward Compatibility) =====
  
  /// Ensure icon size is not smaller than minimum value (compatibility method)
  @Deprecated('Use getResponsiveIconSize instead')
  static double ensureMinIconSize(double iconSize) {
    return iconSize < AppConstants.minIconSize ? AppConstants.minIconSize : iconSize;
  }

  /// Mobile icon size control (compatibility method)
  @Deprecated('Use getResponsiveIconSize instead')
  static double getMobileIconSize(double iconSize, BuildContext context) {
    return getResponsiveIconSize(IconSizeType.medium, context);
  }
  
  /// Global forced icon size control (compatibility method)
  @Deprecated('Use getResponsiveIconSize instead')
  static double globalForceIconSize(double iconSize) {
    return iconSize < AppConstants.mobileMinIconSize ? AppConstants.mobileMinIconSize : iconSize;
  }

  /// Create responsive icon size (compatibility method)
  @Deprecated('Use getResponsiveIconSize instead')
  static double responsiveIconSize(double iconSize, BuildContext context) {
    return getResponsiveIconSize(IconSizeType.medium, context);
  }

  /// Compatibility method: Get responsive icon size from double value
  @Deprecated('Use getResponsiveIconSize with IconSizeType instead')
  static double getResponsiveIconSizeFromDouble(double iconSize, BuildContext context) {
    // Map icon size to corresponding IconSizeType
    IconSizeType sizeType;
    if (iconSize <= 16) {
      sizeType = IconSizeType.small;
    } else if (iconSize <= 24) {
      sizeType = IconSizeType.medium;
    } else if (iconSize <= 32) {
      sizeType = IconSizeType.large;
    } else if (iconSize <= 48) {
      sizeType = IconSizeType.xlarge;
    } else {
      sizeType = IconSizeType.xxlarge;
    }
    return getResponsiveIconSize(sizeType, context);
  }

  // ===== Legacy Convenience Methods (Maintain Backward Compatibility) =====
  
  /// Convenience method: Create protected Icon component (compatibility method)
  @Deprecated('Use responsiveIcon instead')
  static Widget protectedIcon(
    IconData icon, {
    required double size,
    Color? color,
    required BuildContext context,
  }) {
    return responsiveIcon(
      icon,
      context: context,
      size: size,
      color: color,
    );
  }

  /// Convenience method: Create protected small icon (compatibility method)
  @Deprecated('Use responsiveSmallIcon instead')
  static Widget protectedSmallIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return responsiveSmallIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected medium icon (compatibility method)
  @Deprecated('Use responsiveMediumIcon instead')
  static Widget protectedMediumIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return responsiveMediumIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected large icon (compatibility method)
  @Deprecated('Use responsiveLargeIcon instead')
  static Widget protectedLargeIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return responsiveLargeIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected extra large icon (compatibility method)
  @Deprecated('Use responsiveXLargeIcon instead')
  static Widget protectedExtraLargeIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return responsiveXLargeIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected button icon (compatibility method)
  @Deprecated('Use buttonIcon instead')
  static Widget protectedButtonIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return buttonIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected navigation icon (compatibility method)
  @Deprecated('Use navigationIcon instead')
  static Widget protectedNavigationIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return navigationIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected action icon (compatibility method)
  @Deprecated('Use actionIcon instead')
  static Widget protectedActionIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return actionIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected status icon (compatibility method)
  @Deprecated('Use statusIcon instead')
  static Widget protectedStatusIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return statusIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected menu icon (compatibility method)
  @Deprecated('Use menuIcon instead')
  static Widget protectedMenuIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return menuIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected card icon (compatibility method)
  @Deprecated('Use cardIcon instead')
  static Widget protectedCardIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return cardIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected statistics icon (compatibility method)
  @Deprecated('Use statIcon instead')
  static Widget protectedStatIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return statIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected empty state icon (compatibility method)
  @Deprecated('Use emptyStateIcon instead')
  static Widget protectedEmptyStateIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return emptyStateIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected input field icon (compatibility method)
  @Deprecated('Use inputIcon instead')
  static Widget protectedInputIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return inputIcon(
      icon,
      context: context,
      color: color,
    );
  }

  /// Convenience method: Create protected visibility icon (compatibility method)
  @Deprecated('Use visibilityIcon instead')
  static Widget protectedVisibilityIcon(
    IconData icon, {
    Color? color,
    required BuildContext context,
  }) {
    return visibilityIcon(
      icon,
      context: context,
      color: color,
    );
  }
}
