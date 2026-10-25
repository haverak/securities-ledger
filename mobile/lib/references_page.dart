
import 'package:flutter/material.dart';
import 'api_service.dart';

class ReferencesPage extends StatelessWidget {
  const ReferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Справочники'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Типы сделок'),
              Tab(text: 'Площадки'),
              Tab(text: 'Валюты'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ReferenceTab(path: 'deal-types', title: 'Тип сделки'),
            ReferenceTab(path: 'deal-places', title: 'Площадка'),
            ReferenceTab(path: 'currencies', title: 'Валюта'),
          ],
        ),
      ),
    );
  }
}

class ReferenceTab extends StatefulWidget {
  final String path;
  final String title;

  const ReferenceTab({
    super.key,
    required this.path,
    required this.title,
  });

  @override
  State<ReferenceTab> createState() => _ReferenceTabState();
}

class _ReferenceTabState extends State<ReferenceTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  late Future<List<ReferenceItem>> _items;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _items = _api.getReferences(widget.path);
    });
  }

  Future<void> _edit([ReferenceItem? item]) async {
    final nameController = TextEditingController(text: item?.name ?? '');
    final codeController = TextEditingController();
    final isCurrency = widget.path == 'currencies';

    // Для валют код извлекается из текущего списка,
    // потому что справочник хранит и название, и ISO-код.
    if (isCurrency && item != null) {
      codeController.text = item.code ?? '';
    }

    try {
      final data = await showDialog<({String name, String? code})>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item == null
              ? 'Добавить: ${widget.title}'
              : 'Изменить: ${widget.title}'),
          content: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrency)
                  TextField(
                    controller: codeController,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Код ISO',
                      hintText: 'RUB',
                    ),
                  ),
                TextField(
                  controller: nameController,
                  autofocus: !isCurrency,
                  maxLength: isCurrency
                      ? 100
                      : widget.path == 'deal-types'
                      ? 100
                      : 150,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    hintText: widget.title,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final code = codeController.text.trim().toUpperCase();

                if (name.isEmpty) return;
                if (isCurrency &&
                    !RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  (name: name, code: isCurrency ? code : null),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );

      if (data == null || !mounted) return;

      setState(() => _busy = true);
      try {
        if (item == null) {
          await _api.createReference(
            widget.path,
            name: data.name,
            code: data.code,
          );
        } else {
          await _api.updateReference(
            widget.path,
            item.id,
            name: data.name,
            code: data.code,
          );
        }
        if (mounted) _reload();
      } catch (error) {
        _showError('$error');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } finally {
      nameController.dispose();
      codeController.dispose();
    }
  }

  Future<void> _delete(ReferenceItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(
          'Удалить «${item.name}»? Если запись используется '
              'в сделках, сервер запретит удаление.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _api.deleteReference(widget.path, item.id);
      if (mounted) _reload();
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<List<ReferenceItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Не удалось загрузить справочник'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _reload,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data ?? [];

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              children: [
                for (final item in items)
                  Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: widget.path == 'currencies'
                          ? Text(item.code ?? '')
                          : null,
                      onTap: _busy ? null : () => _edit(item),
                      trailing: IconButton(
                        tooltip: 'Удалить',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _busy ? null : () => _delete(item),
                      ),
                    ),
                  ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('Записей пока нет')),
                  ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: widget.path,
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            ),
          ],
        );
      },
    );
  }
}
