// Renders store art from the app's own drawings: icon, mascot cut-outs and
// two illustrations. Run with tool/../../../tool/make_store_art.py, which
// frames them into the Play icon, launcher icons and feature graphic.
//   flutter test tool/art_test.dart --dart-define=ART_OUT=<dir>
import 'package:app_core/art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/src/app.dart';
import 'package:home_inventory/src/ui/logo.dart';
import 'package:home_inventory/src/ui/scenes.dart';

const out = String.fromEnvironment('ART_OUT', defaultValue: 'build/art');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('store art', () async {
    // The in-app logo at rest, checked against brand/logo-1024.png.
    await writeScenePng('$out/icon.png', housetallyLogo, const Size(1024, 1024), inventoryConfig, loop: 0);
    await writeScenePng(
      '$out/mascot.png',
      (c, s, f) => housetally(c, Offset(s.width / 2, s.height * 0.9), s.width * 0.62, f),
      const Size(800, 800),
      inventoryConfig,
    );
    await writeScenePng(
      '$out/mascot_dark.png',
      (c, s, f) => housetally(c, Offset(s.width / 2, s.height * 0.9), s.width * 0.62, f),
      const Size(800, 800),
      inventoryConfig,
      brightness: Brightness.dark,
    );
    await writeScenePng('$out/hero.png', roomsScene, const Size(900, 900), inventoryConfig);
    await writeScenePng('$out/pro.png', stackProScene, const Size(1200, 700), inventoryConfig);
  });
}
