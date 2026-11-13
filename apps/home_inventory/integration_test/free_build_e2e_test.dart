// End-to-end on the build as it ships today: someone who already has 25
// items (the free limit) adds a 26th and exports, all without a paywall.
//
// What could go wrong, written down before the code:
//   1. The shipped build still uses the locked stand-in, so a reviewer taps a
//      paid feature and lands on a paywall that cannot take a purchase.
//   2. Pro is unlocked, but Settings thanks the person for buying it, or its
//      Pro row still leads into the paywall.
//   3. Pro is only unlocked until the app restarts (it leans on a stored flag).
//   4. The privacy link opens another app's policy, or nothing at all, and a
//      phone with no browser gives no hint where the policy lives.
// Unlike app_e2e_test.dart, this run does NOT override the entitlement
// service: it uses exactly what a release build ships with.
//
// Run: tool/run_e2e.sh (runs this after app_e2e_test.dart)
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:drift/native.dart';
import 'package:e2e_driver/e2e_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:home_inventory/src/app.dart';
import 'package:home_inventory/src/data/repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const artifactRoot = String.fromEnvironment('ARTIFACT_DIR', defaultValue: 'test-artifacts/manual-free');
const policyUrl = 'https://shuklamrajat.github.io/widdle-privacy/housetally/';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Housetally as shipped now: every Pro feature free, privacy link', (tester) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    Motion.ambient = false; // endless decorative loops would block pumpAndSettle
    addTearDown(() => Motion.ambient = true);
    final semantics = tester.ensureSemantics();
    final log = E2eLog('home_inventory: Housetally as shipped now: every Pro feature free, privacy link', artifactRoot);
    final tmp = await Directory.systemTemp.createTemp('home_inventory_free');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final db = InventoryDb(NativeDatabase(File('${tmp.path}/app.sqlite')));
    final clock = TestClock(DateTime(2026, 11, 11, 20));
    final sharer = RecordingFileSharer();
    final links = RecordingLinkOpener();
    final d = E2eDriver(tester);

    // No entitlementServiceProvider override: this is the shipped default.
    Widget app() => ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(inventoryConfig),
        inventoryDbProvider.overrideWithValue(db),
        attachmentsDirProvider.overrideWithValue(() async => tmp),
        clockProvider.overrideWithValue(clock.call),
        fileSharerProvider.overrideWithValue(sharer),
        exportDirProvider.overrideWithValue(() async => tmp),
        reviewRequesterProvider.overrideWithValue(RecordingReviewRequester()),
        linkOpenerProvider.overrideWithValue(links),
      ],
      child: const InventoryApp(),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    try {
      await d.tapKey('onboarding-skip');
      await d.waitFor(find.byKey(const Key('add-room')));
      await d.skipTour();
      log.check('desktop build shows no ad', false, d.exists('ad-banner'));
      // 25 items already logged in the Garage, $10 each.
      final garage = (await (db.select(db.rooms)..where((r) => r.name.equals('Garage'))).getSingle()).id;
      for (var n = 1; n <= 25; n++) {
        await db
            .into(db.items)
            .insert(
              ItemsCompanion.insert(
                roomId: garage,
                name: 'Tool ${n.toString().padLeft(2, '0')}',
                priceCents: const Value(1000),
                createdAt: clock(),
              ),
            );
      }
      await d.waitUntil(() => find.text(r'$250.00').evaluate().isNotEmpty, 'total of 25 items');

      // The 26th item is past the free limit: the form must open straight away.
      await d.tapKey('add-item');
      await d.waitFor(find.byKey(const Key('item-name')));
      log.check('26th item: no paywall', false, d.exists('paywall'));
      await d.type('item-name', 'Lawn mower');
      await d.tapKey('item-room');
      await d.pick('Garage');
      await d.type('item-price', '300');
      await d.tapKey('save-item');
      await d.waitFor(find.byKey(const Key('add-item')));
      log.check('26 items saved', 26, (await db.select(db.items).get()).length);
      log.check('total after the 26th item', r'$550.00', await d.textOf('total-value'));

      // Export is a Pro feature too.
      await d.tapKey('export-menu');
      await d.tapKey('export-csv');
      await d.waitUntil(() => sharer.shared.length == 1, 'CSV export');
      log.check('export: no paywall', false, d.exists('paywall'));
      final csv = log.keep(sharer.shared.single, 'inventory.csv').readAsStringSync();
      log.check(
        'CSV lists the lawn mower and all 26 items',
        true,
        csv.contains('Lawn mower') && csv.contains('Tool 25'),
      );

      // Settings: no thank-you for a purchase nobody made, no way into a
      // paywall, and the privacy policy opens at this app's own address.
      await d.tapKey('open-settings');
      log.check(
        'Settings says Pro is free for now',
        true,
        (await d.textsIn('settings-pro')).startsWith('Every Pro feature is free for now'),
      );
      await d.tapKey('settings-pro');
      log.check('tapping the Pro row opens no paywall', false, d.exists('paywall'));
      await d.tapKey('settings-privacy-policy');
      log.check("privacy policy opens this app's own page", [policyUrl], [for (final u in links.opened) '$u']);
      log.check('no error after the link opened', false, d.exists('privacy-link-failed'));
      links.works = false; // a phone with no browser
      await d.tapKey('settings-privacy-policy');
      await d.waitFor(find.byKey(const Key('privacy-link-failed')));
      log.check(
        'no browser: the address is shown instead',
        true,
        find
            .descendant(of: find.byKey(const Key('privacy-link-failed')), matching: find.textContaining(policyUrl))
            .evaluate()
            .isNotEmpty,
      );
      // About, at the foot of Settings: the new logo (the launcher icon's
      // artwork, drawn live) beside the app's name.
      log.check('About row names the app', 'Housetally | ${inventoryConfig.tagline}', await d.textsIn('settings-about'));
      log.check(
        'About row shows the drawn logo, not the plain brand dot',
        1,
        find
            .descendant(of: find.byKey(const Key('settings-about')), matching: find.byType(AnimatedScene))
            .evaluate()
            .length,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Close and reopen: Pro must not depend on anything stored.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await d.waitFor(find.byKey(const Key('add-item')));
      await d.tapKey('add-item');
      await d.waitFor(find.byKey(const Key('item-name')));
      log.check('after a restart: 27th item still free', false, d.exists('paywall'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      log.check('nothing about Pro was stored on the phone', <String>[], [
        for (final k in prefs.getKeys())
          if (k.toLowerCase().contains('pro')) k,
      ]);
    } finally {
      log.write();
      semantics.dispose();
    }
    expect(log.failures, isEmpty, reason: 'see $artifactRoot/result.json');
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
  }, timeout: const Timeout(Duration(minutes: 4)));
}
