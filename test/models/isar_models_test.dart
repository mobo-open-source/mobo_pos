import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_pos/Isarmodel/user_profile.dart';
import 'package:mobo_pos/Isarmodel/dropdown_options.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('creates empty user profile with default values', () {
      final user = UserProfile();
      
      expect(user.id, isNotNull);
      expect(user.userId, isNull);
      expect(user.userName, isNull);
      expect(user.userEmail, isNull);
      expect(user.dbName, isNull);
    });

    test('assigns and retrieves basic properties', () {
      final user = UserProfile()
        ..userId = '123'
        ..userName = 'John Doe'
        ..userEmail = 'john@example.com'
        ..userPhone = '+1234567890'
        ..dbName = 'test_db';
      
      expect(user.userId, '123');
      expect(user.userName, 'John Doe');
      expect(user.userEmail, 'john@example.com');
      expect(user.userPhone, '+1234567890');
      expect(user.dbName, 'test_db');
    });

    test('assigns and retrieves extended properties', () {
      final user = UserProfile()
        ..userMobile = '+0987654321'
        ..userWebsite = 'https://example.com'
        ..userFunction = 'Software Engineer'
        ..workLocation = 'Remote'
        ..department = 'Engineering';
      
      expect(user.userMobile, '+0987654321');
      expect(user.userWebsite, 'https://example.com');
      expect(user.userFunction, 'Software Engineer');
      expect(user.workLocation, 'Remote');
      expect(user.department, 'Engineering');
    });

    test('assigns and retrieves settings properties', () {
      final user = UserProfile()
        ..language = 'en_US'
        ..timezone = 'UTC'
        ..emailSignature = 'Best regards'
        ..maritalStatus = 'single';
      
      expect(user.language, 'en_US');
      expect(user.timezone, 'UTC');
      expect(user.emailSignature, 'Best regards');
      expect(user.maritalStatus, 'single');
    });

    test('assigns and retrieves boolean preferences', () {
      final user = UserProfile()
        ..notificationByEmail = true
        ..notificationInOdoo = false
        ..odooBotStatus = true;
      
      expect(user.notificationByEmail, true);
      expect(user.notificationInOdoo, false);
      expect(user.odooBotStatus, true);
    });

    test('assigns and retrieves server configuration', () {
      final user = UserProfile()
        ..serverUrl = 'https://demo.odoo.com'
        ..username = 'admin'
        ..password = 'admin123'
        ..companyId = '1';
      
      expect(user.serverUrl, 'https://demo.odoo.com');
      expect(user.username, 'admin');
      expect(user.password, 'admin123');
      expect(user.companyId, '1');
    });

    test('assigns and retrieves account key', () {
      final user = UserProfile()
        ..accountKey = 'admin@test_db'
        ..username = 'admin'
        ..dbName = 'test_db';
      
      expect(user.accountKey, 'admin@test_db');
    });

    test('assigns and retrieves timestamp', () {
      final now = DateTime.now();
      final user = UserProfile()..lastUpdated = now;
      
      expect(user.lastUpdated, now);
    });

    test('assigns and retrieves base64 profile image', () {
      final user = UserProfile()
        ..profileImageBase64 = 'base64ImageDataHere';
      
      expect(user.profileImageBase64, 'base64ImageDataHere');
    });

    test('creates complete user profile', () {
      final now = DateTime.now();
      final user = UserProfile()
        ..userId = '1'
        ..userName = 'Test User'
        ..userEmail = 'test@example.com'
        ..userPhone = '+1111111111'
        ..userMobile = '+2222222222'
        ..userWebsite = 'https://test.com'
        ..userFunction = 'Developer'
        ..workLocation = 'Office'
        ..department = 'IT'
        ..language = 'en_US'
        ..timezone = 'UTC'
        ..emailSignature = 'Regards'
        ..maritalStatus = 'married'
        ..notificationByEmail = true
        ..notificationInOdoo = true
        ..odooBotStatus = false
        ..dbName = 'production'
        ..serverUrl = 'https://odoo.company.com'
        ..username = 'testuser'
        ..password = 'secure123'
        ..companyId = '5'
        ..accountKey = 'testuser@production'
        ..profileImageBase64 = 'imagedata'
        ..lastUpdated = now;
      
      expect(user.userId, '1');
      expect(user.userName, 'Test User');
      expect(user.lastUpdated, now);
      expect(user.accountKey, 'testuser@production');
    });
  });

  group('SignedAccount Model Tests', () {
    test('creates empty signed account with default values', () {
      final account = SignedAccount();
      
      expect(account.id, isNotNull);
      expect(account.accountKey, isNull);
      expect(account.username, isNull);
      expect(account.serverAddress, isNull);
    });

    test('assigns and retrieves all properties', () {
      final account = SignedAccount()
        ..accountKey = 'admin@test_db'
        ..username = 'admin'
        ..serverAddress = 'https://odoo.com'
        ..database = 'test_db'
        ..password = 'password123'
        ..userNameDisplay = 'Admin User'
        ..profileImage = 'image_data'
        ..accountIdentifier = 'admin@test_db';
      
      expect(account.accountKey, 'admin@test_db');
      expect(account.username, 'admin');
      expect(account.serverAddress, 'https://odoo.com');
      expect(account.database, 'test_db');
      expect(account.password, 'password123');
      expect(account.userNameDisplay, 'Admin User');
      expect(account.profileImage, 'image_data');
      expect(account.accountIdentifier, 'admin@test_db');
    });

    test('account identifier matches expected format', () {
      final account = SignedAccount()
        ..username = 'user123'
        ..database = 'mydb'
        ..accountIdentifier = 'user123@mydb';
      
      expect(account.accountIdentifier, contains('@'));
      expect(account.accountIdentifier, contains('user123'));
      expect(account.accountIdentifier, contains('mydb'));
    });
  });

  group('MaritalStatusOption Model Tests', () {
    test('creates marital status option', () {
      final option = MaritalStatusOption()
        ..value = 'single'
        ..label = 'Single'
        ..accountKey = 'user@db';
      
      expect(option.value, 'single');
      expect(option.label, 'Single');
      expect(option.accountKey, 'user@db');
    });

    test('creates multiple marital status options', () {
      final single = MaritalStatusOption()
        ..value = 'single'
        ..label = 'Single'
        ..accountKey = 'user@db';
      
      final married = MaritalStatusOption()
        ..value = 'married'
        ..label = 'Married'
        ..accountKey = 'user@db';
      
      expect(single.value, isNot(equals(married.value)));
      expect(single.label, isNot(equals(married.label)));
    });

    test('associates option with account', () {
      final option = MaritalStatusOption()
        ..value = 'divorced'
        ..label = 'Divorced'
        ..accountKey = 'admin@production';
      
      expect(option.accountKey, 'admin@production');
      expect(option.accountKey, contains('@'));
    });
  });

  group('TimezoneOption Model Tests', () {
    test('creates timezone option', () {
      final option = TimezoneOption()
        ..value = 'America/New_York'
        ..label = 'Eastern Time (US & Canada)'
        ..accountKey = 'user@db';
      
      expect(option.value, 'America/New_York');
      expect(option.label, 'Eastern Time (US & Canada)');
      expect(option.accountKey, 'user@db');
    });

    test('creates multiple timezone options', () {
      final eastern = TimezoneOption()
        ..value = 'America/New_York'
        ..label = 'Eastern Time'
        ..accountKey = 'user@db';
      
      final pacific = TimezoneOption()
        ..value = 'America/Los_Angeles'
        ..label = 'Pacific Time'
        ..accountKey = 'user@db';
      
      expect(eastern.value, isNot(equals(pacific.value)));
    });

    test('handles UTC timezone', () {
      final option = TimezoneOption()
        ..value = 'UTC'
        ..label = 'UTC'
        ..accountKey = 'user@db';
      
      expect(option.value, 'UTC');
      expect(option.label, 'UTC');
    });
  });

  group('DepartmentOption Model Tests', () {
    test('creates department option', () {
      final option = DepartmentOption()
        ..idValue = '1'
        ..name = 'Engineering'
        ..accountKey = 'user@db';
      
      expect(option.idValue, '1');
      expect(option.name, 'Engineering');
      expect(option.accountKey, 'user@db');
    });

    test('creates multiple department options', () {
      final engineering = DepartmentOption()
        ..idValue = '1'
        ..name = 'Engineering'
        ..accountKey = 'user@db';
      
      final sales = DepartmentOption()
        ..idValue = '2'
        ..name = 'Sales'
        ..accountKey = 'user@db';
      
      expect(engineering.idValue, isNot(equals(sales.idValue)));
      expect(engineering.name, isNot(equals(sales.name)));
    });

    test('handles numeric ID as string', () {
      final option = DepartmentOption()
        ..idValue = '12345'
        ..name = 'Test Department'
        ..accountKey = 'user@db';
      
      expect(option.idValue, '12345');
      expect(int.tryParse(option.idValue), isNotNull);
    });
  });
}
