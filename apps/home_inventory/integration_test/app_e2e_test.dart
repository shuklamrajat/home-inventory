// End-to-end: a realistic first evening with the app. A new room, four real
// items with photos, a receipt and warranties, then 26 more items so the free
// limit is hit, a paywall that is first dismissed and then bought, a delete
// that must take its photo off the disk, search, and both exports.
// Drives the real app on a real SQLite file and real files on disk.
//
// Run: tool/run_e2e.sh
//
// Hand-worked expectations (today = 11 Nov 2026):
//   MacBook Pro 14   Office       bought 2025-12-01  $1,999.00, 12 months -> ends 2026-12-01, 20 days: soon
//                                 2 photos, 1 receipt, serial C02XK1PQMD6T
//   Samsung TV 65    Living room  bought 2024-11-20  paid $1,299.99, now worth $900.00
//                                 24 months -> ends 2026-11-20, 9 days: soon; 1 photo
//   Dishwasher       Kitchen      bought 2023-01-31  $849.00, 13 months -> 2024-02-29 (clamped): expired
//   Road bike        Garage       bought 2026-03-15  $2,400.00, 60 months -> 2031-03-15: active
//                                 note starts with "=" and has a comma (CSV injection guard)
//   Item 05 .. Item 30 in Basement at n x $10 = $4,550.00
//   Total 1,999 + 900 + 849 + 2,400 + 4,550 = $10,698.00 over 30 items.
//   Adding the 26th item opens the paywall (25 is free). Dismissed: still 25.
//   Exporting before Pro opens the paywall and shares nothing.
//   Item 05 gets a photo and is then deleted: its file is gone, total $10,648.00, 29 items.
//   Warranty list order: Samsung TV 65, MacBook Pro 14, Road bike, Dishwasher.
//   PDF: 4 embedded pictures (MacBook 2 photos + receipt, TV 1 photo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:drift/native.dart';
import 'package:e2e_driver/e2e_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/src/app.dart';
import 'package:home_inventory/src/data/repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const artifactRoot = String.fromEnvironment('ARTIFACT_DIR', defaultValue: 'test-artifacts/manual');

