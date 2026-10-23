import '../core/image_utils.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

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
      // A user with no uploaded photo has image_1920 == false; Odoo then
      // serves a generated (SVG initials) avatar through avatar_1920.
      image: ImageUtils.base64Of(json['image_1920']).isNotEmpty
          ? ImageUtils.base64Of(json['image_1920'])
          : ImageUtils.base64Of(json['avatar_1920']),
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

  /// Initializes the Odoo client for the current account, reusing its stored
  /// session first and only falling back to password auth when that's stale
  /// (see [AuthService.getAuthenticatedClient] — a plain password retry can
  /// never succeed for a 2FA-enabled account and crashes rather than fails
  /// cleanly, so it must not be attempted unconditionally here).
  Future<void> initializeClient() async {
    final prefs = await SharedPreferences.getInstance();
    url = prefs.getString('uri') ?? '';
    final sessionId = prefs.getString('session_id') ?? '';
    final dbName = prefs.getString('dbName') ?? '';
    final userIdStr = prefs.getString('userId') ?? '0';
    final partnerIdStr = prefs.getString('partnerId') ?? '0';
    final companyIdStr = prefs.getString('companyId') ?? '0';

    if (url.isEmpty || sessionId.isEmpty) return;

    final username = prefs.getString('username') ?? '';
    final password = prefs.getString('password') ?? '';
    final authLogin = prefs.getString('userLogin') ?? username;

    userId = int.tryParse(userIdStr);
    companyId = int.tryParse(companyIdStr);

    client = await AuthService().getAuthenticatedClient(
      url: url,
      database: dbName,
      username: authLogin,
      password: password,
      sessionId: sessionId,
      userId: int.tryParse(userIdStr) ?? 0,
      partnerId: int.tryParse(partnerIdStr) ?? 0,
      userLogin: prefs.getString('userLogin'),
      userName: prefs.getString('userName'),
      userLang: prefs.getString('userLang') ?? 'en_US',
      userTz: prefs.getString('userTz') ?? 'UTC',
      isSystem: prefs.getBool('isSystem') ?? false,
      serverVersion: prefs.getString('serverVersion') ?? '',
      companyId: int.tryParse(companyIdStr) ?? 1,
      twoFactorRequired: prefs.getBool('twoFactorRequired') ?? false,
    );
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
          'attributes': ['type'],
        },
      });
      final availableFields = fieldsResponse as Map<String, dynamic>;
      final mobileField =
          availableFields.containsKey('mobile')
              ? 'mobile'
              : (availableFields.containsKey('mobile_phone')
                  ? 'mobile_phone'
                  : null);

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
        if (availableFields.containsKey('avatar_1920')) 'avatar_1920',
        'website',
        'function',
      ];

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
  ///
  /// Only for fields in `res.users`' own self-write whitelist (`name`,
  /// `email`, `image_1920`, ...) — `phone`/`mobile` aren't in it, so writing
  /// them here raises AccessError for a non-admin user even though they
  /// technically exist on the model as related fields. Route those through
  /// [updatePartner] instead.
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    final dbName = p.getString('dbName');
    final username = p.getString('userLogin');
    final password = p.getString('password');

    if (dbName == null || username == null || password == null) return false;

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
  }

  Future<Map<String, dynamic>> _fieldsOf(String model) async {
    try {
      final r = await client?.callKw({
        'model': model,
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'attributes': ['type'],
        },
      });
      return Map<String, dynamic>.from(r as Map);
    } catch (_) {
      return {};
    }
  }

  /// Where the mobile number can be stored on this server, or null if the
  /// server has no such field. Odoo 19 removed `res.partner.mobile`, and
  /// `mobile_phone` only exists on `res.users` when the HR module is installed.
  Future<String?> mobileTarget() async {
    if ((await _fieldsOf('res.partner')).containsKey('mobile')) {
      return 'partner';
    }
    if ((await _fieldsOf('res.users')).containsKey('mobile_phone')) {
      return 'user';
    }
    return null;
  }

  /// Updates `phone`/`mobile` for the user's partner (`res.users` rejects
  /// these for a non-admin user). `mobile` is written to whichever model
  /// actually has the field (see [mobileTarget]) and skipped if none does.
  Future<bool> updatePartner(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    final partnerId = int.tryParse(p.getString('partnerId') ?? '0') ?? 0;
    if (partnerId == 0) throw Exception('missing/invalid stored partnerId');

    final partnerData = Map<String, dynamic>.from(data);
    final mobile = partnerData.remove('mobile');
    String? target;
    if (mobile is String) target = await mobileTarget();
    if (target == 'partner') partnerData['mobile'] = mobile;

    var ok = true;
    if (partnerData.isNotEmpty) {
      ok = await _write('res.partner', partnerId, partnerData);
    }
    if (target == 'user' && mobile is String) {
      await _updateMobilePhone(mobile);
    }
    return ok;
  }

  Future<void> _updateMobilePhone(String mobile) async {
    final uid = userId ?? 0;
    if (uid == 0) return;
    try {
      await _write('res.users', uid, {'mobile_phone': mobile});
    } catch (_) {
      // Non-HR users can't write it on res.users; write the linked employee.
      final emp = await client?.callKw({
        'model': 'hr.employee',
        'method': 'search',
        'args': [
          [
            ['user_id', '=', uid],
          ],
        ],
        'kwargs': {'limit': 1},
      });
      if (emp is List && emp.isNotEmpty) {
        await _write('hr.employee', emp.first as int, {'mobile_phone': mobile});
      } else {
        rethrow;
      }
    }
  }

  Future<bool> _write(
    String model,
    int recordId,
    Map<String, dynamic> data,
  ) async {
    final result = await client?.callKw({
      'model': model,
      'method': 'write',
      'args': [
        [recordId],
        data,
      ],
      'kwargs': {},
    });
    if (result != true) {
      throw Exception('write() on $model returned $result instead of true');
    }
    return true;
  }
}
