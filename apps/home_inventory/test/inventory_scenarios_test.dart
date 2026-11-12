// Isolated scenarios for warranty dates, values and attachment resolution,
// written from docs/failure-modes.md before the code.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/src/domain/inventory_logic.dart';

void main() {
  test('A: warranty end dates and status', () {
    expect(addMonths(DateTime(2023, 1, 31), 13), DateTime(2024, 2, 29));
    expect(addMonths(DateTime(2023, 1, 31), 1), DateTime(2023, 2, 28));
    expect(addMonths(DateTime(2025, 12, 1), 12), DateTime(2026, 12, 1));
    expect(addMonths(DateTime(2024, 11, 20), 24), DateTime(2026, 11, 20));

    final today = DateTime(2026, 11, 11, 23, 30);
    expect(warrantyStatus(null, today).state, WarrantyState.none);
    expect(warrantyStatus(DateTime(2026, 11, 20), today).daysLeft, 9);
    expect(warrantyStatus(DateTime(2026, 11, 20), today).state, WarrantyState.soon);
    expect(warrantyStatus(DateTime(2026, 12, 11), today).state, WarrantyState.soon); // 30 days
    expect(warrantyStatus(DateTime(2026, 12, 12), today).state, WarrantyState.active); // 31 days
    expect(warrantyStatus(DateTime(2026, 11, 11), today).state, WarrantyState.soon); // ends today, still valid
    expect(warrantyStatus(DateTime(2026, 11, 10), today).state, WarrantyState.expired);

    final sorted = sortForWarrantyList([
      (id: 'expired', expires: DateTime(2024, 2, 29)),
      (id: 'active', expires: DateTime(2031, 3, 15)),
      (id: 'mac', expires: DateTime(2026, 12, 1)),
      (id: 'tv', expires: DateTime(2026, 11, 20)),
      (id: 'none', expires: null),
    ], today);
    expect(sorted, ['tv', 'mac', 'active', 'expired']);
  });

  test('B: item value prefers current value, then price', () {
    expect(itemValue(valueCents: 90000, priceCents: 129999), 90000);
    expect(itemValue(valueCents: null, priceCents: 129999), 129999);
    expect(itemValue(valueCents: null, priceCents: null), 0);
  });

  test('C: attachments resolve by file name and missing files are reported', () async {
    final dir = await Directory.systemTemp.createTemp('att');
    File('${dir.path}/a.png').writeAsBytesSync([1, 2, 3]);
    final r = await loadAttachments(dir.path, ['a.png', 'gone.png']);
    expect(r.loaded.length, 1);
    expect(r.missing, ['gone.png']);
    // A stored name cannot escape the folder.
    final escape = await loadAttachments(dir.path, ['../etc/passwd']);
    expect(escape.loaded, isEmpty);
    expect(escape.missing, ['../etc/passwd']);
  });
}
