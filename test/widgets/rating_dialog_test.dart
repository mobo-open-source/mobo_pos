import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_pos/widgets/rating_dialog.dart';
import 'package:mobo_pos/core/style.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createDialogForTesting({
    required Function(double, String) onGoodReview,
    required Function(double, String) onBadReview,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CustomRatingDialog(
          onGoodReview: onGoodReview,
          onBadReview: onBadReview,
        ),
      ),
    );
  }

  group('CustomRatingDialog Widget Tests', () {
    testWidgets('renders all essential UI components', (WidgetTester tester) async {
      await tester.pumpWidget(createDialogForTesting(
        onGoodReview: (_, __) {},
        onBadReview: (_, __) {},
      ));

      expect(find.text('Rate Us'), findsOneWidget);
      expect(find.text('Tell others what you think about this app'), findsOneWidget);
      expect(find.byType(RatingBar), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('NEVER ASK AGAIN'), findsOneWidget);
      expect(find.text('ASK ME LATER'), findsOneWidget);
    });

    testWidgets('shows comment box only for low ratings', (WidgetTester tester) async {
      await tester.pumpWidget(createDialogForTesting(
        onGoodReview: (_, __) {},
        onBadReview: (_, __) {},
      ));

      // Initial rating is 5, so comment box should be hidden
      expect(find.byType(TextField), findsNothing);

      // Change rating to 3 stars
      // Note: RatingBar.builder uses a custom itemBuilder, so we interacts with the stars.
      // For simplicity in this test, we can use the state if possible, but widget tests should be black-box.
      // Let's find the RatingBar and simulate a tap.
      await tester.tap(find.byType(RatingBar)); // This might default to 3 if tap in middle
      await tester.pump();

      // Since tapping is imprecise, let's just use the fact that if we set it < 4 it shows.
      // We can set it manually via the widget if we had a controller or just tap the left side.
      // Let's try to find the stars.
      final starIcon = find.byIcon(Icons.star_rounded).first;
      await tester.tap(starIcon);
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('calls onGoodReview for 4+ stars', (WidgetTester tester) async {
      double? capturedRating;
      await tester.pumpWidget(createDialogForTesting(
        onGoodReview: (r, _) => capturedRating = r,
        onBadReview: (_, __) {},
      ));

      // 5 stars by default
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(capturedRating, 5.0);
    });

    testWidgets('calls onBadReview for < 4 stars', (WidgetTester tester) async {
      double? capturedRating;
      String? capturedComment;
      await tester.pumpWidget(createDialogForTesting(
        onGoodReview: (_, __) {},
        onBadReview: (r, c) {
          capturedRating = r;
          capturedComment = c;
        },
      ));

      // Tap first star (1 star)
      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pump();

      // Enter comment
      await tester.enterText(find.byType(TextField), 'Needs improvement');
      await tester.pump();

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(capturedRating, 1.0);
      expect(capturedComment, 'Needs improvement');
    });
   group('Dialog action buttons', () {
      testWidgets('tapping ASK ME LATER pops context', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CustomRatingDialog.show(context),
              child: const Text('Show'),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        expect(find.byType(CustomRatingDialog), findsOneWidget);

        await tester.tap(find.text('ASK ME LATER'));
        await tester.pumpAndSettle();
        expect(find.byType(CustomRatingDialog), findsNothing);
      });
    });
  });
}
