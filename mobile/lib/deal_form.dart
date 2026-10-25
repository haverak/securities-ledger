
import 'package:flutter/material.dart';
import 'api_service.dart';

class DealFormPage extends StatefulWidget {
  final Deal? deal;

  const DealFormPage({super.key, this.deal});

  @override
  State<DealFormPage> createState() => _DealFormPageState();
}

class _DealFormPageState extends State<DealFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _api = ApiService();

  late final Future<void> _loading;

  List<ReferenceItem> _types = [];
  List<ReferenceItem> _places = [];
  List<ReferenceItem> _currencies = [];

  int? _typeId;
  int? _placeId;
  int? _currencyId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.deal != null) {
      final deal = widget.deal!;
      _name.text = deal.securityName;
      _quantity.text = deal.quantity.toString();
      _price.text = deal.price;
      _date = deal.dealDate;
      _typeId = deal.dealTypeId;
      _placeId = deal.dealPlaceId;
      _currencyId = deal.currencyId;
    }
    _loading = _loadReferences();
  }

  Future<void> _loadReferences() async {
    final results = await Future.wait([
      _api.getReferences('deal-types'),
      _api.getReferences('deal-places'),
      _api.getReferences('currencies'),
    ]);
    _types = results[0];
    _places = results[1];
    _currencies = results[2];
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Widget _selector(
      String label,
      List<ReferenceItem> items,
      int? selected,
      ValueChanged<int?> changed,
      ) {
    return DropdownButtonFormField<int>(
      key: ValueKey(label),
      initialValue: selected,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem<int>(
          value: item.id,
          child: Text(item.name),
        ),
      )
          .toList(),
      onChanged: changed,
      validator: (value) =>
      value == null ? 'Выберите значение' : null,
    );
  }


  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final name = _name.text.trim();
      final quantity = int.parse(_quantity.text.trim());
      final price = _price.text.trim().replaceAll(',', '.');

      if (widget.deal == null) {
        await _api.createDeal(
          securityName: name,
          quantity: quantity,
          price: price,
          date: _date,
          typeId: _typeId!,
          placeId: _placeId!,
          currencyId: _currencyId!,
        );
      } else {
        await _api.updateDeal(
          id: widget.deal!.id,
          securityName: name,
          quantity: quantity,
          price: price,
          date: _date,
          typeId: _typeId!,
          placeId: _placeId!,
          currencyId: _currencyId!,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deal == null ? 'Новая сделка' : 'Редактирование сделки'),
      ),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Не удалось загрузить справочники:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_types.isEmpty || _places.isEmpty || _currencies.isEmpty) {
            return const Center(
              child: Text('Сначала заполните справочники на сервере'),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Ценная бумага',
                    hintText: 'Например, акции Сбербанка',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Количество',
                  ),
                  validator: (value) {
                    final number = int.tryParse(value?.trim() ?? '');
                    return number == null || number <= 0
                        ? 'Введите целое число больше нуля'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Цена за единицу',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim().replaceAll(',', '.');
                    final validFormat = RegExp(
                      r'^\d{1,14}(\.\d{1,4})?$',
                    ).hasMatch(text);
                    if (!validFormat) {
                      return 'До 14 цифр и 4 знаков после точки';
                    }
                    if (double.tryParse(text) == null ||
                        double.parse(text) <= 0) {
                      return 'Цена должна быть положительной';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _selector(
                  'Тип сделки',
                  _types,
                  _typeId,
                      (value) => setState(() => _typeId = value),
                ),
                const SizedBox(height: 20),
                _selector(
                  'Торговая площадка',
                  _places,
                  _placeId,
                      (value) => setState(() => _placeId = value),
                ),
                const SizedBox(height: 20),
                _selector(
                  'Валюта',
                  _currencies,
                  _currencyId,
                      (value) => setState(() => _currencyId = value),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    'Дата: ${_date.day.toString().padLeft(2, '0')}.'
                        '${_date.month.toString().padLeft(2, '0')}.'
                        '${_date.year}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) {
                      setState(() => _date = picked);
                    }
                  },
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Сохранение...' : 'Сохранить сделку'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
