import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  Map<String, dynamic> companyData = {};
  bool hasError = false;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCompanyProfile();
  }

  Future<void> _fetchCompanyProfile() async {
    log("Fetching company profile data...");
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString("uri");
      final dbName = prefs.getString("database");
      final sessionId = prefs.getString("session_id");

      if (serverUrl == null || dbName == null || sessionId == null) {
        throw Exception('Missing authentication data');
      }

      // Create session from stored data
      final session = OdooSession(
        id: sessionId,
        userId: int.parse(prefs.getString("userId") ?? "1"),
        partnerId: int.parse(prefs.getString("partnerId") ?? "1"),
        userLogin: prefs.getString("userLogin") ?? "",
        userName: prefs.getString("userName") ?? "",
        userLang: prefs.getString("userLang") ?? "en_US",
        userTz: prefs.getString("userTz") ?? "UTC",
        isSystem: prefs.getBool("isSystem") ?? false,
        dbName: dbName,
        serverVersion: prefs.getString("serverVersion") ?? "16.0",
        companyId: int.parse(prefs.getString("companyId") ?? "1"),
        allowedCompanies: [],
      );

      final client = OdooClient(serverUrl, );

      // CRITICAL: Re-authenticate the client
      final username = prefs.getString("username");
      final password = prefs.getString("password");
      if (username != null && password != null) {
        await client.authenticate(dbName, username, password);
      }

      // Get company ID from session
      final companyId = session.companyId;
      
      final companyDetails = await client.callKw({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', companyId]
          ]
        ],
        'kwargs': {
          'fields': [
            'name',
            'phone',
            'mobile',
            'email',
            'website',
            'street',
            'city',
            'state_id',
            'country_id',
            'vat',
            'logo_web',
            'company_registry',
            'alias_domain_id',
          ],
        },
      });

      if (companyDetails != null && companyDetails.isNotEmpty) {
        final company = companyDetails[0];
        company['address'] = _formatAddress(company);
        log("Company profile fetched successfully");

        setState(() {
          companyData = company;
          isLoading = false;
        });
      } else {
        log("No company details found");
        setState(() {
          companyData = {};
          isLoading = false;
        });
      }
    } catch (e) {
      log("Error fetching company profile: $e");
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString();
      });
    }
  }

  String _formatAddress(Map<String, dynamic> company) {
    List<String> addressParts = [];

    if (company['street'] != false && company['street'] != null) {
      addressParts.add(company['street']);
    }
    if (company['city'] != false && company['city'] != null) {
      addressParts.add(company['city']);
    }
    if (company['state_id'] != false && company['state_id'] != null) {
      addressParts.add(company['state_id'][1]);
    }
    if (company['country_id'] != false && company['country_id'] != null) {
      addressParts.add(company['country_id'][1]);
    }

    return addressParts.isNotEmpty ? addressParts.join(', ') : 'No Address';
  }

  Widget _buildLogoWidget(BuildContext context) {
    final logoWeb = companyData['logo_web'];
    if (logoWeb == null || logoWeb == '' || logoWeb == 'false') {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFC03355).withOpacity(0.1),
          border: Border.all(color: const Color(0xFFC03355), width: 2),
        ),
        child: const HugeIcon(icon:
          HugeIcons.strokeRoundedBuilding06,
          size: 50,
          color: Color(0xFFC03355),
        ),
      );
    }

    try {
      final decodedBytes = base64Decode(logoWeb);
      return GestureDetector(
        onTap: () {
          _showFullScreenImage(context, decodedBytes);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC03355), width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.memory(
              decodedBytes,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC03355).withOpacity(0.1),
                ),
                child: const HugeIcon(icon:
                  HugeIcons.strokeRoundedBuilding06,
                  size: 50,
                  color: Color(0xFFC03355),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      log("Error decoding logo_web: $e");
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFC03355).withOpacity(0.1),
          border: Border.all(color: const Color(0xFFC03355), width: 2),
        ),
        child: const HugeIcon(icon:
          HugeIcons.strokeRoundedBuilding06,
          size: 50,
          color: Color(0xFFC03355),
        ),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.memory(imageBytes),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Company Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(icon:
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: isLoading
          ? const CompanyLoadingView()
          : hasError
              ? CompanyErrorView(
                  errorMessage: errorMessage,
                  onRetry: _fetchCompanyProfile,
                )
              : companyData.isEmpty
                  ? const NoDataView()
                  : SingleChildScrollView(
                      child: CompanyContentView(
                        companyData: companyData,
                        buildLogoWidget: _buildLogoWidget,
                      ),
                    ),
    );
  }
}

