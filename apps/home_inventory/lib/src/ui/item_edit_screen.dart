import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/repository.dart';
import '../domain/inventory_logic.dart';
import 'format.dart';

class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.item, this.initialRoomId});
  final Item? item;
  final int? initialRoomId;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _Pending {
  _Pending(this.kind, this.fileName);
  final String kind;
  final String fileName;
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _category = TextEditingController(text: widget.item?.category ?? '');
  late final _brand = TextEditingController(text: widget.item?.brand ?? '');
  late final _serial = TextEditingController(text: widget.item?.serial ?? '');
  late final _purchased = TextEditingController(
    text: widget.item?.purchaseDate == null ? '' : isoDate(widget.item!.purchaseDate!),
  );
  late final _price = TextEditingController(
    text: widget.item?.priceCents == null ? '' : Money.plain(widget.item!.priceCents!),
  );
  late final _value = TextEditingController(
    text: widget.item?.valueCents == null ? '' : Money.plain(widget.item!.valueCents!),
  );
  late final _warrantyEnds = TextEditingController(
    text: widget.item?.warrantyExpires == null ? '' : isoDate(widget.item!.warrantyExpires!),
  );
  final _warrantyMonths = TextEditingController();
  late final _notes = TextEditingController(text: widget.item?.notes ?? '');
  int? _roomId;
  final List<_Pending> _pending = [];
  bool _saved = false;
  bool _busy = false;
  late final InventoryRepository _repo;

  @override
  void initState() {
    super.initState();
    _roomId = widget.item?.roomId ?? widget.initialRoomId;
    _repo = ref.read(repositoryProvider);
  }

  @override
  void dispose() {
    // Files picked for an item that was never saved would otherwise stay on
    // disk with nothing pointing at them.
    if (!_saved && _pending.isNotEmpty) {
      final repo = _repo;
      final names = [for (final x in _pending) x.fileName];
      repo.attachmentsPath().then((dir) async {
        for (final n in names) {
          final f = File(p.join(dir, n));
          if (await f.exists()) await f.delete();
        }
      });
    }
    for (final c in [
      _name,
      _category,
      _brand,
      _serial,
      _purchased,
      _price,
      _value,
      _warrantyEnds,
      _warrantyMonths,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyMonths() {
    final months = int.tryParse(_warrantyMonths.text.trim());
    final bought = parseIsoDate(_purchased.text);
    if (months == null || bought == null) return;
    _warrantyEnds.text = isoDate(addMonths(bought, months));
  }

  Future<void> _pick(String kind) async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('pick-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              key: const Key('pick-library'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final img = await ref.read(photoSourceProvider).pick(camera: camera);
    if (img == null) return;
    final repo = ref.read(repositoryProvider);
    final name = await repo.storeFile(img.bytes, img.extension);
    if (widget.item != null) {
      await repo.addAttachment(widget.item!.id, kind, name);
    } else {
      setState(() => _pending.add(_Pending(kind, name)));
    }
  }

  String? _moneyError(String? v) =>
      (v ?? '').trim().isEmpty || Money.parse(v!) != null ? null : 'Enter an amount like 49.99';
  String? _optionalDate(String? v) =>
      (v ?? '').trim().isEmpty || parseIsoDate(v!) != null ? null : 'Use a date like 2026-09-01';

  Future<void> _save() async {
    if (_busy) return;
    if (_months.isNotEmpty) _applyMonths();
    if (!_form.currentState!.validate()) return;
    final bought = parseIsoDate(_purchased.text);
    final ends = parseIsoDate(_warrantyEnds.text);
    if (bought != null && ends != null && ends.isBefore(bought)) {
      showSnack(context, "The warranty can't end before the purchase date.");
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);
    final c = ItemsCompanion(
      id: widget.item == null ? const Value.absent() : Value(widget.item!.id),
      roomId: Value(_roomId!),
      name: Value(_name.text.trim()),
      category: Value(_category.text.trim()),
      brand: Value(_brand.text.trim()),
      serial: Value(_serial.text.trim()),
      purchaseDate: Value(bought),
      priceCents: Value(_price.text.trim().isEmpty ? null : Money.parse(_price.text)),
      valueCents: Value(_value.text.trim().isEmpty ? null : Money.parse(_value.text)),
      warrantyExpires: Value(ends),
      notes: Value(_notes.text.trim()),
    );
    final id = await repo.saveItem(c);
    for (final x in _pending) {
      await repo.addAttachment(id, x.kind, x.fileName);
    }
    _saved = true;
    await ref.read(ratingPrompterProvider).recordCompletedTask();
    if (mounted) Navigator.pop(context, id);
  }

  String get _months => _warrantyMonths.text.trim();

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'Delete ${widget.item!.name}?', 'Its photos and receipts are deleted too.')) {
      return;
    }
    await ref.read(repositoryProvider).deleteItem(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final stored = widget.item == null
        ? const <Attachment>[]
        : (ref.watch(attachmentsProvider).value ?? const <Attachment>[])
              .where((a) => a.itemId == widget.item!.id)
              .toList();
    final dir = ref.watch(attachmentsPathProvider).value;
    final shown = [
      for (final a in stored) (kind: a.kind, fileName: a.fileName, att: a as Attachment?),
      for (final x in _pending) (kind: x.kind, fileName: x.fileName, att: null),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'New item' : 'Edit item'),
        actions: [
          if (widget.item != null)
            IconButton(key: const Key('delete-item'), icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(key: const Key('save-item'), onPressed: _busy ? null : _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Builder(
              builder: (context) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in shown)
                    Stack(
                      children: [
                        Container(
                          key: Key('thumb-${s.fileName}'),
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black12),
                          clipBehavior: Clip.antiAlias,
                          child: dir != null
                              ? Image.file(
                                  File(p.join(dir, s.fileName)),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                                )
                              : null,
                        ),
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Icon(
                            s.kind == 'receipt' ? Icons.receipt_long : Icons.photo,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        if (s.att != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => ref.read(repositoryProvider).removeAttachment(s.att!),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('add-photo'),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Photo'),
                  onPressed: () => _pick('photo'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('add-receipt'),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Receipt'),
                  onPressed: () => _pick('receipt'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'What is it?'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Give it a name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('item-room'),
              initialValue: _roomId,
              decoration: const InputDecoration(labelText: 'Room'),
              items: [for (final r in rooms) DropdownMenuItem(value: r.id, child: Text(r.name))],
              onChanged: (v) => setState(() => _roomId = v),
              validator: (v) => v == null ? 'Pick a room' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-category'),
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-brand'),
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-serial'),
              controller: _serial,
              decoration: const InputDecoration(labelText: 'Serial number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-purchased'),
              controller: _purchased,
              decoration: const InputDecoration(labelText: 'Purchase date', hintText: 'YYYY-MM-DD'),
              validator: _optionalDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price paid'),
              validator: _moneyError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-value'),
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Current value (optional)',
                helperText: 'Leave empty to use the price paid',
              ),
              validator: _moneyError,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('item-warranty-months'),
                    controller: _warrantyMonths,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Warranty (months)'),
                    onChanged: (_) => _applyMonths(),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty || int.tryParse(v!.trim()) != null ? null : 'Whole months',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('item-warranty-ends'),
                    controller: _warrantyEnds,
                    decoration: const InputDecoration(labelText: 'Warranty ends', hintText: 'YYYY-MM-DD'),
                    validator: _optionalDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item-notes'),
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-item-bottom'),
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
