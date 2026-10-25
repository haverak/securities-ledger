import 'references_page.dart';
import 'package:flutter/material.dart';
import 'deal_details.dart';
import 'api_service.dart';
import 'deal_form.dart';

void main() {
  runApp(const SecuritiesLedgerApp());
}

class SecuritiesLedgerApp extends StatelessWidget {
  const SecuritiesLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Учёт сделок',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4DB6AC),
        scaffoldBackgroundColor: const Color(0xFF161A1D),
      ),
      home: const DealsPage(),
    );
  }
}

class DealsPage extends StatefulWidget {
  const DealsPage({super.key});

  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage> {
  final ApiService api = ApiService();
  late Future<List<Deal>> dealsFuture;
  String searchQuery = '';
  int? selectedType;
  int? selectedPlace;
  int? selectedCurrency;
  DateTime? dateFrom;
  DateTime? dateTo;
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Deal> filterDeals(List<Deal> deals) {
    return deals.where((deal) {
      final matchesName = deal.securityName
          .toLowerCase()
          .contains(searchQuery.toLowerCase());

      final matchesType =
          selectedType == null || deal.dealTypeId == selectedType;

      final matchesPlace =
          selectedPlace == null || deal.dealPlaceId == selectedPlace;

      final matchesCurrency =
          selectedCurrency == null || deal.currencyId == selectedCurrency;

      final date = DateUtils.dateOnly(deal.dealDate);

      final matchesFrom = dateFrom == null ||
          !date.isBefore(DateUtils.dateOnly(dateFrom!));

      final matchesTo = dateTo == null ||
          !date.isAfter(DateUtils.dateOnly(dateTo!));

      return matchesName &&
          matchesType &&
          matchesPlace &&
          matchesCurrency &&
          matchesFrom &&
          matchesTo;
    }).toList();
  }

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    refreshDeals();
  }

  void refreshDeals() {
    setState(() {
      dealsFuture = api.getDeals();
    });
  }

  Future<void> showFilters() async {
    try {
      final apiService = ApiService();

      final results = await Future.wait([
        apiService.getReferences('deal-types'),
        apiService.getReferences('deal-places'),
        apiService.getReferences('currencies'),
      ]);

      if (!mounted) return;

      int? type = selectedType;
      int? place = selectedPlace;
      int? currency = selectedCurrency;
      DateTime? from = dateFrom;
      DateTime? to = dateTo;

      final applied = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, updateSheet) {
            Widget dropdown(
                String label,
                List<ReferenceItem> items,
                int? value,
                ValueChanged<int?> changed,
                ) {
              return DropdownButtonFormField<int>(
                key: ValueKey(label),
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Все'),
                  ),
                  ...items.map(
                        (item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(
                        item.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: changed,
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Фильтры сделок',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      dropdown(
                        'Тип сделки',
                        results[0],
                        type,
                            (value) => updateSheet(() => type = value),
                      ),
                      const SizedBox(height: 12),
                      dropdown(
                        'Площадка',
                        results[1],
                        place,
                            (value) => updateSheet(() => place = value),
                      ),
                      const SizedBox(height: 12),
                      dropdown(
                        'Валюта',
                        results[2],
                        currency,
                            (value) => updateSheet(() => currency = value),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () async {
                          final value = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDateRange: from != null && to != null
                                ? DateTimeRange(start: from!, end: to!)
                                : null,
                          );

                          if (value != null) {
                            updateSheet(() {
                              from = value.start;
                              to = value.end;
                            });
                          }
                        },
                        child: Text(
                          from == null || to == null
                              ? 'Выбрать период'
                              : 'Период: ${from!.day}.${from!.month}.${from!.year}'
                              ' — ${to!.day}.${to!.month}.${to!.year}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          updateSheet(() {
                            type = null;
                            place = null;
                            currency = null;
                            from = null;
                            to = null;
                          });
                        },
                        child: const Text('Сбросить фильтры'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('Применить'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      if (applied == true && mounted) {
        setState(() {
          selectedType = type;
          selectedPlace = place;
          selectedCurrency = currency;
          dateFrom = from;
          dateTo = to;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки фильтров: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Учёт сделок'),
        actions: [
          IconButton(
            tooltip: 'Фильтры',
            icon: const Icon(Icons.filter_list),
            onPressed: showFilters,
          ),

          IconButton(
            tooltip: 'Справочники',
            icon: const Icon(Icons.library_books_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReferencesPage(),
                ),
              );

              if (mounted) refreshDeals();
            },
          ),

          IconButton(
            tooltip: 'Обновить',
            onPressed: refreshDeals,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Deal>>(
        future: dealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('Не удалось загрузить сделки'),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: refreshDeals,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final allDeals = snapshot.data ?? <Deal>[];
          final deals = filterDeals(allDeals);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Поиск по названию бумаги',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => searchQuery = value);
                  },
                ),
                const SizedBox(height: 16),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('Найдено сделок'),
                    trailing: Text(
                      '${deals.length}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Последние операции',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: deals.isEmpty
                      ? const Center(child: Text('Сделок пока нет'))
                      : ListView.builder(
                    itemCount: deals.length,
                    itemBuilder: (context, index) {
                      final deal = deals[index];
                      return Card(
                        child: ListTile(

                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DealDetailsPage(deal: deal),
                              ),
                            );

                            if (changed == true && mounted) {
                              refreshDeals();
                            }
                          },

                          leading: const Icon(Icons.show_chart),
                          title: Text(deal.securityName),
                          subtitle: Text(
                            'Количество: ${deal.quantity} · '
                                'Цена: ${deal.price}',
                          ),
                          trailing: Text('#${deal.id}'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(

        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const DealFormPage(),
            ),
          );

          if (created == true && mounted) {
            refreshDeals();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Новая сделка'),
      ),
    );
  }
}