class CompanyContentView extends StatelessWidget {
  final Map<String, dynamic> companyData;
  final Widget Function(BuildContext) buildLogoWidget;

  const CompanyContentView({
    super.key,
    required this.companyData,
    required this.buildLogoWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        
        // Logo
        buildLogoWidget(context),
        
        const SizedBox(height: 20),

        // Company Name
        Text(
          companyData['name'] ?? 'No Name',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 30),

        // Info cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // Contact Info Card
              InfoCard(
                title: 'Contact Information',
                icon: HugeIcons.strokeRoundedMail01,
                content: Column(
                  children: [
                    InfoItem(
                      icon: HugeIcons.strokeRoundedMail01,
                      title: 'Email',
                      value: companyData['email'] ?? 'No Email',
                    ),
                    InfoItem(
                      icon: HugeIcons.strokeRoundedCall,
                      title: 'Phone',
                      value: companyData['phone'] != false && companyData['phone'] != null
                          ? companyData['phone']
                          : 'No Phone',
                    ),
                    InfoItem(
                      icon: HugeIcons.strokeRoundedSmartPhone01,
                      title: 'Mobile',
                      value: companyData['mobile'] != false && companyData['mobile'] != null
                          ? companyData['mobile']
                          : 'No Mobile',
                    ),
                    if (companyData['website'] != false && companyData['website'] != null)
                      InfoItem(
                        icon: HugeIcons.strokeRoundedGlobe02,
                        title: 'Website',
                        value: companyData['website'] ?? 'No Website',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Address Card
              InfoCard(
                title: 'Address',
                icon: HugeIcons.strokeRoundedLocation01,
                content: Column(
                  children: [
                    InfoItem(
                      icon: HugeIcons.strokeRoundedHome01,
                      title: 'Location',
                      value: companyData['address'] ?? 'No Address',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Business Info Card
              InfoCard(
                title: 'Business Information',
                icon: HugeIcons.strokeRoundedBuilding06,
                content: Column(
                  children: [
                    InfoItem(
                      icon: HugeIcons.strokeRoundedMail01,
                      title: 'Email Domain',
                      value: companyData['alias_domain_id'] != false && companyData['alias_domain_id'] != null
                          ? companyData['alias_domain_id'][1] ?? 'No Domain Set'
                          : 'No Domain Set',
                    ),
                    if (companyData['vat'] != false && companyData['vat'] != null)
                      InfoItem(
                        icon: HugeIcons.strokeRoundedInvoice01,
                        title: 'VAT Number',
                        value: companyData['vat'],
                      ),
                    if (companyData['company_registry'] != false && companyData['company_registry'] != null)
                      InfoItem(
                        icon: HugeIcons.strokeRoundedFile02,
                        title: 'Company Registry',
                        value: companyData['company_registry'],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final Widget content;

  const InfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final primaryColor = const Color(0xFFC03355);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                HugeIcon(icon:
                  icon,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }
}

class InfoItem extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String value;

  const InfoItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFC03355);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(icon:
              icon,
              color: primaryColor.withOpacity(0.7),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyLoadingView extends StatelessWidget {
  const CompanyLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFFC03355),
          ),
          SizedBox(height: 20),
          Text(
            "Loading company profile...",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const CompanyErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon:
              HugeIcons.strokeRoundedAlert02,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              "Error Loading Company Profile",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't load the company information. Please check your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC03355),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoDataView extends StatelessWidget {
  const NoDataView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon:
            HugeIcons.strokeRoundedBuilding06,
            color: isDark ? Colors.grey[600] : Colors.grey[500],
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            "No Company Data Found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "We couldn't find any company information for your account",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
