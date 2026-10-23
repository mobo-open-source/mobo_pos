/// URL classification for the Odoo login flow.
///
/// Every check here parses the URL and inspects [Uri.path]. Matching against
/// the raw URL string is unsafe: `url.contains('/odoo')` also matches the
/// `//odoo` produced by a host such as `https://odoo.customer.com`, which makes
/// every page on that server — including the login page — look like a
/// successful login.
library;

/// Whether [url] is an Odoo backend page, meaning login has already completed.
///
/// Covers Odoo 16 and earlier (`/web`) and Odoo 17+ (`/odoo`). Login pages are
/// never backend pages, including the TOTP step.
bool isOdooBackendUrl(String url) {
  final path = _pathOf(url);
  if (path.startsWith('/web/login')) return false;
  return path == '/odoo' ||
      path.startsWith('/odoo/') ||
      path == '/web' ||
      path.startsWith('/web/');
}

/// Whether [url] is the login page, including the TOTP step.
bool isOdooLoginUrl(String url) => _pathOf(url).startsWith('/web/login');

/// Whether [url] is the TOTP challenge page.
bool isOdooTotpUrl(String url) => _pathOf(url).startsWith('/web/login/totp');

/// Whether [url] is the database selector.
bool isOdooDatabaseSelectorUrl(String url) =>
    _pathOf(url).startsWith('/web/database/selector');

String _pathOf(String url) => Uri.tryParse(url)?.path ?? '';
