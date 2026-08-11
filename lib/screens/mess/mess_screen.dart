import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student_activities/core/widgets.dart';

class MessScreen extends StatefulWidget {
  const MessScreen({super.key});

  @override
  State<MessScreen> createState() => _MessScreenState();
}

class _MessScreenState extends State<MessScreen> {
  static const _labels = <String, String>{
    'Unified_Veg': 'Unified Menu - Veg',
    'Unified_Non_Veg': 'Unified Menu - Non-Veg',
    'North_Veg': 'North Indian - Veg',
    'North_Non_Veg': 'North Indian - Non-Veg',
    'South_Veg': 'South Indian - Veg',
    'South_Non_Veg': 'South Indian - Non-Veg',
    'North_Veg_No_Onion_Garlic': 'North Indian - Veg (No Onion/Garlic)',
    'Protein_Veg': 'Protein Mess - Veg',
    'Protein_Non_Veg': 'Protein Mess - Non-Veg',
  };
  static const _mealOrder = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];
  Map<String, dynamic>? _data;
  DateTime _selectedDate = DateTime.now();
  String _menuKey = 'Unified_Veg';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await rootBundle.loadString('assets/menu_data.json');
    if (!mounted) return;
    setState(() => _data = Map<String, dynamic>.from(jsonDecode(text) as Map));
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
  }

  static DateTime? _parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String get _versionKey {
    final versions = _asMap(_data?['versions']);
    final keys = versions.keys.map((key) => key.toString()).toList()..sort();
    if (keys.isEmpty) return '';

    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    var selectedKey = keys.first;
    for (final key in keys) {
      final date = _parseDate(key);
      if (date != null && !date.isAfter(selected)) selectedKey = key;
    }
    return selectedKey;
  }

  Map<String, dynamic> get _category {
    final versions = _asMap(_data?['versions']);
    final version = _asMap(versions[_versionKey]);
    final messMenu = _asMap(version['Messmenu']);
    final categories = _asMap(messMenu['Categories']);
    return _asMap(categories[_menuKey]);
  }

  String get _weekLetter {
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final cycles = _data?['cycles'];
    var start = DateTime(2026, 4, 1);
    if (cycles is List) {
      DateTime? firstStart;
      DateTime? latestStart;
      for (final rawCycle in cycles) {
        final cycle = _asMap(rawCycle);
        final cycleStart = _parseDate(cycle['startDate']?.toString() ?? '');
        if (cycleStart == null) continue;
        firstStart ??= cycleStart;
        if (!cycleStart.isAfter(selected)) latestStart = cycleStart;
      }
      start = latestStart ?? firstStart ?? start;
    }
    final days = selected.difference(start).inDays;
    const weeks = ['A', 'B', 'C', 'D'];
    return weeks[((days ~/ 7) % 4 + 4) % 4];
  }

  String get _dayName => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][_selectedDate.weekday - 1];

  String get _cycleName {
    final cycles = _data?['cycles'];
    if (cycles is! List) return '';
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    for (final rawCycle in cycles) {
      final cycle = _asMap(rawCycle);
      final start = _parseDate(cycle['startDate']?.toString() ?? '');
      final end = _parseDate(cycle['endDate']?.toString() ?? '');
      if (start != null &&
          end != null &&
          !selected.isBefore(start) &&
          !selected.isAfter(end)) {
        return cycle['name']?.toString() ?? '';
      }
    }
    return '';
  }

  String? get _currentMeal {
    if (!DateUtils.isSameDay(_selectedDate, DateTime.now())) return null;
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 10) return 'Breakfast';
    if (hour >= 10 && hour < 15) return 'Lunch';
    if (hour >= 15 && hour < 18) return 'Snacks';
    if (hour >= 18 && hour < 22) return 'Dinner';
    return null;
  }

  Map<String, List<String>> get _meals {
    if (_data == null) return {};
    final week = _asMap(_category[_weekLetter]);
    final schedule = _asMap(week['schedule']);
    final day = _asMap(schedule[_dayName]);
    final common = _asMap(_category['common_items']);
    return {
      for (final meal in _mealOrder)
        meal: [
          ...((day[meal] is List ? day[meal] as List : const []).map(
            (item) => item.toString(),
          )),
          if (common[meal] is String &&
              (common[meal] as String).trim().isNotEmpty)
            common[meal] as String,
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const LoadingIndicator(message: 'Loading mess menu');
    }
    final meals = _meals;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2026, 4, 1),
                    lastDate: DateTime(2030, 12, 31),
                    initialDate: _selectedDate,
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Week $_weekLetter · $_dayName',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (_cycleName.isNotEmpty)
                    Text(
                      _cycleName,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _menuKey,
          isExpanded: true,
          items: _labels.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (key) {
            if (key != null) setState(() => _menuKey = key);
          },
          decoration: const InputDecoration(labelText: 'Mess menu'),
        ),
        const SizedBox(height: 20),
        ..._mealOrder.map(
          (meal) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MealCard(
              meal: meal,
              items: meals[meal] ?? const [],
              current: _currentMeal == meal,
            ),
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.items,
    required this.current,
  });
  final String meal;
  final List<String> items;
  final bool current;

  IconData get _icon => switch (meal) {
    'Breakfast' => Icons.wb_sunny_outlined,
    'Lunch' => Icons.lunch_dining_outlined,
    'Snacks' => Icons.cookie_outlined,
    _ => Icons.nightlight_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icon,
                color: current ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(meal, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (current) StatusChip(label: 'Now', color: scheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'Menu not available',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '• ${item.replaceAll('*', '')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
