import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_pos/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewService Unit Tests', () {
    late ReviewService reviewService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      reviewService = ReviewService();
      reviewService.reset();
    });

    test('trackAppOpen increments open count and sets first open date', () async {
      await reviewService.trackAppOpen();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt('review_open_count'), 1);
      expect(prefs.containsKey('review_first_open_date'), true);
    });

    test('trackSignificantEvent increments event count', () async {
      await reviewService.trackSignificantEvent();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt('review_event_count'), 1);

      await reviewService.trackSignificantEvent();
      expect(prefs.getInt('review_event_count'), 2);
    });

    test('neverAskAgain sets the correct flag', () async {
      await reviewService.neverAskAgain();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getBool('review_never_ask_again'), true);
    });

    test('trackAppOpen does not increment twice in same run', () async {
      // Note: _wasTrackedThisRun is a private member, so we test behavior
      await reviewService.trackAppOpen();
      await reviewService.trackAppOpen();
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('review_open_count'), 1);
    });
  });
}
