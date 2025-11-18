class AppConstants {
  // App Information
  static const String appName = 'MeDUSA';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Professional medical data fusion and analysis system';

  // ===== Font system refactoring =====
  // Base font size (desktop first)
  static const double _baseFontSize = 16.0;
  
  // Refined typography hierarchy for elegant UI
  static const double _displayRatio = 1.75;    // Display text (main page titles)
  static const double _headlineRatio = 1.375;  // Headlines (section headers) 
  static const double _titleRatio = 1.125;     // Titles (card headers, reduced from 1.5)
  static const double _bodyLargeRatio = 1.0;   // Body large (primary content)
  static const double _bodyRatio = 0.875;      // Body (secondary content, reduced)
  static const double _labelRatio = 0.75;      // Labels (form labels, tags)
  static const double _captionRatio = 0.6875;  // Caption (metadata, timestamps, smaller)
  
  // Desktop font sizes (primary sizes) - refined hierarchy
  static const double desktopDisplayFontSize = _baseFontSize * _displayRatio;      // 28.0
  static const double desktopHeadlineFontSize = _baseFontSize * _headlineRatio;    // 22.0
  static const double desktopTitleFontSize = _baseFontSize * _titleRatio;          // 18.0 (reduced)
  static const double desktopBodyLargeFontSize = _baseFontSize * _bodyLargeRatio;  // 16.0
  static const double desktopBodyFontSize = _baseFontSize * _bodyRatio;            // 14.0 (reduced)
  static const double desktopLabelFontSize = _baseFontSize * _labelRatio;          // 12.0
  static const double desktopCaptionFontSize = _baseFontSize * _captionRatio;      // 11.0 (reduced)
  
  // Mobile font sizes (refined for better readability)
  static const double _mobileScaleFactor = 1.0; // Mobile scale factor - keep same size for readability
  static const double mobileDisplayFontSize = desktopDisplayFontSize * _mobileScaleFactor;      // 28.0
  static const double mobileHeadlineFontSize = desktopHeadlineFontSize * _mobileScaleFactor;    // 22.0
  static const double mobileTitleFontSize = desktopTitleFontSize * _mobileScaleFactor;          // 18.0
  static const double mobileBodyLargeFontSize = desktopBodyLargeFontSize * _mobileScaleFactor;  // 16.0
  static const double mobileBodyFontSize = desktopBodyFontSize * _mobileScaleFactor;            // 14.0
  static const double mobileLabelFontSize = desktopLabelFontSize * _mobileScaleFactor;          // 12.0
  static const double mobileCaptionFontSize = desktopCaptionFontSize * _mobileScaleFactor;      // 11.0
  
  // Tablet font sizes (medium sizes)
  static const double _tabletScaleFactor = 0.95; // Tablet scale factor - slightly smaller than desktop
  static const double tabletDisplayFontSize = desktopDisplayFontSize * _tabletScaleFactor;      // 26.6
  static const double tabletHeadlineFontSize = desktopHeadlineFontSize * _tabletScaleFactor;    // 20.9
  static const double tabletTitleFontSize = desktopTitleFontSize * _tabletScaleFactor;          // 17.1
  static const double tabletBodyLargeFontSize = desktopBodyLargeFontSize * _tabletScaleFactor;  // 15.2
  static const double tabletBodyFontSize = desktopBodyFontSize * _tabletScaleFactor;            // 13.3
  static const double tabletLabelFontSize = desktopLabelFontSize * _tabletScaleFactor;          // 11.4
  static const double tabletCaptionFontSize = desktopCaptionFontSize * _tabletScaleFactor;      // 10.45
  
  // ===== Layered minimum font protection system =====
  
  // Basic readability protection (compliant with WCAG 2.1 AA standards)
  static const double baseMinFontSize = 14.0;           // Base minimum font size
  static const double baseMinTitleFontSize = 18.0;      // Base minimum title font size
  static const double baseMinBodyFontSize = 16.0;       // Base minimum body font size
  static const double baseMinCaptionFontSize = 14.0;    // Base minimum caption font size
  static const double baseMinButtonFontSize = 16.0;     // Base minimum button font size
  
  // Device-specific minimum font protection
  static const double mobileMinFontSize = 16.0;           // Mobile minimum font size (touch-friendly)
  static const double mobileMinTitleFontSize = 22.0;      // Mobile minimum title font size (increased)
  static const double mobileMinBodyFontSize = 16.0;       // Mobile minimum body font size
  static const double mobileMinCaptionFontSize = 15.0;    // Mobile minimum caption font size (increased)
  static const double mobileMinButtonFontSize = 18.0;     // Mobile minimum button font size (touch-friendly)
  
  static const double tabletMinFontSize = 15.0;           // Tablet minimum font size
  static const double tabletMinTitleFontSize = 19.0;      // Tablet minimum title font size
  static const double tabletMinBodyFontSize = 15.0;       // Tablet minimum body font size
  static const double tabletMinCaptionFontSize = 14.0;    // Tablet minimum caption font size
  static const double tabletMinButtonFontSize = 16.0;     // Tablet minimum button font size
  
  static const double desktopMinFontSize = 14.0;           // Desktop minimum font size
  static const double desktopMinTitleFontSize = 18.0;      // Desktop minimum title font size
  static const double desktopMinBodyFontSize = 14.0;       // Desktop minimum body font size
  static const double desktopMinCaptionFontSize = 12.0;    // Desktop minimum caption font size
  static const double desktopMinButtonFontSize = 14.0;     // Desktop minimum button font size
  
  // Accessibility enhanced font sizes
  static const double accessibilityMinFontSize = 18.0;     // Accessibility minimum font size
  static const double accessibilityMinTitleFontSize = 22.0; // Accessibility minimum title font size
  static const double accessibilityMinBodyFontSize = 18.0;  // Accessibility minimum body font size
  static const double accessibilityMinCaptionFontSize = 16.0; // Accessibility minimum caption font size
  static const double accessibilityMinButtonFontSize = 18.0;  // Accessibility minimum button font size
  
  // High contrast mode font sizes
  static const double highContrastMinFontSize = 16.0;      // High contrast minimum font size
  static const double highContrastMinTitleFontSize = 20.0;  // High contrast minimum title font size
  static const double highContrastMinBodyFontSize = 16.0;   // High contrast minimum body font size
  
  // Touch device optimized font sizes
  static const double touchFriendlyMinFontSize = 16.0;     // Touch-friendly minimum font size
  static const double touchFriendlyMinButtonFontSize = 18.0; // Touch-friendly minimum button font size
  
  // High DPI screen font size adjustment factors
  static const double highDpiFontScaleFactor = 1.1;        // High DPI screen font scale factor
  static const double ultraHighDpiFontScaleFactor = 1.2;   // Ultra high DPI screen font scale factor
  
  // User font preference thresholds
  static const double userPreferenceThreshold = 1.2;        // User font preference threshold (1.2x+ considered preference for large font)
  static const double accessibilityModeThreshold = 1.5;     // Accessibility mode threshold (1.5x+ considered need for accessibility support)

  // ===== Spacing system refactoring =====
  // Base spacing unit
  static const double _baseSpacing = 8.0;
  
  // Spacing ratio system
  static const double _smallSpacingRatio = 0.5;    // 0.5x
  static const double _mediumSpacingRatio = 1.0;   // 1.0x
  static const double _largeSpacingRatio = 1.5;    // 1.5x
  static const double _xlargeSpacingRatio = 2.0;   // 2.0x
  static const double _xxlargeSpacingRatio = 3.0;  // 3.0x
  
  // Spacing constants
  static const double spacing = _baseSpacing * _mediumSpacingRatio;      // 8.0
  static const double spacingSmall = _baseSpacing * _smallSpacingRatio;  // 4.0
  static const double spacingMedium = _baseSpacing * _mediumSpacingRatio; // 8.0
  static const double spacingLarge = _baseSpacing * _largeSpacingRatio;  // 12.0
  static const double spacingXLarge = _baseSpacing * _xlargeSpacingRatio; // 16.0
  static const double spacingXXLarge = _baseSpacing * _xxlargeSpacingRatio; // 24.0
  
  // Legacy naming for compatibility
  static const double defaultPadding = spacingXLarge;    // 16.0
  static const double smallPadding = spacingMedium;      // 8.0
  static const double largePadding = spacingXXLarge;     // 24.0

  // ===== Icon system refactoring =====
  // Base icon size
  static const double _baseIconSize = 24.0;
  
  // Icon ratio system
  static const double _smallIconRatio = 0.75;     // 0.75x
  static const double _mediumIconRatio = 1.0;     // 1.0x
  static const double _largeIconRatio = 1.33;     // 1.33x
  static const double _xlargeIconRatio = 1.67;    // 1.67x
  static const double _xxlargeIconRatio = 2.0;    // 2.0x
  
  // Icon size constants
  static const double iconSizeSmall = _baseIconSize * _smallIconRatio;     // 18.0
  static const double iconSizeMedium = _baseIconSize * _mediumIconRatio;   // 24.0
  static const double iconSizeLarge = _baseIconSize * _largeIconRatio;     // 32.0
  static const double iconSizeXLarge = _baseIconSize * _xlargeIconRatio;   // 40.0
  static const double iconSizeXXLarge = _baseIconSize * _xxlargeIconRatio; // 48.0
  
  // Legacy naming for compatibility
  static const double minIconSize = iconSizeSmall;      // 18.0
  static const double mobileMinIconSize = iconSizeMedium; // 24.0
  static const double defaultIconSize = iconSizeMedium;   // 24.0
  static const double largeIconSize = iconSizeLarge;      // 32.0
  
  // Status indicator sizes (for small status icons, badges, etc.)
  static const double statusIndicatorSmall = 12.0;       // Small status indicator (online dots, etc.)
  static const double statusIndicatorMedium = 16.0;      // Medium status indicator  
  static const double statusIndicatorLarge = 20.0;       // Large status indicator
  static const double mobileStatusIndicatorMin = 14.0;   // Minimum mobile status indicator size
  
  // Avatar and profile picture sizes with protection
  static const double avatarSizeSmall = 24.0;            // Small avatar (list items)
  static const double avatarSizeMedium = 32.0;           // Medium avatar (cards)
  static const double avatarSizeLarge = 48.0;            // Large avatar (profiles)
  static const double avatarSizeXLarge = 64.0;           // Extra large avatar
  static const double minAvatarSize = 24.0;              // Absolute minimum avatar size
  static const double mobileMinAvatarSize = 32.0;        // Minimum mobile avatar size

  // ===== Border radius system refactoring =====
  // Base radius unit
  static const double _baseRadius = 8.0;
  
  // Radius ratio system
  static const double _smallRadiusRatio = 0.5;    // 0.5x
  static const double _mediumRadiusRatio = 1.0;   // 1.0x
  static const double _largeRadiusRatio = 1.5;    // 1.5x
  
  // Radius constants
  static const double radiusSmall = _baseRadius * _smallRadiusRatio;   // 4.0
  static const double radiusMedium = _baseRadius * _mediumRadiusRatio; // 8.0
  static const double radiusLarge = _baseRadius * _largeRadiusRatio;   // 12.0
  
  // Legacy naming for compatibility
  static const double defaultRadius = radiusMedium; // 8.0
  static const double smallRadius = radiusSmall;    // 4.0
  static const double largeRadius = radiusLarge;    // 12.0

  // ===== Responsive breakpoint system refactoring =====
  // Desktop-first breakpoint design
  static const double breakpointMobile = 768.0;      // Mobile breakpoint
  static const double breakpointTablet = 1024.0;     // Tablet breakpoint
  static const double breakpointDesktop = 1440.0;    // Desktop breakpoint
  static const double breakpointLargeDesktop = 1920.0; // Large desktop breakpoint
  
  // Legacy naming for compatibility
  static const double mobileBreakpoint = breakpointMobile;
  static const double tabletBreakpoint = breakpointTablet;
  static const double desktopBreakpoint = breakpointDesktop;
  static const double largeDesktopBreakpoint = breakpointLargeDesktop;

  // ===== Layout dimension system =====
  // Sidebar width (based on screen ratio)
  static const double sidebarWidthRatio = 0.2;        // 20% of screen width
  static const double sidebarMinWidth = 240.0;        // Minimum width
  static const double sidebarMaxWidth = 320.0;        // Maximum width
  
  // Content area maximum width
  static const double contentMaxWidth = 1200.0;       // Content area maximum width
  static const double contentPaddingRatio = 0.05;     // 5% of screen width as padding

  // API Configuration - AWS Lambda Production
  // General API v3 - Authentication, Users, Patients, Devices
  static const String _generalApiBaseUrl = 'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod';
  
  // Tremor API - Tremor Analysis and Statistics (specialized endpoint)
  static const String _tremorApiBaseUrl = 'https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod';
  
  // Use General API as default base URL for authentication and general endpoints
  static String get baseUrl {
    // You can add environment detection here if needed
    return _generalApiBaseUrl;
  }
  
  // Tremor API endpoint for tremor-specific requests
  static String get tremorApiUrl => _tremorApiBaseUrl;
  
  // API version (automatically added by network interceptor)
  static const String apiVersion = '';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String settingsKey = 'app_settings';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String encryptionKeyKey = 'encryption_key';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Chart Configuration
  static const int realtimeDataPoints = 100;
  static const int hourlyDataPoints = 360; // 6 hours * 60 minutes
  static const int dailyDataPoints = 144; // 6 days * 24 hours
  static const int weeklyDataPoints = 42; // 6 weeks * 7 days

  // Sensor Data Thresholds
  static const double lowTremorThreshold = 40.0;
  static const double mediumTremorThreshold = 70.0;
  static const double highTremorThreshold = 100.0;

  // Refresh Intervals
  static const Duration realtimeRefreshInterval = Duration(seconds: 3);
  static const Duration normalRefreshInterval = Duration(seconds: 30);
  static const Duration backgroundRefreshInterval = Duration(minutes: 5);

  // Security Configuration
  static const int passwordMinLength = 8;
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  
  // Password Strength Requirements (Scheme A: Basic Enhancement)
  static const bool passwordRequireUppercase = true;
  static const bool passwordRequireLowercase = true;
  static const bool passwordRequireDigit = true;
  static const bool passwordRequireSpecialChar = true;
  static const String passwordSpecialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  // UI Constants
  static const double cardElevation = 2.0;

  // Error Messages
  static const String networkErrorMessage = 'Network connection error. Please check your internet connection.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
  static const String unauthorizedErrorMessage = 'Session expired. Please login again.';
  static const String generalErrorMessage = 'An unexpected error occurred. Please try again.';
}
