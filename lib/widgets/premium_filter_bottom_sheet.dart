import 'package:flutter/material.dart';

import '../core/style.dart';

/// Represents a single filter option (chip / radio choice).
class FilterOption {
  final String title;
  bool value;

  FilterOption({required this.title, required this.value});
}

/// Logical grouping of related filter options (e.g. "Status").
class FilterGroup {
  final String title;
  final List<FilterOption> options;

  FilterGroup({required this.title, required this.options});
}

/// Filter & Group By bottom sheet — same design as the Mobo CRM app's
/// `PremiumFilterBottomSheet`: a drag handle, a header with a close button,
/// a segmented Filter/Group By tab bar, chip-style filter options with an
/// "Active Filters" summary, a single-selection Group By list (with a
/// "None" option), and a Clear All / Apply footer.
class PremiumFilterBottomSheet extends StatefulWidget {
  final List<FilterGroup> filterGroups;
  final List<FilterGroup> groupByOptions;
  final Function(Map<String, dynamic>) onApply;
  final String title;
  final Color primaryColor;

  const PremiumFilterBottomSheet({
    super.key,
    required this.filterGroups,
    this.groupByOptions = const [],
    required this.onApply,
    this.title = 'Filters',
    this.primaryColor = AppStyle.primaryColor,
  });

  /// Convenience method to show the bottom sheet
  static void show({
    required BuildContext context,
    required List<FilterGroup> filterGroups,
    List<FilterGroup> groupByOptions = const [],
    required Function(Map<String, dynamic>) onApply,
    String title = 'Filters',
    Color primaryColor = AppStyle.primaryColor,
  }) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PremiumFilterBottomSheet(
          filterGroups: filterGroups,
          groupByOptions: groupByOptions,
          onApply: onApply,
          title: title,
          primaryColor: primaryColor,
        );
      },
    );
  }

  @override
  State<PremiumFilterBottomSheet> createState() => _PremiumFilterBottomSheetState();
}

class _PremiumFilterBottomSheetState extends State<PremiumFilterBottomSheet>
    with TickerProviderStateMixin {
  late List<FilterGroup> _tempFilterGroups;
  late List<FilterGroup> _tempGroupByOptions;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _tempFilterGroups = widget.filterGroups
        .map((g) => FilterGroup(
              title: g.title,
              options: g.options.map((o) => FilterOption(title: o.title, value: o.value)).toList(),
            ))
        .toList();

    _tempGroupByOptions = widget.groupByOptions
        .map((g) => FilterGroup(
              title: g.title,
              options: g.options.map((o) => FilterOption(title: o.title, value: o.value)).toList(),
            ))
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectValues() {
    final result = <String, dynamic>{};
    for (final group in _tempFilterGroups) {
      final prefix = '${group.title.toLowerCase().replaceAll(' ', '_')}_';
      for (final option in group.options) {
        result['$prefix${option.title.toLowerCase().replaceAll(' ', '_')}'] = option.value;
      }
    }
    for (final group in _tempGroupByOptions) {
      final prefix = '${group.title.toLowerCase().replaceAll(' ', '_')}_';
      for (final option in group.options) {
        result['$prefix${option.title.toLowerCase().replaceAll(' ', '_')}'] = option.value;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          _buildHeader(isDark),
          _buildTabBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFiltersTab(isDark), _buildGroupByTab(isDark)],
            ),
          ),
          _buildBottomActions(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title == 'Filters' ? 'Filter & Group By' : widget.title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSelections(bool isDark) {
    final filterCounts = <String, int>{};
    for (final group in _tempFilterGroups) {
      final count = group.options.where((o) => o.value).length;
      if (count > 0) filterCounts[group.title] = count;
    }

    if (filterCounts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: filterCounts.entries.map((entry) {
              return _buildActiveChip(
                label: '${entry.key} (${entry.value})',
                isDark: isDark,
                onRemove: () {
                  setState(() {
                    for (final group in _tempFilterGroups) {
                      if (group.title == entry.key) {
                        for (final option in group.options) {
                          option.value = false;
                        }
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChip({
    required String label,
    required bool isDark,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: widget.primaryColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: widget.primaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(height: 48, text: 'Filter'),
          Tab(height: 48, text: 'Group By'),
        ],
      ),
    );
  }

  Widget _buildFiltersTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveSelections(isDark),
          ...List.generate(_tempFilterGroups.length, (i) => _buildFilterGroup(i, isDark)),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(int groupIndex, bool isDark) {
    final group = _tempFilterGroups[groupIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            group.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              group.options.length,
              (optionIndex) => _buildChipOption(groupIndex, optionIndex, isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipOption(int groupIndex, int optionIndex, bool isDark) {
    final option = _tempFilterGroups[groupIndex].options[optionIndex];
    return ChoiceChip(
      label: Text(
        option.title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: option.value ? FontWeight.w600 : FontWeight.w400,
          color: option.value ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: option.value,
      selectedColor: widget.primaryColor,
      backgroundColor: widget.primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: option.value ? widget.primaryColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      onSelected: (val) => setState(() => option.value = val),
      showCheckmark: false,
    );
  }

  Widget _buildGroupByTab(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group shops by',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            _buildNoneGroupByOption(isDark),
            const SizedBox(height: 10),
            Divider(color: isDark ? Colors.grey[700] : Colors.grey[300], thickness: 1, height: 1),
            const SizedBox(height: 10),
            ...List.generate(_tempGroupByOptions.length, (i) => _buildGroupByGroup(i, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoneGroupByOption(bool isDark) {
    final isNoneSelected = _tempGroupByOptions.every((g) => g.options.every((o) => !o.value));

    return Material(
      color: Colors.transparent,
      child: RadioListTile<bool>(
        title: Text(
          'None',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Display as a simple list',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
        ),
        value: true,
        groupValue: isNoneSelected,
        onChanged: (value) {
          setState(() {
            for (final group in _tempGroupByOptions) {
              for (final option in group.options) {
                option.value = false;
              }
            }
          });
        },
        activeColor: widget.primaryColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildGroupByGroup(int groupIndex, bool isDark) {
    final group = _tempGroupByOptions[groupIndex];
    return Column(
      children: List.generate(group.options.length, (i) => _buildGroupByOption(groupIndex, i, isDark)),
    );
  }

  Widget _buildGroupByOption(int groupIndex, int optionIndex, bool isDark) {
    final option = _tempGroupByOptions[groupIndex].options[optionIndex];

    return Material(
      color: Colors.transparent,
      child: RadioListTile<bool>(
        title: Text(
          option.title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
        ),
        value: true,
        groupValue: option.value,
        onChanged: (value) {
          setState(() {
            for (final grp in _tempGroupByOptions) {
              for (final opt in grp.options) {
                opt.value = false;
              }
            }
            option.value = true;
          });
        },
        activeColor: widget.primaryColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBottomActions(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        border: Border(top: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    for (final group in _tempFilterGroups) {
                      for (final option in group.options) {
                        option.value = false;
                      }
                    }
                    for (final group in _tempGroupByOptions) {
                      for (final option in group.options) {
                        option.value = false;
                      }
                    }
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.primaryColor,
                  side: BorderSide(color: widget.primaryColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final values = _collectValues();
                  widget.onApply(values);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
