import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa_app/core/utils/font_utils.dart';

void main() {
  group('FontUtils Tests', () {
    testWidgets('getResponsiveTitleFontSize returns valid size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final fontSize = FontUtils.getResponsiveTitleFontSize(context);
              expect(fontSize, greaterThan(0));
              expect(fontSize, isA<double>());
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('getResponsiveBodyFontSize returns valid size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final fontSize = FontUtils.getResponsiveBodyFontSize(context);
              expect(fontSize, greaterThan(0));
              expect(fontSize, isA<double>());
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('responsiveTitleStyle creates valid TextStyle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final style = FontUtils.title(context: context);
              expect(style, isA<TextStyle>());
              expect(style.fontSize, greaterThan(0));
              expect(style.fontWeight, FontWeight.w600);
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('responsiveBodyStyle creates valid TextStyle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final style = FontUtils.body(context: context);
              expect(style, isA<TextStyle>());
              expect(style.fontSize, greaterThan(0));
              expect(style.fontWeight, FontWeight.w400);
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('responsiveTitle creates valid Widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FontUtils.titleText('Test Title', context);
              },
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('responsiveBody creates valid Widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FontUtils.bodyText('Test Body', context);
              },
            ),
          ),
        ),
      );

      expect(find.text('Test Body'), findsOneWidget);
    });

    testWidgets('responsiveCaption creates valid Widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FontUtils.captionText('Test Caption', context);
              },
            ),
          ),
        ),
      );

      expect(find.text('Test Caption'), findsOneWidget);
    });

    testWidgets('responsiveButton creates valid Widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FontUtils.bodyText('Test Button', context);
              },
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('getResponsiveSubtitleFontSize returns valid size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final fontSize = FontUtils.getResponsiveSubtitleFontSize(context);
              expect(fontSize, greaterThan(0));
              expect(fontSize, isA<double>());
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('getResponsiveCaptionFontSize returns valid size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final fontSize = FontUtils.getResponsiveCaptionFontSize(context);
              expect(fontSize, greaterThan(0));
              expect(fontSize, isA<double>());
              return const Scaffold();
            },
          ),
        ),
      );
    });
  });
}
