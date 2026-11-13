// ignore_for_file: avoid_print
// DIAG ONLY: builds the home screen up piece by piece, with semantics on,
// printing each step, to find which piece stops the emulator.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/src/app.dart';
import 'package:home_inventory/src/data/repository.dart';
import 'package:home_inventory/src/ui/home_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('diag: home screen piece by piece', (tester) async {
    final semantics = tester.ensureSemantics();
    final tmp = await Directory.systemTemp.createTemp('ht_diag');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('core.tourDone', true);
    final db = InventoryDb(NativeDatabase(File('${tmp.path}/app.sqlite')));
    Future<void> hold(int secs) async {
      for (var i = 0; i < secs * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    homeDiagLevel.value = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(inventoryConfig),
        inventoryDbProvider.overrideWithValue(db),
        fileSharerProvider.overrideWithValue(RecordingFileSharer()),
        exportDirProvider.overrideWithValue(() async => tmp),
        reviewRequesterProvider.overrideWithValue(RecordingReviewRequester()),
        linkOpenerProvider.overrideWithValue(RecordingLinkOpener()),
        attachmentsDirProvider.overrideWithValue(() async => tmp),
        adsPlatformProvider.overrideWithValue(FakeAdsPlatform(inEeaOrUk: false)),
        entitlementServiceProvider.overrideWithValue(const FreeForNowEntitlementService()),
      ],
      child: const InventoryApp(),
    ));
    await hold(6);
    print('HTDIAG onboarding shown');
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    for (final lv in const [0, 1, 2, 3, 4, 5, 6, 7, 8, 99]) {
      homeDiagLevel.value = lv;
      print('HTDIAG level $lv start');
      await hold(12);
      print('HTDIAG level $lv survived');
    }
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    print('HTDIAG tour start');
    container.read(tourControllerProvider.notifier).start();
    await hold(20);
    print('HTDIAG tour survived');
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}
