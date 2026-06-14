import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/app_theme.dart';

/// Pantalla CRUD genérica — igual al AdminTable.vue
class AdminCrudScreen extends StatefulWidget {
  final String title;
  final String endpoint;
  final List<AdminColumn> columns;
  final Map<String, dynamic> Function()? defaultForm;

  const AdminCrudScreen({
    super.key,
    required this.title,
    required this.endpoint,
    required this.columns,
    this.defaultForm,
  });

  @override
  State<AdminCrudScreen> createState() => _AdminCrudScreenState();
}

class _AdminCrudScreenState extends State<AdminCrudScreen> {
  List<dynamic> _items = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await dio.get(widget.endpoint);
      final data = res.data['data'];
      setState(() {
        _items = data is List ? data : [data];
        _applySearch();
      });
    } catch (_) {
      setState(() => _items = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applySearch() {
    if (_search.isEmpty) { _filtered = List.from(_items); return; }
    final q = _search.toLowerCase();
    _filtered = _items.where((item) =>
      widget.columns.any((col) =>
        '${item[col.key] ?? ''}'.toLowerCase().contains(q)
      )
    ).toList();
  }

  Future<void> _delete(dynamic item) async {
    final id = item['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Seguro que deseas eliminar este registro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await dio.delete('${widget.endpoint}/$id');
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar'), backgroundColor: AppColors.red));
      }
    }
  }

  void _openForm({dynamic item}) {
    showDialog(
      context: context,
      builder: (_) => _FormDialog(
        title: item == null ? 'Agregar ${widget.title}' : 'Editar ${widget.title}',
        columns: widget.columns,
        initial: item,
        onSave: (data) async {
          try {
            if (item == null) {
              await dio.post(widget.endpoint, data: data);
            } else {
              await dio.put('${widget.endpoint}/${item['id']}', data: data);
            }
            _load();
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error al guardar'), backgroundColor: AppColors.red));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(children: [
            Text(widget.title, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const Spacer(),
            SizedBox(
              width: 220,
              child: TextField(
                onChanged: (v) => setState(() { _search = v; _applySearch(); }),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: Text('Agregar ${widget.title}'),
            ),
          ]),
        ),
        const Divider(height: 1),
        // Tabla
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(child: Text('Sin registros'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: [
                            ...widget.columns.map((c) => DataColumn(
                              label: Text(c.label, style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)))),
                            const DataColumn(label: Text('Acciones',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                          ],
                          rows: _filtered.map((item) => DataRow(
                            cells: [
                              ...widget.columns.map((c) => DataCell(
                                Text('${item[c.key] ?? '—'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: c.mono ? 'monospace' : null,
                                    color: c.primary ? AppColors.primary : const Color(0xFF1E293B),
                                    fontWeight: c.primary ? FontWeight.w600 : FontWeight.normal,
                                  )))),
                              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18,
                                      color: Color(0xFF475569)),
                                  onPressed: () => _openForm(item: item),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18,
                                      color: AppColors.red),
                                  onPressed: () => _delete(item),
                                  tooltip: 'Eliminar',
                                ),
                              ])),
                            ],
                          )).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class AdminColumn {
  final String key, label;
  final bool mono, primary;
  const AdminColumn(this.key, this.label, {this.mono = false, this.primary = false});
}

class _FormDialog extends StatefulWidget {
  final String title;
  final List<AdminColumn> columns;
  final dynamic initial;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _FormDialog({required this.title, required this.columns,
    required this.initial, required this.onSave});
  @override State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late Map<String, TextEditingController> _ctrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrls = { for (final c in widget.columns) c.key:
      TextEditingController(text: '${widget.initial?[c.key] ?? ''}') };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.columns.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _ctrls[c.key],
                decoration: InputDecoration(
                  labelText: c.label,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            )).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : () async {
            setState(() => _saving = true);
            await widget.onSave(
              { for (final c in widget.columns) c.key: _ctrls[c.key]!.text.trim() });
            if (context.mounted) Navigator.pop(context);
          },
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}