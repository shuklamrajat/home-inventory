import 'dart:typed_data';

import 'package:app_core/app_core.dart';

import '../data/repository.dart';
import '../domain/inventory_logic.dart';
import '../ui/format.dart';

String _warrantyLabel(DateTime? expires, DateTime now) {
  final s = warrantyStatus(expires, now);
  return switch (s.state) {
    WarrantyState.none => '',
    WarrantyState.active => 'active',
    WarrantyState.soon => 'ends in ${s.daysLeft} days',
    WarrantyState.expired => 'expired',
  };
}

List<Item> _sorted(List<Room> rooms, List<Item> items) {
  final order = {for (var i = 0; i < rooms.length; i++) rooms[i].id: i};
  return [...items]..sort((a, b) {
      final r = (order[a.roomId] ?? 1 << 30).compareTo(order[b.roomId] ?? 1 << 30);
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}

/// One row per item, grouped by room, with a total line. Money columns are
/// plain numbers so a spreadsheet can sum them.
String buildInventoryCsv(List<Room> rooms, List<Item> items, List<Attachment> atts, DateTime now) {
  final roomName = {for (final r in rooms) r.id: r.name};
  final w = CsvWriter()
    ..row(['Room', 'Item', 'Category', 'Brand', 'Serial', 'Purchased', 'Price', 'Current value', 'Value used',
      'Warranty ends', 'Warranty', 'Photos', 'Receipts', 'Notes']);
  var total = 0;
  for (final it in _sorted(rooms, items)) {
    final v = valueOf(it);
    total += v;
    w.row([
      roomName[it.roomId] ?? '',
      it.name,
      it.category,
      it.brand,
      it.serial,
      it.purchaseDate == null ? '' : isoDate(it.purchaseDate!),
      it.priceCents == null ? '' : Money.plain(it.priceCents!),
      it.valueCents == null ? '' : Money.plain(it.valueCents!),
      Money.plain(v),
      it.warrantyExpires == null ? '' : isoDate(it.warrantyExpires!),
      _warrantyLabel(it.warrantyExpires, now),
      atts.where((a) => a.itemId == it.id && a.kind == 'photo').length,
      atts.where((a) => a.itemId == it.id && a.kind == 'receipt').length,
      it.notes,
    ]);
  }
  w
    ..blank()
    ..row(['Total', '${items.length} items', '', '', '', '', '', '', Money.plain(total)]);
  return w.build();
}

/// Claim report: totals, a table per room, then one block per item that has
/// photos, receipts or a serial number, with the pictures embedded.
Future<Uint8List> buildInventoryPdf(List<Room> rooms, List<Item> items, List<Attachment> atts, String attachmentsDir,
    String currency, DateTime now) async {
  String m(int c) => Money.format(c, currency: currency);
  final sorted = _sorted(rooms, items);
  final total = items.fold(0, (a, i) => a + valueOf(i));

  final tables = <PdfTableSection>[];
  for (final r in rooms) {
    final inRoom = sorted.where((i) => i.roomId == r.id).toList();
    if (inRoom.isEmpty) continue;
    tables.add(PdfTableSection(
      heading: r.name,
      headers: const ['Item', 'Brand', 'Serial', 'Purchased', 'Value', 'Warranty'],
      rows: [
        for (final it in inRoom)
          [
            it.name,
            it.brand,
            it.serial,
            it.purchaseDate == null ? '' : isoDate(it.purchaseDate!),
            m(valueOf(it)),
            it.warrantyExpires == null ? '' : '${isoDate(it.warrantyExpires!)} (${_warrantyLabel(it.warrantyExpires, now)})',
          ],
      ],
      columnAlignRight: const {4},
      footer: ['${r.name} total: ${m(inRoom.fold(0, (a, i) => a + valueOf(i)))}'],
    ));
  }

  final details = <PdfDetailBlock>[];
  final missing = <String>[];
  for (final it in sorted) {
    final mine = atts.where((a) => a.itemId == it.id).toList()
      ..sort((a, b) => a.kind == b.kind ? a.id.compareTo(b.id) : (a.kind == 'photo' ? -1 : 1));
    if (mine.isEmpty && it.serial.isEmpty) continue;
    final loaded = await loadAttachments(attachmentsDir, [for (final a in mine) a.fileName]);
    for (final n in loaded.missing) {
      missing.add('${it.name}: ${mine.firstWhere((a) => a.fileName == n).kind} missing');
    }
    details.add(PdfDetailBlock(
      title: it.name,
      lines: [
        if (it.brand.isNotEmpty) ('Brand', it.brand),
        if (it.serial.isNotEmpty) ('Serial', it.serial),
        if (it.purchaseDate != null) ('Purchased', isoDate(it.purchaseDate!)),
        if (it.priceCents != null) ('Price paid', m(it.priceCents!)),
        ('Value', m(valueOf(it))),
        ('Photos', '${mine.where((a) => a.kind == 'photo').length}'),
        ('Receipts', '${mine.where((a) => a.kind == 'receipt').length}'),
      ],
      images: [for (final a in mine) if (loaded.loaded[a.fileName] != null) loaded.loaded[a.fileName]!],
    ));
  }

  return buildPdfReport(
    title: 'Home inventory',
    meta: [
      'Prepared ${isoDate(now)}',
      if (missing.isNotEmpty) 'Files not found on this device: ${missing.join('; ')}',
    ],
    summary: [
      ('Items', '${items.length}'),
      ('Total value', m(total)),
      ('Photos', '${atts.where((a) => a.kind == 'photo').length}'),
      ('Receipts', '${atts.where((a) => a.kind == 'receipt').length}'),
    ],
    tables: tables,
    details: details,
    footerNote: 'Value is the current value where entered, otherwise the price paid.',
  );
}
