import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/printer_service.dart';

/// Configuration screen for the receipt printer (Landi M20 built-in head or a
/// networked ESC/POS printer). Persists via [PrinterService] / SharedPreferences.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  static const Color _accent = Color(0xFFC03355);

  final PrinterService _service = PrinterService();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  bool _loading = true;
  bool _testing = false;
  bool _builtinAvailable = false;

  bool _enabled = false;
  PrinterMode _mode = PrinterMode.builtin;
  int _paperWidth = 58;
  bool _autoPrint = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final PrinterConfig config = await _service.loadConfig();
    final bool builtin = await _service.isBuiltinAvailable();
    if (!mounted) return;
    setState(() {
      _enabled = config.enabled;
      _mode = config.mode;
      _paperWidth = config.paperWidthMm;
      _autoPrint = config.autoPrint;
      _addressController.text = config.address;
      _portController.text = config.port.toString();
      _builtinAvailable = builtin;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final int port = int.tryParse(_portController.text.trim()) ?? 9100;
    await _service.saveConfig(PrinterConfig(
      enabled: _enabled,
      mode: _mode,
      address: _addressController.text.trim(),
      port: port,
      paperWidthMm: _paperWidth,
      autoPrint: _autoPrint,
    ));
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    await _save();
    final PrintResult result = await _service.testPrint();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Test receipt sent'
            : 'Test failed: ${result.message}'),
        backgroundColor: result.success ? _accent : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Receipt Printer',
            style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01, color: textColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(isDark, [
                  SwitchListTile(
                    value: _enabled,
                    activeColor: _accent,
                    title: Text('Enable receipt printing',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, color: textColor)),
                    subtitle: Text(
                      'Print receipts from the POS to a thermal printer',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    onChanged: (bool v) async {
                      setState(() => _enabled = v);
                      await _save();
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Printer type', textColor),
                _card(isDark, [
                  RadioListTile<PrinterMode>(
                    value: PrinterMode.builtin,
                    groupValue: _mode,
                    activeColor: _accent,
                    title: Text('Built-in (Landi M20)',
                        style: TextStyle(color: textColor)),
                    subtitle: Text(
                      _builtinAvailable
                          ? 'Device printer detected'
                          : 'Uses the terminal\'s built-in thermal head',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    onChanged: (PrinterMode? v) async {
                      setState(() => _mode = v!);
                      await _save();
                    },
                  ),
                  RadioListTile<PrinterMode>(
                    value: PrinterMode.network,
                    groupValue: _mode,
                    activeColor: _accent,
                    title: Text('Network (ESC/POS over Wi-Fi)',
                        style: TextStyle(color: textColor)),
                    subtitle: Text(
                      'A standalone printer at an IP address',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    onChanged: (PrinterMode? v) async {
                      setState(() => _mode = v!);
                      await _save();
                    },
                  ),
                ]),
                if (_mode == PrinterMode.network) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('Network printer', textColor),
                  _card(isDark, [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _addressController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor),
                            decoration: _inputDecoration(
                                'IP address', 'e.g. 192.168.1.100', isDark),
                            onChanged: (_) => _save(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor),
                            decoration:
                                _inputDecoration('Port', '9100', isDark),
                            onChanged: (_) => _save(),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 16),
                _sectionLabel('Paper width', textColor),
                _card(isDark, [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 58, label: Text('58 mm')),
                        ButtonSegment<int>(value: 80, label: Text('80 mm')),
                      ],
                      selected: {_paperWidth},
                      onSelectionChanged: (Set<int> s) async {
                        setState(() => _paperWidth = s.first);
                        await _save();
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _card(isDark, [
                  SwitchListTile(
                    value: _autoPrint,
                    activeColor: _accent,
                    title: Text('Auto-print after payment',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, color: textColor)),
                    subtitle: Text(
                      'Print automatically when an order receipt is shown',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    onChanged: (bool v) async {
                      setState(() => _autoPrint = v);
                      await _save();
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _testing ? null : _testPrint,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print),
                    label: Text(_testing ? 'Printing…' : 'Print test receipt'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7))),
      );

  Widget _card(bool isDark, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      );

  InputDecoration _inputDecoration(String label, String hint, bool isDark) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent),
        ),
      );
}
