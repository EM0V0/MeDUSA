import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Font utility class - Responsive font management
class FontUtils {
  // ===== Breakpoint Checks =====
  
  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < AppConstants.breakpointMobile;
  }
  
  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppConstants.breakpointMobile && width < AppConstants.breakpointTablet;
  }
  
  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.breakpointTablet;
  }

  // ===== Font Size Calculation =====
  
  /// Get responsive font size based on screen type with minimum font protection
  static double getFontSize(BuildContext context, {
    required double mobileSize,
    required double tabletSize,
    required double desktopSize,
    double? mobileMin,
    double? tabletMin,
    double? desktopMin,
  }) {
    if (isMobile(context)) {
      return mobileMin != null ? 
        (mobileSize < mobileMin ? mobileMin : mobileSize) : mobileSize;
    }
    if (isTablet(context)) {
      return tabletMin != null ? 
        (tabletSize < tabletMin ? tabletMin : tabletSize) : tabletSize;
    }
    return desktopMin != null ? 
      (desktopSize < desktopMin ? desktopMin : desktopSize) : desktopSize;
  }
  
  /// Get responsive display font size (largest, for main titles)
  static double getResponsiveDisplayFontSize(BuildContext context) {
    return getFontSize(
      context,
      mobileSize: AppConstants.mobileDisplayFontSize,
      tabletSize: AppConstants.tabletDisplayFontSize,
      desktopSize: AppConstants.desktopDisplayFontSize,
      mobileMin: AppConstants.mobileMinTitleFontSize,
      tabletMin: AppConstants.tabletMinTitleFontSize,
      desktopMin: AppConstants.desktopMinTitleFontSize,
    );
  }
  
  /// Get responsive headline font size (for section headers)
  static double getResponsiveHeadlineFontSize(BuildContext context) {
    return getFontSize(
      context,
      mobileSize: AppConstants.mobileHeadlineFontSize,
      tabletSize: AppConstants.tabletHeadlineFontSize,
      desktopSize: AppConstants.desktopHeadlineFontSize,
      mobileMin: AppConstants.mobileMinTitleFontSize,
      tabletMin: AppConstants.tabletMinTitleFontSize,
      desktopMin: AppConstants.desktopMinTitleFontSize,
    );
  }

  /// Get responsive title font size (for card headers, smaller than before)
  static double getResponsiveTitleFontSize(BuildContext context) {
    return getFontSize(
      context,
      mobileSize: AppConstants.mobileTitleFontSize,
      tabletSize: AppConstants.tabletTitleFontSize,
      desktopSize: AppConstants.desktopTitleFontSize,
      mobileMin: AppConstants.mobileMinTitleFontSize,
      tabletMin: AppConstants.tabletMinTitleFontSize,
      desktopMin: AppConstants.desktopMinTitleFontSize,
    );
  }
  
  /// Get responsive subtitle font size
  static double getResponsiveSubtitleFontSize(BuildContext context) {
    return getResponsiveTitleFontSize(context) * 0.8;
  }
  
  /// Get responsive body large font size (primary content)
  static double getResponsiveBodyLargeFontSize(BuildContext context) {
    return getFontSize(
      context,
      mobileSize: AppConstants.mobileBodyLargeFontSize,
      tabletSize: AppConstants.tabletBodyLargeFontSize,
      desktopSize: AppConstants.desktopBodyLargeFontSize,
      mobileMin: AppConstants.mobileMinBodyFontSize,
      tabletMin: AppConstants.tabletMinBodyFontSize,
      desktopMin: AppConstants.desktopMinBodyFontSize,
    );
  }
  
  /// Get responsive body font size (secondary content, smaller)
  static double getResponsiveBodyFontSize(BuildContext context) {
    return getFontSize(
      context,
      mobileSize: AppConstants.mobileBodyFontSize,
      tabletSize: AppConstants.tabletBodyFontSize,
      desktopSize: AppConstants.desktopBodyFontSize,
      mobileMin: AppConstants.mobileMinBodyFontSize,
      tabletMin: AppConstants.tabletMinBodyFontSize,
      desktopMin: AppConstants.desktopMinBodyFontSize,
    );
  }
  
  /// Get responsive label font size (for form labels, tags)
  static double getResponsiveLabelFontSize(BuildContext context) {
    return getFontSize(
      context,
      mobileSize: AppConstants.mobileLabelFontSize,
      tabletSize: AppConstants.tabletLabelFontSize,
      desktopSize: AppConstants.desktopLabelFontSize,
      mobileMin: AppConstants.mobileMinCaptionFontSize,
      tabletMin: AppConstants.tabletMinCaptionFontSize,
      desktopMin: AppConstants.desktopMinCaptionFontSize,
    );
  }
  
  /// Get responsive caption font size
  static double getResponsiveCaptionFontSize(BuildContext context) {
    return getFontSize(
      context,
      mobileSize: AppConstants.mobileCaptionFontSize,
      tabletSize: AppConstants.tabletCaptionFontSize,
      desktopSize: AppConstants.desktopCaptionFontSize,
      mobileMin: AppConstants.mobileMinCaptionFontSize,
      tabletMin: AppConstants.tabletMinCaptionFontSize,
      desktopMin: AppConstants.desktopMinCaptionFontSize,
    );
  }
  
  /// Get responsive button font size
  static double getResponsiveButtonFontSize(BuildContext context) {
    return getResponsiveBodyFontSize(context);
  }

  // ===== Text Style Creation =====
  
  /// Create responsive title text style
  static TextStyle responsiveTitleStyle({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveTitleFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }
  
  /// Create responsive subtitle text style
  static TextStyle responsiveSubtitleStyle({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveSubtitleFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
    );
  }
  
  /// Create responsive body text style
  static TextStyle responsiveBodyStyle({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveBodyFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
    );
  }
  
  /// Create responsive caption text style
  static TextStyle responsiveCaptionStyle({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveCaptionFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
    );
  }
  
  /// Create responsive button text style
  static TextStyle responsiveButtonStyle({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveButtonFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
    );
  }

  // ===== Style Method Shortcuts (Enhanced Typography) =====
  
  /// Display style method (largest, for main page titles)
  static TextStyle display({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveDisplayFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w700, // Bold by default
      color: color,
      letterSpacing: -0.5, // Tighter spacing for large text
    );
  }
  
  /// Headline style method (for section headers)
  static TextStyle headline({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveHeadlineFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w600, // Semi-bold by default
      color: color,
      letterSpacing: -0.25,
    );
  }

  /// Title style method (for card headers, refined)
  static TextStyle title({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveTitleFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }
  
  /// Body large style method (primary content)
  static TextStyle bodyLarge({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveBodyLargeFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: 1.5, // Better line height
    );
  }
  
  /// Body style method (secondary content, refined)
  static TextStyle body({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveBodyFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: 1.4,
    );
  }
  
  /// Label style method (for form labels, tags)
  static TextStyle label({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveLabelFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      letterSpacing: 0.1,
    );
  }
  
  /// Caption style method (metadata, timestamps, refined smaller)
  static TextStyle caption({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: getResponsiveCaptionFontSize(context),
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: 1.3,
      letterSpacing: 0.15,
    );
  }
  
  /// Subtitle style method
  static TextStyle subtitle({
    required BuildContext context,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return responsiveSubtitleStyle(
      context: context,
      color: color,
      fontWeight: fontWeight,
    );
  }

  // ===== Widget Creation Methods =====
  
  /// Create responsive title text widget
  static Widget titleText(String text, BuildContext context, {
    Color? color,
    TextAlign? textAlign,
    int? maxLines,
    FontWeight? fontWeight,
  }) {
    return Text(
      text,
      style: title(
        context: context,
        color: color,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
    );
  }
  
  /// Create responsive body text widget
  static Widget bodyText(String text, BuildContext context, {
    Color? color,
    TextAlign? textAlign,
    int? maxLines,
    FontWeight? fontWeight,
  }) {
    return Text(
      text,
      style: body(
        context: context,
        color: color,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
    );
  }
  
  /// Create responsive caption text widget
  static Widget captionText(String text, BuildContext context, {
    Color? color,
    TextAlign? textAlign,
    int? maxLines,
    FontWeight? fontWeight,
  }) {
    return Text(
      text,
      style: caption(
        context: context,
        color: color,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
    );
  }
}