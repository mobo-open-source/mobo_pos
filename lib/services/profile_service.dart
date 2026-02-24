import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data model representing a user profile with personal and company information.
class Profile {
  final int id;
  final String name;
  final String phone;
  final String mail;
  final String address;
  final String mobile;
  final String website;
  final String jobTitle;
  final String image;
  final String company;
  final String street;
  final String street2;
  final String state;
  final int stateId;
  final String country;
  final int countryId;

  Profile({
    required this.id,
    required this.name,
    required this.phone,
    required this.mail,
    required this.address,
    required this.mobile,
    required this.website,
    required this.jobTitle,
    required this.image,
    required this.company,
    required this.street,
    required this.street2,
    required this.state,
    required this.stateId,
    required this.country,
    required this.countryId,
  });

  /// Creates a [Profile] instance from a JSON map returned by the Odoo API.
  factory Profile.fromJson(Map<String, dynamic> json) {
    String extractName(dynamic field) {
      if (field is List && field.length >= 2) {
        return field[1]?.toString() ?? '';
      }
      return '';
    }

    int extractId(dynamic field) {
      if (field is List && field.isNotEmpty) {
        return field[0] ?? 0;
      }
      return 0;
    }

    String extractStringField(dynamic field) {
      if (field == null || field == false) {
        return '';
      }
      return field.toString();
    }

    return Profile(
      id: json['id'] ?? 0,
      name: extractStringField(json['name']),
      phone: extractStringField(json['phone']),
      mail: extractStringField(json['email']),
      address: extractStringField(json['contact_address']),
      mobile: extractStringField(json['mobile'] ?? json['mobile_phone']),
      website: extractStringField(json['website']),
      jobTitle: extractStringField(json['function']),
      image: extractStringField(json['image_1920']),
      company: extractName(json['company_id']),
      street: extractStringField(json['street']),
      street2: extractStringField(json['street2']),
      state: extractName(json['state_id']),
      stateId: extractId(json['state_id']),
      country: extractName(json['country_id']),
      countryId: extractId(json['country_id']),
    );
  }

  /// Converts the [Profile] instance into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': mail,
      'address': address,
      'mobile': mobile,
      'website': website,
      'jobTitle': jobTitle,
      'image': image,
      'company': company,
      'street': street,
      'street2': street2,
      'state': state,
      'stateId': stateId,
      'country': country,
      'countryId': countryId,
    };
  }

  /// Returns a default "Unknown" [Profile] instance.
  factory Profile.defaultProfile() {
    return Profile(
      id: 0,
      name: 'Unknown',
      phone: '',
      mail: '',
      address: '',
      mobile: '',
      website: '',
      jobTitle: '',
      image: '',
      company: '',
      street: '',
      street2: '',
      state: '',
      stateId: 0,
      country: '',
      countryId: 0,
    );
  }
}

/// Service for managing user profile retrieval and updates via Odoo RPC.
class ProfileService {
  OdooClient? client;
  int? userId;
  int? companyId;
  String url = '';

  /// Initializes the Odoo client with saved credentials from SharedPreferences.
  Future<void> initializeClient() async {
    final prefs = await SharedPreferences.getInstance();
    url = prefs.getString('uri') ?? '';
    final sessionId = prefs.getString('session_id') ?? '';
    final dbName = prefs.getString('dbName') ?? '';
    final userIdStr = prefs.getString('userId') ?? '0';
    final partnerIdStr = prefs.getString('partnerId') ?? '0';
    final companyIdStr = prefs.getString('companyId') ?? '0';

    if (url.isEmpty || sessionId.isEmpty) return;

    final session = OdooSession(
      id: sessionId,
      userId: int.parse(userIdStr),
      partnerId: int.parse(partnerIdStr),
      userLogin: prefs.getString('userLogin') ?? '',
      userName: prefs.getString('userName') ?? '',
      userLang: prefs.getString('userLang') ?? '',
      userTz: prefs.getString('userTz') ?? '',
      isSystem: prefs.getBool('isSystem') ?? false,
      dbName: dbName,
      serverVersion: prefs.getString('serverVersion') ?? '',
      companyId: int.parse(companyIdStr),
      allowedCompanies: [],
    );

    final username = prefs.getString('username') ?? '';
    final password = prefs.getString('password') ?? '';

    client = OdooClient(url);
    await client!.authenticate(dbName, username, password);
  }

  int parseMajorVersion(String? serverVersion) {
    if (serverVersion == null || serverVersion.isEmpty) return 0;

    final match = RegExp(r'(\d{1,2})').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Fetches the current user's profile details from Odoo.
  Future<List<Profile>> loadProfile() async {
    try {
      final p = await SharedPreferences.getInstance();
      final dbName = p.getString('dbName');
      final username = p.getString('userLogin');
      final password = p.getString('password');

      if (dbName == null || username == null || password == null) return [];

      final fieldsResponse = await client?.callKw({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'attributes': ['type']
        }
      });
      final availableFields = fieldsResponse as Map<String, dynamic>;
      final mobileField = availableFields.containsKey('mobile')
          ? 'mobile'
          : (availableFields.containsKey('mobile_phone') ? 'mobile_phone' : null);

      final fields = [
        'id',
        'name',
        'phone',
        'email',
        if (mobileField != null) mobileField,
        'contact_address',
        'company_id',
        'street',
        'street2',
        'state_id',
        'country_id',
        'image_1920',
        'website',
        'function',
      ];
      await client?.authenticate(dbName, username, password);

      final res = await client?.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', int.parse(p.getString('userId') ?? '0')],
          ],
        ],
        'kwargs': {'fields': fields},
      });
      return (res as List).map((e) => Profile.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Updates the user's profile information in Odoo.
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    final dbName = p.getString('dbName');
    final username = p.getString('userLogin');
    final password = p.getString('password');

    if (dbName == null || username == null || password == null) return false;

    try {
      await client?.authenticate(dbName, username, password);
      final result = await client?.callKw({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [int.parse(p.getString('userId') ?? '0')],
          data,
        ],
        'kwargs': {},
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
