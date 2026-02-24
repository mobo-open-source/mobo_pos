import 'package:isar_community/isar.dart';

part 'dropdown_options.g.dart';

// Model for Marital Status Options
/// Isar collection for storing marital status dropdown options.
@collection
class MaritalStatusOption {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('accountKey')])
  late String value; // e.g., 'single', 'married'

  late String label; // e.g., 'Single', 'Married'

  late String accountKey; // Format: username@dbName
}

// Model for Timezone Options
/// Isar collection for storing timezone dropdown options.
@collection
class TimezoneOption {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('accountKey')])
  late String value; // e.g., 'America/New_York'

  late String label; // e.g., 'Eastern Time (US & Canada)'

  late String accountKey; // Format: username@dbName
}

// Model for Department Options
/// Isar collection for storing department dropdown options.
@collection
class DepartmentOption {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('accountKey')])
  late String idValue; // Department ID as string, e.g., '1'

  late String name; // e.g., 'Engineering'

  late String accountKey; // Format: username@dbName
}