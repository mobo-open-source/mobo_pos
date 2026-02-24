import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'user_profile.dart';
import 'dropdown_options.dart'; // Import the new models

/// Service for managing the Isar database instance and its lifecycle.
class IsarService {
  static Isar? _instance;

  /// Returns the singleton Isar instance, initializing it if necessary.
  static Future<Isar> get instance async {
    if (_instance == null) {
      final dir = await getApplicationDocumentsDirectory();
      _instance = await Isar.open(
        [
          UserProfileSchema,
          SignedAccountSchema,
          SignedAccountListingSchema,
          MaritalStatusOptionSchema,
          TimezoneOptionSchema,
          DepartmentOptionSchema,
        ],
        directory: dir.path,
      );

    }
    return _instance!;
  }
}