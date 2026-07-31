import 'package:flutter/material.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/models/models.dart';
import 'package:student_activities/services/api_client.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetAllocation> _allocations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ApiClient.instance.get('/budget');
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'Unable to load budget data.';
      });
      return;
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    final allocations = (payload['data'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              BudgetAllocation.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    setState(() {
      _allocations = allocations;
      _loading = false;
    });
  }

  int get _totalBudget =>
      _allocations.fold(0, (sum, item) => sum + item.totalBudget);
  int get _totalStudents =>
      _allocations.fold(0, (sum, item) => sum + item.students);

  Map<String, List<BudgetAllocation>> get _byHouse {
    final values = <String, List<BudgetAllocation>>{};
    for (final allocation in _allocations) {
      values
          .putIfAbsent(
            allocation.house.isEmpty ? 'Unassigned' : allocation.house,
            () => [],
          )
          .add(allocation);
    }
    return values;
  }

  String _money(int value) {
    final digits = value.toString();
    final parts = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      parts.insert(0, digits.substring(end - 3 < 0 ? 0 : end - 3, end));
    }
    return '₹${parts.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator(message: 'Loading budget');
    if (_error != null) {
      return ErrorDisplay(message: _error!, onRetry: _loadBudget);
    }
    if (_allocations.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No budget data available',
      );
    }
    final groups = _byHouse.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return RefreshIndicator(
      onRefresh: _loadBudget,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Row(
            children: [
              Expanded(
                child: _Summary(
                  value: _money(_totalBudget),
                  label: 'Total allocation',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Summary(
                  value: '$_totalStudents',
                  label: 'Students covered',
                  icon: Icons.groups_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'House allocations'),
          ...groups.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HouseAllocation(
                house: entry.key,
                allocations: entry.value,
                money: _money,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 18),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _HouseAllocation extends StatelessWidget {
  const _HouseAllocation({
    required this.house,
    required this.allocations,
    required this.money,
  });

  final String house;
  final List<BudgetAllocation> allocations;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    final total = allocations.fold(0, (sum, item) => sum + item.totalBudget);
    final students = allocations.fold(0, (sum, item) => sum + item.students);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.home_work_outlined,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(house, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text('$students students · ${money(total)}'),
        children: allocations
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.region.isEmpty ? 'All regions' : item.region),
                subtitle: Text(
                  '${item.students} students · Equal ${money(item.equalShare)} · Proportional ${money(item.propShare)}',
                ),
                trailing: Text(
                  money(item.totalBudget),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