/// Stands in for the camera: each pick is a small PNG in a new colour, so
/// every stored file is a distinct real image the PDF has to embed.
class FakePhotoSource implements PhotoSource {
  int picks = 0;
  static const _colors = [
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF8E24AA),
  ];

  @override
  Future<PickedImage?> pick({required bool camera}) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 160, 120), Paint()..color = _colors[picks % _colors.length]);
    c.drawCircle(Offset(30.0 + picks * 20, 60), 18, Paint()..color = const Color(0xFFFFFFFF));
    picks++;
    final img = await rec.endRecording().toImage(160, 120);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return PickedImage(png!.buffer.asUint8List(), 'png');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('30 items, photos, warranties, free limit, delete cleanup, exports', (tester) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    Motion.ambient = false; // endless decorative loops would block pumpAndSettle
    addTearDown(() => Motion.ambient = true);
    final semantics = tester.ensureSemantics();
    final log = E2eLog('home_inventory: 30 items, photos, warranties, free limit, delete, exports', artifactRoot);
    final tmp = await Directory.systemTemp.createTemp('inv_e2e');
    final attDir = Directory('${tmp.path}/attachments')..createSync();
    final exportDir = Directory('${tmp.path}/exports')..createSync();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final db = InventoryDb(NativeDatabase(File('${tmp.path}/inventory.sqlite')));
    final clock = TestClock(DateTime(2026, 11, 11, 20));
    final sharer = RecordingFileSharer();
    final photos = FakePhotoSource();
    final d = E2eDriver(tester);
    final shots = StoreShots(tester)..usePhoneSize();

    Widget app() => ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(inventoryConfig),
        inventoryDbProvider.overrideWithValue(db),
        attachmentsDirProvider.overrideWithValue(() async => attDir),
        photoSourceProvider.overrideWithValue(photos),
        clockProvider.overrideWithValue(clock.call),
        fileSharerProvider.overrideWithValue(sharer),
        exportDirProvider.overrideWithValue(() async => exportDir),
        reviewRequesterProvider.overrideWithValue(RecordingReviewRequester()),
        entitlementServiceProvider.overrideWithValue(LocalEntitlementService(prefs, allowDebugPurchase: true)),
      ],
      child: const InventoryApp(),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    String spoken(String k) => tester.getSemantics(find.byKey(Key(k))).label;

    Future<Item> itemNamed(String n) async => (db.select(db.items)..where((i) => i.name.equals(n))).getSingle();
    Future<int> roomId(String n) async => (await (db.select(db.rooms)..where((r) => r.name.equals(n))).getSingle()).id;
    List<String> filesOnDisk() => attDir.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();

    Future<void> pickRoom(String room) async {
      await d.tapKey('item-room');
      await d.pick(room);
    }

    // Files already on disk from earlier items, so thumbnails count per form.
    var stored = 0;
    Future<void> attach(String button, {bool camera = true}) async {
      final before = filesOnDisk().length;
      await d.tapKey(button);
      await d.tapKey(camera ? 'pick-camera' : 'pick-library');
      await d.waitUntil(() => filesOnDisk().length == before + 1, 'stored photo');
      final thumbs = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('thumb-'),
        skipOffstage: false,
      );
      await d.waitUntil(() => thumbs.evaluate().length == before + 1 - stored, 'thumbnail shown');
    }

    Future<void> saveAndReturn() async {
      await d.tapKey('save-item');
      await d.waitFor(find.byKey(const Key('add-item')));
      stored = filesOnDisk().length;
    }

    try {
      await shots.take('0_welcome');
      await d.tapKey('onboarding-skip');
      await d.waitFor(find.byKey(const Key('add-room')));

      // A room of their own.
      await d.tapKey('add-room');
      await tester.enterText(find.byKey(const Key('room-name-field')), 'Basement');
      await d.tapKey('room-add-ok');
      // The sixth room lands below the fold, so scroll to it as a person would.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await d.reveal(find.text('Basement'));
      final basement = await roomId('Basement');
      log.check(
        'rooms after adding Basement',
        ['Living room', 'Kitchen', 'Bedroom', 'Office', 'Garage', 'Basement'],
        [for (final r in await db.select(db.rooms).get()) r.name],
      );

      // 1. MacBook: two photos and a receipt, warranty from months.
      await d.tapKey('add-item');
      await attach('add-photo');
      await attach('add-photo', camera: false);
      await attach('add-receipt');
      await d.type('item-name', 'MacBook Pro 14');
      await pickRoom('Office');
      await d.type('item-category', 'Electronics');
      await d.type('item-brand', 'Apple');
      await d.type('item-serial', 'C02XK1PQMD6T');
      await d.type('item-purchased', '2025-12-01');
      await d.type('item-price', '1,999.00');
      await d.type('item-warranty-months', '12');
      log.check(
        'MacBook warranty end filled from months',
        '2025-12-01 + 12 months = 2026-12-01',
        '2025-12-01 + 12 months = ${tester.widget<TextFormField>(find.byKey(const Key('item-warranty-ends'))).controller!.text}',
      );
      await shots.take('3_item');
      await saveAndReturn();

      // 2. TV: current value lower than price paid.
      await d.tapKey('add-item');
      await attach('add-photo');
      await d.type('item-name', 'Samsung TV 65');
      await pickRoom('Living room');
      await d.type('item-brand', 'Samsung');
      await d.type('item-purchased', '2024-11-20');
      await d.type('item-price', '1299.99');
      await d.type('item-value', '900');
      await d.type('item-warranty-months', '24');
      await saveAndReturn();

      // 3. Dishwasher: 31 Jan + 13 months must land on 29 Feb 2024.
      await d.tapKey('add-item');
      await d.type('item-name', 'Dishwasher');
      await pickRoom('Kitchen');
      await d.type('item-purchased', '2023-01-31');
      await d.type('item-price', '849');
      await d.type('item-warranty-months', '13');
      log.check(
        'Dishwasher warranty end clamps to month end',
        '2024-02-29',
        tester.widget<TextFormField>(find.byKey(const Key('item-warranty-ends'))).controller!.text,
      );
      await saveAndReturn();

      // 4. Road bike: a warranty end before purchase is refused first.
      await d.tapKey('add-item');
      await d.type('item-name', 'Road bike');
      await pickRoom('Garage');
      await d.type('item-purchased', '2026-03-15');
      await d.type('item-price', '2400');
      await d.type('item-warranty-ends', '2026-01-01');
      await d.tapKey('save-item');
      log.check(
        'warranty ending before purchase refused',
        true,
        find.text("The warranty can't end before the purchase date.").evaluate().isNotEmpty,
      );
      log.check('refused item not stored', 3, (await db.select(db.items).get()).length);
      await d.type('item-warranty-months', '60');
      await d.type('item-notes', '=HYPERLINK("http://x"), carbon frame');
      await saveAndReturn();

      log.check('total after 4 items', r'$6,148.00', await d.textOf('total-value'));

      // Export before Pro: paywall, nothing shared.
      await d.tapKey('export-menu');
      await d.tapKey('export-pdf');
      await d.waitFor(find.byKey(const Key('paywall')));
      log.check('export without Pro opens the paywall', true, d.exists('paywall'));
      await shots.take('6_pro');
      await tester.pageBack();
      await tester.pumpAndSettle();
      log.check('nothing shared without Pro', 0, sharer.shared.length);

      // Items 05..30 in the Basement, from the room screen. The 26th hits the limit.
      await d.tap(find.byKey(Key('room-$basement')));
      var paywallSeen = false;
      for (var n = 5; n <= 30; n++) {
        await d.tap(find.byType(FloatingActionButton).last);
        if (n == 26) {
          await d.waitFor(find.byKey(const Key('paywall')));
          paywallSeen = true;
          log.check('26th item opens the paywall', true, d.exists('paywall'));
          await tester.pageBack();
          await tester.pumpAndSettle();
          log.check('dismissed paywall: no new-item form', false, d.exists('item-name'));
          log.check('dismissed paywall: still 25 items', 25, (await db.select(db.items).get()).length);
          await d.tap(find.byType(FloatingActionButton).last);
          await d.waitFor(find.byKey(const Key('paywall')));
          await d.reveal(find.byKey(const Key('offer-pro_lifetime')));
          await tester.tap(find.byKey(const Key('offer-pro_lifetime')));
          var sawConfetti = false;
          final end = DateTime.now().add(const Duration(seconds: 15));
          while (!d.exists('item-name')) {
            if (DateTime.now().isAfter(end)) throw StateError('item form did not open after buying Pro');
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            sawConfetti |= find.byKey(const Key('celebration')).evaluate().isNotEmpty;
          }
          log.check('confetti plays after buying Pro', true, sawConfetti);
          await tester.pumpAndSettle();
          log.check('confetti cleared once landed', 0, find.byKey(const Key('celebration')).evaluate().length);
        }
        await d.waitFor(find.byKey(const Key('item-name')));
        log.check(
          'item $n opens in Basement',
          basement,
          tester.widget<DropdownButtonFormField<int>>(find.byKey(const Key('item-room'))).initialValue,
        );
        await d.type('item-name', 'Item ${n.toString().padLeft(2, '0')}');
        await d.type('item-price', '${n * 10}');
        if (n == 5) await attach('add-photo');
        await d.tapKey('save-item');
        await d.waitUntil(() => !d.exists('item-name'), 'item $n saved');
        stored = filesOnDisk().length;
      }
      log.check('paywall was reached at the 26th item', true, paywallSeen);
      await tester.pageBack();
      await tester.pumpAndSettle();
      log.check('Basement after 26 items', '26 items', await d.textOf('room-count-$basement'));
      log.check('total after 30 items', r'$10,698.00', await d.textOf('total-value'));
      log.check('item count after 30 items', '30', await d.textOf('item-count'));
      await shots.take('1_rooms');

      // Stored file names are relative, so a moved app folder still works.
      final allAtts = await db.select(db.attachments).get();
      log.check('attachments stored as bare file names', true, allAtts.every((a) => !a.fileName.contains('/')));
      log.check('attachment files on disk before delete', 5, filesOnDisk().length);

      // Delete Item 05 from the Items tab; its photo must leave the disk.
      final item05 = await itemNamed('Item 05');
      final item05File = allAtts.firstWhere((a) => a.itemId == item05.id).fileName;
      await d.tapKey('tab-items');
      await d.type('item-search', 'item 05');
      await d.tap(find.byKey(Key('item-${item05.id}')));
      await d.tapKey('delete-item');
      await d.tapKey('confirm-ok');
      await d.waitFor(find.byKey(const Key('add-item')));
      log.check('deleted item photo removed from disk', false, filesOnDisk().contains(item05File));
      log.check('attachment files on disk after delete', 4, filesOnDisk().length);
      log.check('total after delete', r'$10,648.00', await d.textOf('total-value'));
      log.check('item count after delete', '29', await d.textOf('item-count'));
      // Worked by hand: Basement Items 06-30 = 10 x (6+...+30) = 4500; shares of 10648, rounded.
      log.check(
        'value-by-room ring after delete',
        r'Value by room. Basement $4,500.00, 42%. Garage $2,400.00, 23%. Office $1,999.00, 19%. '
            r'Living room $900.00, 8%. Kitchen $849.00, 8%.',
        spoken('room-chart'),
      );

      // Search by serial number.
      // Coming back from a closed screen, the field needs a tap before typing,
      // as it would for a person.
      await d.tapKey('item-search');
      await d.type('item-search', 'c02xk1');
      final mac = await itemNamed('MacBook Pro 14');
      log.check(
        'serial search finds only the MacBook',
        [true, 1],
        [
          d.exists('item-${mac.id}'),
          find.byWidgetPredicate((w) => w is ListTile && '${w.key}'.contains("'item-")).evaluate().length,
        ],
      );
      await d.type('item-search', '');

      // Warranties tab.
      await d.tapKey('tab-warranties');
      final tv = await itemNamed('Samsung TV 65'),
          dish = await itemNamed('Dishwasher'),
          bike = await itemNamed('Road bike');
      final tiles = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('warranty-') &&
            !(w.key as ValueKey<String>).value.startsWith('warranty-state-'),
      );
      final order = tiles.evaluate().map((e) => e.widget.key).toList();
      log.check(
        'warranty list order',
        [
          Key('warranty-${tv.id}'),
          Key('warranty-${mac.id}'),
          Key('warranty-${bike.id}'),
          Key('warranty-${dish.id}'),
        ].map((k) => '$k').toList(),
        order.map((k) => '$k').toList(),
      );
      log.check(
        'warranty labels',
        ['Ends in 9 days', 'Ends in 20 days', 'Active', 'Expired'],
        [
          for (final i in [tv, mac, bike, dish]) await d.textOf('warranty-state-${i.id}'),
        ],
      );
      await shots.take('2_warranties');

      // Exports, now with Pro.
      await d.tapKey('export-menu');
      await d.tapKey('export-csv');
      await d.waitUntil(() => sharer.shared.length == 1, 'CSV shared');
      await d.tapKey('export-menu');
      await d.tapKey('export-pdf');
      await d.waitUntil(() => sharer.shared.length == 2, 'PDF shared', timeout: const Duration(seconds: 30));
      final csvFile = sharer.shared[0], pdfFile = sharer.shared[1];
      log.check(
        'export file names',
        ['home_inventory_2026-11-11.csv', 'home_inventory_2026-11-11.pdf'],
        [csvFile.uri.pathSegments.last, pdfFile.uri.pathSegments.last],
      );

      final csv = await csvFile.readAsString();
      final lines = csv.replaceFirst('﻿', '').split('\r\n');
      log.check('CSV item rows', 29, lines.skip(1).takeWhile((l) => l.isNotEmpty).length);
      log.check('CSV total line', 'Total,29 items,,,,,,,10648.00', lines.firstWhere((l) => l.startsWith('Total')));
      log.check(
        'CSV dishwasher row',
        'Kitchen,Dishwasher,,,,2023-01-31,849.00,,849.00,2024-02-29,expired,0,0,',
        lines.firstWhere((l) => l.contains('Dishwasher')),
      );
      log.check(
        'CSV TV row uses current value',
        true,
        lines
            .firstWhere((l) => l.contains('Samsung TV'))
            .contains(',1299.99,900.00,900.00,2026-11-20,ends in 9 days,1,0,'),
      );
      log.check(
        'CSV MacBook counts photos and receipt',
        true,
        lines.firstWhere((l) => l.contains('MacBook')).endsWith(',2026-12-01,ends in 20 days,2,1,'),
      );
      log.check(
        'CSV note guarded against formulas',
        true,
        lines.firstWhere((l) => l.contains('Road bike')).endsWith(',"\'=HYPERLINK(""http://x""), carbon frame"'),
      );
      log.check('CSV has no Item 05', false, csv.contains('Item 05'));

      final pdf = await pdfFile.readAsBytes();
      log.check('PDF looks like a PDF', '%PDF', String.fromCharCodes(pdf.take(4)));
      log.keep(csvFile, 'inventory.csv');
      log.keep(pdfFile, 'inventory.pdf');
      log.inputs['photo_picks'] = photos.picks;
      log.inputs['clock'] = clock().toIso8601String();

      // Dark theme, then close and reopen: theme, items and Pro stay.
      await d.tapKey('tab-rooms');
      await d.tapKey('open-settings');
      await d.tapKey('settings-theme');
      await d.pick('Dark');
      log.check(
        'Settings switches the app to dark',
        Brightness.dark,
        Theme.of(tester.element(find.byKey(const Key('settings-theme')))).brightness,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await shots.take('4_dark_rooms');
      await d.tapKey('tab-warranties');
      await shots.take('5_dark_warranties');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await d.waitFor(find.byKey(const Key('total-value')));
      log.check(
        'reopened: still dark',
        Brightness.dark,
        Theme.of(tester.element(find.byKey(const Key('total-value')))).brightness,
      );
      log.check('reopened: total kept', r'$10,648.00', await d.textOf('total-value'));
      log.check('reopened: no onboarding again', false, d.exists('onboarding'));
      await d.tapKey('export-menu');
      await d.tapKey('export-csv');
      await d.waitUntil(() => sharer.shared.length == 3, 'CSV shared after reopen');
      log.check('reopened: Pro kept, export needs no paywall', false, d.exists('paywall'));
    } catch (e, st) {
      log.check('no exception', 'none', '$e\n$st');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close().timeout(const Duration(seconds: 10), onTimeout: () {});
      log.write();
      semantics.dispose();
    }
    expect(log.failures, isEmpty, reason: 'see $artifactRoot/result.json');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
