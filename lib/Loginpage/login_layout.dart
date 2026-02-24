import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// A shared layout builder for all login-related screens, providing a consistent professional look.
class LoginLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? backButton;

  const LoginLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.backButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(children: [
        // Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[950] : Colors.grey[50],
              image: DecorationImage(
                image: AssetImage('assets/loginbg.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.black.withOpacity(1) : Colors.white.withOpacity(1),
                  BlendMode.dstATop,
                ),
                onError: (exception, stackTrace) {
                  // Fallback to solid color if image fails to load
                },
              ),
            ),
          ),
        ),

        // Sales App text at the top
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/pos-icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.business,
                      color: Color(0xFFC03355),
                      size: 24,
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'mobo POS',
                  style: const TextStyle(
                    fontFamily: 'YaroRg',
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main content centered
        SafeArea(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 0.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewportConstraints.maxHeight),
                  child: Align(
                    alignment: const Alignment(0, -0.05),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Header section (Sign In title and subtitle only)
                          const SizedBox(height: 40),
                          _buildSignInHeader(),
                          const SizedBox(height: 40),

                          // Form section with consistent theme
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: Theme.of(context)
                                    .inputDecorationTheme
                                    .copyWith(
                                      errorStyle: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.red[900]!,
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                              ),
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Back button (if provided)
        if (backButton != null) backButton!,
      ]),
    );
  }

  // Build header section (legacy - kept for compatibility)
  Widget _buildHeader() {
    return _buildSignInHeader();
  }

  // Build Sign In header section (without Sales App text)
  Widget _buildSignInHeader() {
    return Column(
      children: [
        // Sign In title
        Text(
          title,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 26,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Common text field builder for login screens
/// A specialized text field component for login forms with a custom design.
class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final List<List<dynamic>> prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;

  const LoginTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.suffixIcon,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Colors.black,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(.4)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: HugeIcon(icon:  prefixIcon, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 0,
        ),
        prefixIconColor: MaterialStateColor.resolveWith(
          (states) => states.contains(MaterialState.disabled)
              ? Colors.black26
              : Colors.black54,
        ),
        suffixIcon: hasError
            ? Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20,
              )
            : suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// Common dropdown field builder for login screens
/// A specialized dropdown field component for selecting databases on login screens.
class LoginDropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;
  final bool hasError;
  final AutovalidateMode? autovalidateMode;

  const LoginDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.validator,
    this.hasError = false,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : null;
    final bool isEnabled = onChanged != null;

    return Theme(
      data: Theme.of(context).copyWith(
        // Customize dropdown menu theme for better positioning and styling
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Circular border radius
          ),
          elevation: 8,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        // Customize dropdown button theme
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // Circular border radius
              ),
            ),
            elevation: MaterialStateProperty.all(8),
            backgroundColor: MaterialStateProperty.all(Colors.white),
            surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
          ),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        items: uniqueItems.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        autovalidateMode: autovalidateMode,
        // Improved dropdown positioning and styling
        menuMaxHeight: 200, // Limit dropdown height
        borderRadius: BorderRadius.circular(16), // Circular border radius for dropdown
        dropdownColor: Colors.white,
        elevation: 8,
        // Custom icon with better positioning
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isEnabled ? Colors.black54 : Colors.black26,
          size: 20,
        ),
        iconSize: 20,
        isExpanded: true, // Make dropdown take full width
        hint: Text(
          hint,
          style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black.withOpacity(.4)),
        ),
        decoration: InputDecoration(
          enabled: isEnabled,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedDatabase,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          prefixIconColor: MaterialStateColor.resolveWith(
            (states) => states.contains(MaterialState.disabled)
                ? Colors.black26
                : Colors.black54,
          ),
          suffixIcon: (hasError && (safeValue == null || safeValue.isEmpty))
              ? HugeIcon(icon:
                  HugeIcons.strokeRoundedAlertCircle,
                  color: Colors.red[900],
                  size: 20,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class LoginErrorDisplay extends StatelessWidget {
  final String? error;

  const LoginErrorDisplay({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: error != null
            ? Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HugeIcon(icon:HugeIcons.strokeRoundedAlertCircle,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// URL text field with integrated protocol dropdown and history
/// A specialized text field for entering server URLs with protocol selection and history support.
class LoginUrlTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final List<List<dynamic>> prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;
  final String selectedProtocol;
  final ValueChanged<String>? onProtocolChanged;
  final List<String> urlHistory; // Add URL history parameter for suggestions
  final bool isLoading; // Add loading state parameter

  const LoginUrlTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
    this.selectedProtocol = 'https://',
    this.onProtocolChanged,
    this.urlHistory = const [], // Default empty list
    this.isLoading = false, // Default not loading
  });

  @override
  State<LoginUrlTextField> createState() => _LoginUrlTextFieldState();
}

class _LoginUrlTextFieldState extends State<LoginUrlTextField> {
  late FocusNode _focusNode;
  bool _showDropdown = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    // Remove overlay entry without calling setState
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
     
    // Clean up focus node
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.urlHistory.isNotEmpty && widget.enabled) {
      _showHistoryDropdown();
    } else {
      _hideDropdown();
    }
  }

  void _showHistoryDropdown() {
    if (_overlayEntry != null) return;
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _showDropdown = true;
    });
  }

  void _hideDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    if (mounted) {
      setState(() {
        _showDropdown = false;
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    
    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 200,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: widget.urlHistory.length,
                itemBuilder: (context, index) {
                  final url = widget.urlHistory[index];
                  String displayUrl = url;
                  if (url.startsWith('https://')) {
                    displayUrl = url.substring(8);
                  } else if (url.startsWith('http://')) {
                    displayUrl = url.substring(7);
                  }
                  
                  return InkWell(
                    onTap: () {
                      _selectUrl(url);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              displayUrl,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectUrl(String selectedUrl) {
    // Extract protocol and clean URL
    String protocol = 'https://';
    String cleanUrl = selectedUrl;
    
    if (selectedUrl.startsWith('https://')) {
      protocol = 'https://';
      cleanUrl = selectedUrl.substring(8);
    } else if (selectedUrl.startsWith('http://')) {
      protocol = 'http://';
      cleanUrl = selectedUrl.substring(7);
    }
    
    // Hide dropdown first
    _hideDropdown();
    
    // Update protocol and URL
    widget.onProtocolChanged?.call(protocol);
    widget.controller.text = cleanUrl;
    widget.onChanged?.call(cleanUrl);
    
    // Remove focus after a short delay to ensure dropdown is hidden
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNode.unfocus();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
            link: _layerLink,
            child: TextFormField(
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            validator: widget.validator,
            autovalidateMode: widget.autovalidateMode,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withOpacity(.4)),
              prefixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Server icon
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: HugeIcon(icon: 
                      widget.prefixIcon,
                      size: 20,
                      color: widget.enabled ? Colors.black54 : Colors.black26,
                    ),
                  ),
                  // Protocol dropdown
                  Container(
                    height: 48, // Match the input field height
                    width: 72, // Fixed width to contain within divider
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Colors.black.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      enabled: widget.enabled,
                      initialValue: widget.selectedProtocol,
                      padding: EdgeInsets.zero,
                      position: PopupMenuPosition.under,
                      color: Colors.white,
                      constraints: const BoxConstraints(
                        minWidth: 72,
                        maxWidth: 72,
                      ),
                      itemBuilder: (context) => ['http://', 'https://']
                          .map((p) => PopupMenuItem<String>(
                                value: p,
                                child: Text(
                                  p,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ))
                          .toList(),
                      onSelected: (value) => widget.onProtocolChanged?.call(value),
                      child: Container(
                        height: 48, // Match the input field height
                        width: 85, // Fixed width
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center, // Center align the content
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.selectedProtocol,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: widget.enabled ? Colors.black : Colors.black26,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: widget.enabled ? Colors.black54 : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show loading indicator when validating
                  if (widget.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                        ),
                      ),
                    )
                  // Show dropdown indicator when history is available and not loading
                  else if (widget.urlHistory.isNotEmpty && widget.enabled)
                    Icon(
                      _showDropdown ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.black54,
                    ),
                  // Error icon
                  if (widget.hasError && !widget.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.only(
                left: 0,
                right: 20,
                top: 16,
                bottom: 16,
              ),
            ),
          ),
        ),
        // Show URL history count if available
        // if (widget.urlHistory.isNotEmpty && widget.enabled)
        //   Padding(
        //     padding: const EdgeInsets.only(top: 4, left: 4),
        //     child: Text(
        //       '${widget.urlHistory.length} recent server${widget.urlHistory.length == 1 ? '' : 's'} available - tap to select',
        //       style: GoogleFonts.manrope(
        //         fontSize: 11,
        //         fontWeight: FontWeight.w400,
        //         color: Colors.white70,
        //       ),
        //     ),
        //   ),
      ],
    );
  }
}

// Common button widget
class LoginButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? loadingWidget;
  final bool isEnabled; // Add enabled state parameter

  const LoginButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingWidget,
    this.isEnabled = true, // Default to enabled
  });

  @override
  Widget build(BuildContext context) {
    // Determine if button should be interactive
    final bool isInteractive = isEnabled && !isLoading && onPressed != null;
    
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isInteractive ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isInteractive ? Colors.black : Colors.black.withOpacity(0.3),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withOpacity(0.2),
          disabledForegroundColor: Colors.white,
          overlayColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading && loadingWidget != null
            ? loadingWidget!
            : Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // Keep text always white/full opacity
                ),
              ),
      ),
    );
  }
}
