import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import 'ui/home_screen.dart';
import 'ui/logo.dart';
import 'ui/scenes.dart';

const featureUnlimitedItems = 'unlimited_items';
const featureExport = 'export';

const inventoryConfig = AppConfig(
  appName: 'Housetally',
  tagline: 'Everything you own, ready for an insurance claim',
  privacyPolicyUrl: 'https://shuklamrajat.github.io/widdle-privacy/housetally/',
  seedColor: Color(0xFFA1452C),
  accentColor: Color(0xFFF2B33D),
  gradientEndColor: Color(0xFF5D2E46),
  paywallScene: stackProScene,
  logo: housetallyLogo,
  onboarding: [
    OnboardingPage(
      icon: Icons.chair_outlined,
      scene: roomsScene,
      title: 'Room by room',
      body: 'Snap a photo, add what it cost. Ten minutes per room is enough to start.',
    ),
    OnboardingPage(
      icon: Icons.verified_outlined,
      scene: warrantyScene,
      title: 'Warranties and receipts',
      body: 'Keep receipts with each item and see which warranties are about to run out.',
    ),
    OnboardingPage(
      icon: Icons.picture_as_pdf_outlined,
      scene: reportScene,
      title: 'Claim-ready report',
      body: 'One PDF with photos, values and serial numbers for your insurer. Stays on your phone until you send it.',
    ),
  ],
  tour: [
    TourStep(
      target: 'add-item',
      icon: Icons.add_box_outlined,
      title: 'Add what you own',
      body: 'Tap here for each item: what it cost, which room it is in, a photo of it and its receipt.',
    ),
    TourStep(
      target: 'tab-rooms',
      icon: Icons.meeting_room_outlined,
      title: 'Room by room',
      body: 'See what each room is worth, and add rooms of your own.',
    ),
    TourStep(
      target: 'tab-items',
      icon: Icons.search,
      title: 'Every item',
      body: 'The whole list in one place, with search.',
    ),
    TourStep(
      target: 'tab-warranties',
      icon: Icons.verified_outlined,
      title: 'Warranties',
      body: 'Warranties sorted by when they run out, so none lapses unnoticed.',
    ),
    TourStep(
      target: 'export-menu',
      icon: Icons.ios_share,
      title: 'Ready for a claim',
      body: 'Export an insurance report or a spreadsheet of everything you own.',
    ),
    TourStep(
      target: 'open-settings',
      icon: Icons.tune,
      title: 'Settings and Pro',
      body: 'Currency, theme and Pro features live here. You can take this tour again from Settings any time.',
    ),
  ],
  proFeatures: [
    ProFeature(
      id: featureUnlimitedItems,
      title: 'Unlimited items',
      description: 'The free version holds $freeLimitText items.',
    ),
    ProFeature(
      id: featureExport,
      title: 'Insurance report',
      description: 'PDF with photos and a CSV for spreadsheets.',
    ),
  ],
);

const freeLimitText = '25';

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) => const CoreApp(home: HomeScreen());
}
