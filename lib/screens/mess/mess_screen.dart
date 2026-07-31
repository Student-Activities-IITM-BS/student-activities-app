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
    'unifiedVeg': 'Unified Menu - Veg',
    'unifiedNonVeg': 'Unified Menu - Non-Veg',
    'northVeg': 'North Indian - Veg',
    'northNonVeg': 'North Indian - Non-Veg',
    'southVeg': 'South Indian - Veg',
    'southNonVeg': 'South Indian - Non-Veg',
    'jain': 'Jain / Pure Veg',
    'proteinMessVeg': 'Protein Mess - Veg',
    'proteinMessNonVeg': 'Protein Mess - Non-Veg',
  };
  static const _mealOrder = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];
  Map<String, dynamic>? _data;
  DateTime _selectedDate = DateTime.now();
  String _menuKey = 'unifiedVeg';

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

  String get _weekLetter {
    final start = DateTime(2026, 3, 30);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
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
    final data = _data;
    if (data == null) return {};
    final menus = Map<String, dynamic>.from(data['menuData'] as Map);
    final menu = menus[_menuKey] is Map
        ? Map<String, dynamic>.from(menus[_menuKey] as Map)
        : const <String, dynamic>{};
    final weeks = menu['weeks'] is Map
        ? Map<String, dynamic>.from(menu['weeks'] as Map)
        : const <String, dynamic>{};
    final week = weeks[_weekLetter] is Map
        ? Map<String, dynamic>.from(weeks[_weekLetter] as Map)
        : const <String, dynamic>{};
    final day = week[_dayName] is Map
        ? Map<String, dynamic>.from(week[_dayName] as Map)
        : const <String, dynamic>{};
    final common = data['commonItems'] is Map
        ? Map<String, dynamic>.from(data['commonItems'] as Map)
        : const <String, dynamic>{};
    return {
      for (final meal in _mealOrder)
        meal: [
          ...((day[meal] as List<dynamic>? ?? const []).map(
            (item) => item.toString(),
          )),
          ...((common[meal] as List<dynamic>? ?? const []).map(
            (item) => item.toString(),
          )),
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
                    firstDate: DateTime(2026, 1, 1),
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
              child: Text(
                'Week $_weekLetter · $_dayName',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge,
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
