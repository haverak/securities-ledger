
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'deal_form.dart';

class DealDetailsPage extends StatefulWidget {
  final Deal deal;

  const DealDetailsPage({super.key, required this.deal});

  @override
  State<DealDetailsPage> createState() => _DealDetailsPageState();
}

class _DealDetailsPageState extends State<DealDetailsPage> {
  final ApiService _api = ApiService();

  late final Future<Map<String, String>> _references;

  @override
  void initState() {
    super.initState();
    _references = _loadReferences();
  }

  Future<Map<String, String>> _loadReferences() async {
    final results = await Future.wait([
      _api.getReferences('deal-types'),
      _api.getReferences('deal-places'),
      _api.getReferences('currencies'),
    ]);

    String findName(List<ReferenceItem> items, int id) {
      for (final item in items) {
        if (item.id == id) return item.name;
      }
      return 'Не найдено (ID $id)';
    }

    return {
      'type': findName(results[0], widget.deal.dealTypeId),
      'place': findName(results[1], widget.deal.dealPlaceId),
      'currency': findName(results[2], widget.deal.currencyId),
    };
  }

  Future<void> _delete(BuildContext context) async {
    final deal = widget.deal;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить сделку?'),
        content: Text(
          'Сделка «${deal.securityName}» будет удалена без возможности восстановления.',
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

    if (confirmed != true || !context.mounted) return;

    try {
      await ApiService().deleteDeal(deal.id);
      if (context.mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final total = (double.tryParse(deal.price) ?? 0) * deal.quantity;

    return Scaffold(
      appBar: AppBar(title: const Text('Карточка сделки')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            deal.securityName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Количество'),
                  trailing: Text('${deal.quantity}'),
                ),
                ListTile(
                  title: const Text('Цена за единицу'),
                  trailing: Text(deal.price),
                ),
                ListTile(
                  title: const Text('Сумма сделки'),
                  trailing: Text(total.toStringAsFixed(2)),
                ),
                ListTile(
                  title: const Text('Дата'),
                  trailing: Text(
                    '${deal.dealDate.day.toString().padLeft(2, '0')}.'
                        '${deal.dealDate.month.toString().padLeft(2, '0')}.'
                        '${deal.dealDate.year}',
                  ),
                ),

                FutureBuilder<Map<String, String>>(
                  future: _references,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return const ListTile(
                        leading: Icon(Icons.warning_amber),
                        title: Text('Не удалось загрузить справочники'),
                      );
                    }

                    final refs = snapshot.data!;

                    return Column(
                      children: [
                        ListTile(
                          title: const Text('Тип сделки'),
                          trailing: Text(refs['type'] ?? '—'),
                        ),
                        ListTile(
                          title: const Text('Торговая площадка'),
                          trailing: Text(refs['place'] ?? '—'),
                        ),
                        ListTile(
                          title: const Text('Валюта'),
                          trailing: Text(refs['currency'] ?? '—'),
                        ),
                      ],
                    );
                  },
                ),

              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => DealFormPage(deal: deal),
                ),
              );
              if (changed == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Изменить'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
