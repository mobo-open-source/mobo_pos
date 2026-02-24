import 'package:isar_community/isar.dart';

part 'user_profile.g.dart';

/// Isar collection for storing detailed user profile information fetched from Odoo.
@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  String? userId;
  String? userName;
  String? userEmail;
  String? userPhone;
  String? userMobile; // New field for mobile phone
  String? userWebsite; // New field for website
  String? userFunction; // New field for job title/function
  String? workLocation;
  String? department;
  String? language;
  String? timezone;
  String? emailSignature;
  String? maritalStatus;
  String? profileImageBase64;
  bool? notificationByEmail;
  bool? notificationInOdoo;
  bool? odooBotStatus;
  String? dbName;
  String? serverUrl;
  String? username;
  String? password;
  String? companyId; // New field to store company ID
  DateTime? lastUpdated;
  @Index(unique: true, composite: [CompositeIndex('dbName')])
  String? accountKey; // Format: username@dbName
}

/// Isar collection representing an account that has been signed into.
@collection
class SignedAccount {
  Id id = Isar.autoIncrement;

  String? accountKey; // Format: username@dbName
  String? username;
  String? serverAddress;
  String? database;
  String? password;
  String? userNameDisplay;
  String? profileImage;

  @Index(unique: true)
  String? accountIdentifier; // Format: username@database
}

/// Isar collection for listing accounts in the switch account screen.
@collection
class SignedAccountListing {
  Id id = Isar.autoIncrement;

  String? accountKey; // Format: username@dbName
  String? username;
  String? serverAddress;
  String? database;
  String? password;
  String? userNameDisplay;
  String? profileImage;
  DateTime? lastLoginTime;

  @Index(unique: true)
  String? accountIdentifier; // Format: username@database
}