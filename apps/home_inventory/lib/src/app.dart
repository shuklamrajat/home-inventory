import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

const featureUnlimitedItems = 'unlimited_items';
const featureExport = 'export';

const inventoryConfig = AppConfig(
  appName: 'Home Inventory',
  tagline: 'Everything you own, ready for an insurance claim',
  seedColor: Color(0xFF6D4C41),
  onboarding: [
    OnboardingPage(
      icon: Icons.chair_outlined,
      title: 'Room by room',
      body: 'Snap a photo, add what it cost. Ten minutes per room is enough to start.',
    ),
    OnboardingPage(
      icon: Icons.verified_outlined,
      title: 'Warranties and receipts',
      body: 'Keep receipts with each item and see which warranties are about to run out.',
    ),
    OnboardingPage(
      icon: Icons.picture_as_pdf_outlined,
      title: 'Claim-ready report',
      body: 'One PDF with photos, values and serial numbers for your insurer. Stays on your phone until you send it.',
    ),
  ],
  proFeatures: [
    ProFeature(id: featureUnlimitedItems, title: 'Unlimited items', description: 'The free version holds $freeLimitText items.'),
    ProFeature(id: featureExport, title: 'Insurance report', description: 'PDF with photos and a CSV for spreadsheets.'),
  ],
);

const freeLimitText = '25';

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) => const CoreApp(home: HomeScreen());
}
