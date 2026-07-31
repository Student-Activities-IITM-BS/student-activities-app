import 'package:flutter/material.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/services/api_client.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key, this.slug});

  final String? slug;

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _controllers = {};
  Map<String, dynamic>? _payload;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    var slug = widget.slug;
    if (slug == null || slug.isEmpty) {
      final active = await ApiClient.instance.get('/recruitment/active');
      if (!mounted) return;
      if (!active.success) {
        setState(() {
          _loading = false;
          _error = active.error ?? 'Unable to load recruitment.';
        });
        return;
      }
      if (active.data == null) {
        setState(() {
          _payload = const {};
          _loading = false;
        });
        return;
      }
      final activeData = active.data is Map
          ? Map<String, dynamic>.from(active.data as Map)
          : const <String, dynamic>{};
      slug = activeData['slug']?.toString();
    }
    if (slug == null || slug.isEmpty) {
      setState(() {
        _payload = const {};
        _loading = false;
      });
      return;
    }
    final response = await ApiClient.instance.get('/recruitment/$slug');
    if (!mounted) return;
    if (!response.success || response.data is! Map) {
      setState(() {
        _loading = false;
        _error = response.error ?? 'Unable to load this recruitment.';
      });
      return;
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    final application = payload['application'] is Map
        ? Map<String, dynamic>.from(payload['application'] as Map)
        : const <String, dynamic>{};
    final answers = application['answers'] is Map
        ? Map<String, dynamic>.from(application['answers'] as Map)
        : const <String, dynamic>{};
    _answers
      ..clear()
      ..addAll(answers);
    setState(() {
      _payload = payload;
      _loading = false;
    });
  }

  Map<String, dynamic> get _recruitment => _payload?['recruitment'] is Map
      ? Map<String, dynamic>.from(_payload!['recruitment'] as Map)
      : const <String, dynamic>{};
  Map<String, dynamic> get _form => _payload?['form'] is Map
      ? Map<String, dynamic>.from(_payload!['form'] as Map)
      : const <String, dynamic>{};
  Map<String, dynamic> get _identity => _payload?['identity'] is Map
      ? Map<String, dynamic>.from(_payload!['identity'] as Map)
      : const <String, dynamic>{};
  bool get _open => _recruitment['is_open'] == true;

  bool _visible(Map<String, dynamic> value) {
    final showIf = value['showIf'] is Map
        ? Map<String, dynamic>.from(value['showIf'] as Map)
        : null;
    if (showIf == null) return true;
    final selected = _answers[showIf['field']?.toString()];
    final expected = showIf['in'] is List
        ? (showIf['in'] as List).map((item) => item.toString()).toSet()
        : <String>{};
    return expected.contains(selected?.toString());
  }

  TextEditingController _controller(String id) => _controllers.putIfAbsent(
    id,
    () => TextEditingController(text: _answers[id]?.toString() ?? ''),
  );

  List<Map<String, dynamic>> _fields(Map<String, dynamic> section) =>
      (section['fields'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<void> _submit() async {
    final missing = <String>[];
    for (final sectionRaw in _form['sections'] as List<dynamic>? ?? const []) {
      final section = Map<String, dynamic>.from(sectionRaw as Map);
      if (!_visible(section)) continue;
      for (final field in _fields(section)) {
        if (!_visible(field) ||
            field['serverFilled'] == true ||
            field['required'] != true) {
          continue;
        }
        final value = _answers[field['id']?.toString()];
        final blank =
            value == null ||
            value is String && value.trim().isEmpty ||
            value is List && value.isEmpty;
        if (blank) missing.add(field['label']?.toString() ?? 'Required field');
      }
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Complete: ${missing.first}')));
      return;
    }
    final slug = _recruitment['slug']?.toString();
    if (slug == null) return;
    setState(() => _saving = true);
    final response = await ApiClient.instance.post(
      '/recruitment/$slug',
      body: {'answers': _answers},
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Could not save application.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Application saved.')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator(message: 'Loading recruitment');
    if (_error != null) return ErrorDisplay(message: _error!, onRetry: _load);
    if (_payload?.isEmpty == true) {
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No recruitment is open right now',
      );
    }
    final sections = (_form['sections'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where(_visible)
        .toList();
    final application = _payload?['application'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      children: [
        Text(
          _recruitment['title']?.toString() ?? 'Recruitment',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (_recruitment['closes_at']?.toString().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            'Closes ${_dateLabel(_recruitment['closes_at']?.toString())}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (!_open) ...[
          const SizedBox(height: 16),
          AppCard(
            child: Text(
              application is Map
                  ? 'This recruitment is closed. Your saved answers are shown below.'
                  : 'This recruitment is closed.',
            ),
          ),
        ],
        if (_identity.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'Your details'),
          AppCard(
            child: Column(
              children: [
                _IdentityRow(
                  label: 'Name',
                  value: _identity['name']?.toString() ?? '',
                ),
                const Divider(),
                _IdentityRow(
                  label: 'Email',
                  value: _identity['email']?.toString() ?? '',
                ),
                if (_identity['house']?.toString().isNotEmpty == true) ...[
                  const Divider(),
                  _IdentityRow(
                    label: 'House',
                    value: _identity['house'].toString(),
                  ),
                ],
              ],
            ),
          ),
        ],
        ...sections.map(
          (section) => _Section(
            section: section,
            read: (id) => _answers[id],
            write: (id, value) => setState(() => _answers[id] = value),
            controllerFor: _controller,
            visible: _visible,
            enabled: _open,
          ),
        ),
        const SizedBox(height: 20),
        if (_open)
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Save application'),
          ),
      ],
    );
  }

  String _dateLabel(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    return date == null
        ? value ?? ''
        : '${date.day}/${date.month}/${date.year}';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.read,
    required this.write,
    required this.controllerFor,
    required this.visible,
    required this.enabled,
  });
  final Map<String, dynamic> section;
  final dynamic Function(String id) read;
  final void Function(String id, dynamic value) write;
  final TextEditingController Function(String id) controllerFor;
  final bool Function(Map<String, dynamic>) visible;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fields = (section['fields'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where(visible)
        .toList();
    if (fields.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section['title']?.toString() ?? 'Questions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (section['description']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              section['description'].toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: fields
                  .map(
                    (field) => _Field(
                      field: field,
                      value: read(field['id']?.toString() ?? ''),
                      onChanged: (value) =>
                          write(field['id']?.toString() ?? '', value),
                      controllerFor: controllerFor,
                      enabled: enabled,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.controllerFor,
    required this.enabled,
  });
  final Map<String, dynamic> field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final TextEditingController Function(String id) controllerFor;
  final bool enabled;

  String get _id => field['id']?.toString() ?? '';
  String get _type => field['type']?.toString() ?? 'text';
  String get _label =>
      '${field['label']?.toString() ?? 'Question'}${field['required'] == true ? ' *' : ''}';
  List<String> get _options => (field['options'] as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .toList();

  @override
  Widget build(BuildContext context) {
    if (field['serverFilled'] == true) return const SizedBox.shrink();
    final helper = field['help']?.toString();
    if (_type == 'checkbox') {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: value == true,
        onChanged: enabled ? onChanged : null,
        title: Text(_label),
        subtitle: helper == null ? null : Text(helper),
      );
    }
    if (_type == 'select') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: _options.contains(value?.toString())
              ? value.toString()
              : null,
          items: _options
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(),
          onChanged: (selected) {
            if (enabled) {
              onChanged(selected);
            }
          },
          decoration: InputDecoration(labelText: _label, helperText: helper),
        ),
      );
    }
    if (_type == 'radio') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: RadioGroup<String>(
          groupValue: value?.toString(),
          onChanged: (String? selected) {
            if (enabled) {
              onChanged(selected);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_label, style: Theme.of(context).textTheme.labelLarge),
              if (helper != null)
                Text(helper, style: Theme.of(context).textTheme.bodySmall),
              ..._options.map(
                (option) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: option,
                  enabled: enabled,
                  title: Text(option),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_type == 'date') {
      final display = value?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: OutlinedButton.icon(
          onPressed: !enabled
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1950),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.tryParse(display) ?? DateTime.now(),
                  );
                  if (picked != null) {
                    onChanged(
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                    );
                  }
                },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(display.isEmpty ? _label : '$_label: $display'),
        ),
      );
    }
    if (_type == 'rating-matrix') {
      final rows = (field['rows'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();
      final values = value is Map
          ? Map<String, dynamic>.from(value as Map)
          : <String, dynamic>{};
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label, style: Theme.of(context).textTheme.labelLarge),
            if (helper != null)
              Text(helper, style: Theme.of(context).textTheme.bodySmall),
            ...rows.map(
              (row) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row),
                  Slider(
                    value: (values[row] is num ? values[row] as num : 3)
                        .toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '${values[row] ?? 3}',
                    onChanged: enabled
                        ? (rating) =>
                              onChanged({...values, row: rating.round()})
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final controller = controllerFor(_id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: _type == 'number'
            ? TextInputType.number
            : _type == 'email' || _type == 'url'
            ? TextInputType.url
            : TextInputType.text,
        minLines: _type == 'textarea' ? 4 : 1,
        maxLines: _type == 'textarea' ? 8 : 1,
        maxLength: field['max'] is num ? (field['max'] as num).toInt() : null,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: _label, helperText: helper),
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(value, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}
