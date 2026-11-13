import 'dart:io';
import 'dart:math' as math;

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../app.dart';
import '../data/repository.dart';
import '../domain/inventory_logic.dart';
import '../export/inventory_export.dart';
import 'format.dart';
import 'item_edit_screen.dart';
import 'scenes.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  Future<void> _addItem({int? roomId}) async {
    final count = await ref.read(repositoryProvider).itemCount();
    if (!mounted) return;
    if (count >= freeItemLimit && !await requirePro(context, ref, featureUnlimitedItems)) return;
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ItemEditScreen(initialRoomId: roomId)));
  }

  Future<void> _export({required bool pdf}) async {
    if (!await requirePro(context, ref, featureExport)) return;
    final repo = ref.read(repositoryProvider);
    final rooms = ref.read(roomsProvider).value ?? const <Room>[];
    final items = ref.read(itemsProvider).value ?? const <Item>[];
    final atts = ref.read(attachmentsProvider).value ?? const <Attachment>[];
    final now = ref.read(clockProvider)();
    final ex = ref.read(exportServiceProvider);
    final base = 'home_inventory_${isoDate(now)}';
    final file = pdf
        ? await ex.writePdf(
            '$base.pdf',
            await buildInventoryPdf(
              rooms,
              items,
              atts,
              await repo.attachmentsPath(),
              ref.read(coreSettingsProvider).currency,
              now,
            ),
          )
        : await ex.writeCsv('$base.csv', buildInventoryCsv(rooms, items, atts, now));
    await ex.share(file, subject: 'Home inventory');
    await ref.read(ratingPrompterProvider).recordCompletedTask();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 30),
            const SizedBox(width: 8),
            Text(ref.watch(appConfigProvider).appName),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('export-menu'),
            icon: const Icon(Icons.ios_share),
            onSelected: (v) => _export(pdf: v == 'pdf'),
            itemBuilder: (_) => const [
              PopupMenuItem(key: Key('export-pdf'), value: 'pdf', child: Text('Insurance report (PDF)')),
              PopupMenuItem(key: Key('export-csv'), value: 'csv', child: Text('Spreadsheet (CSV)')),
            ],
          ),
          IconButton(
            key: const Key('open-settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoreSettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          const _ValueHero(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                RoomsTab(onAddItem: (roomId) => _addItem(roomId: roomId)),
                const ItemsTab(),
                const WarrantiesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-item'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add item'),
        onPressed: _addItem,
      ),
      bottomNavigationBar: AdDock(
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              key: Key('tab-rooms'),
              icon: Icon(Icons.house_outlined),
              selectedIcon: Icon(Icons.house_rounded),
              label: 'Rooms',
            ),
            NavigationDestination(
              key: Key('tab-items'),
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Items',
            ),
            NavigationDestination(
              key: Key('tab-warranties'),
              icon: Icon(Icons.verified_outlined),
              selectedIcon: Icon(Icons.verified_rounded),
              label: 'Warranties',
            ),
          ],
        ),
      ),
    );
  }
}

// The Housetally mascot, peeking out of the value ring.
void _mascot(Canvas c, Size s, SceneFrame f) =>
    housetally(c, Offset(s.width / 2, s.height * 0.98), s.width * 0.95, f, blink: _blink(f.loop));

double _blink(double loop) {
  final t = (loop * 2) % 1;
  return t > 0.93 ? math.sin((t - 0.93) / 0.07 * math.pi) : 0;
}

/// Colours for rooms in the chart and on the room cards, in value order.
List<Color> roomPalette(BuildContext context) {
  final s = Theme.of(context).colorScheme;
  final b = BrandColors.of(context);
  return [s.primary, b.accent, const Color(0xFF8E5A9B), const Color(0xFF3F8F7A), const Color(0xFF4F7CC4), s.tertiary];
}

/// Rooms with their value, most valuable first; rooms worth nothing are left out.
List<(Room, int)> roomValues(List<Room> rooms, List<Item> items) {
  final out = [
    for (final r in rooms) (r, items.where((i) => i.roomId == r.id).fold(0, (a, i) => a + valueOf(i))),
  ].where((e) => e.$2 > 0).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  return out;
}

IconData roomIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('kitchen')) return Icons.kitchen_rounded;
  if (n.contains('living') || n.contains('lounge')) return Icons.weekend_rounded;
  if (n.contains('bed')) return Icons.bed_rounded;
  if (n.contains('bath')) return Icons.bathtub_rounded;
  if (n.contains('garage')) return Icons.garage_rounded;
  if (n.contains('office') || n.contains('study')) return Icons.desk_rounded;
  if (n.contains('basement') || n.contains('cellar')) return Icons.stairs_rounded;
  if (n.contains('garden') || n.contains('yard')) return Icons.yard_rounded;
  if (n.contains('kid') || n.contains('nursery')) return Icons.toys_rounded;
  return Icons.meeting_room_rounded;
}

class _ValueHero extends ConsumerWidget {
  const _ValueHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final currency = ref.watch(coreSettingsProvider).currency;
    final total = items.fold(0, (a, i) => a + valueOf(i));
    final brand = BrandColors.of(context);
    final theme = Theme.of(context);
    final values = roomValues(rooms, items);
    final palette = roomPalette(context);
    String money(int c) => Money.format(c, currency: currency);
    String pct(int part) => total == 0 ? '0%' : '${(part * 100 / total).round()}%';
    final label = values.isEmpty
        ? 'Value by room. Nothing valued yet.'
        : 'Value by room. ${[for (final (r, v) in values) '${r.name} ${money(v)}, ${pct(v)}.'].join(' ')}';
    return BrandPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOME VALUE',
                  style: TextStyle(
                    color: brand.onBrand.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUpText(
                    value: total.toDouble(),
                    format: (v) => money(v.round()),
                    textKey: const Key('total-value'),
                    style: theme.textTheme.headlineMedium?.copyWith(color: brand.onBrand, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _HeroChip(
                      icon: Icons.inventory_2_rounded,
                      label: 'Items',
                      value: '${items.length}',
                      valueKey: const Key('item-count'),
                    ),
                    _HeroChip(icon: Icons.house_rounded, label: 'Rooms', value: '${rooms.length}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDonut(
            key: const Key('room-chart'),
            size: 104,
            thickness: 14,
            parts: values.isEmpty
                ? [ChartPart(1, brand.onBrand.withValues(alpha: 0.2))]
                : [
                    for (var i = 0; i < values.length; i++)
                      ChartPart(values[i].$2.toDouble(), palette[i % palette.length]),
                  ],
            semanticsLabel: label,
            center: SizedBox(width: 54, height: 54, child: AnimatedScene(paint: _mascot, aspectRatio: 1)),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, required this.value, this.valueKey});
  final IconData icon;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: brand.onBrand.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: brand.onBrand),
          const SizedBox(width: 5),
          Text('$label ', style: TextStyle(color: brand.onBrand.withValues(alpha: 0.8), fontSize: 12)),
          Text(
            value,
            key: valueKey,
            style: TextStyle(color: brand.onBrand, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class RoomsTab extends ConsumerWidget {
  const RoomsTab({super.key, required this.onAddItem});
  final void Function(int roomId) onAddItem;

  Future<void> _addRoom(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.add_home_rounded),
        title: const Text('New room'),
        content: TextField(
          key: const Key('room-name-field'),
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Kitchen, Garage, Office'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            key: const Key('room-add-ok'),
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) await ref.read(repositoryProvider).addRoom(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final currency = ref.watch(coreSettingsProvider).currency;
    final theme = Theme.of(context);
    final palette = roomPalette(context);
    final ranked = [for (final (r, _) in roomValues(rooms, items)) r.id];
    final top = rooms.fold(
      0,
      (m, r) => math.max(m, items.where((i) => i.roomId == r.id).fold(0, (a, i) => a + valueOf(i))),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        SectionHeader(
          'Rooms',
          trailing: TextButton.icon(
            key: const Key('add-room'),
            icon: const Icon(Icons.add_home_outlined),
            label: const Text('Add room'),
            onPressed: () => _addRoom(context, ref),
          ),
        ),
        for (final (i, r) in rooms.indexed)
          Builder(
            builder: (context) {
              final inRoom = items.where((it) => it.roomId == r.id).toList();
              final value = inRoom.fold(0, (a, it) => a + valueOf(it));
              final rank = ranked.indexOf(r.id);
              final color = rank < 0 ? theme.colorScheme.outline : palette[rank % palette.length];
              return Appear(
                index: i,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: Key('room-${r.id}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomScreen(room: r, onAddItem: () => onAddItem(r.id)),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                      child: Row(
                        children: [
                          IconBadge(icon: roomIcon(r.name), color: color),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(r.name, style: theme.textTheme.titleMedium)),
                                    Text(
                                      Money.format(value, currency: currency),
                                      key: Key('room-value-${r.id}'),
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inRoom.length == 1 ? '1 item' : '${inRoom.length} items',
                                  key: Key('room-count-${r.id}'),
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                _ValueBar(fraction: top == 0 ? 0 : value / top, color: color),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// A slim bar that grows to its share of the most valuable room.
class _ValueBar extends StatelessWidget {
  const _ValueBar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: color.withValues(alpha: 0.14))),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
              duration: Motion.of(context, 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key, required this.room, required this.onAddItem});
  final Room room;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = (ref.watch(itemsProvider).value ?? const <Item>[]).where((i) => i.roomId == room.id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roomIcon(room.name)),
            const SizedBox(width: 8),
            Flexible(child: Text(room.name)),
          ],
        ),
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.chair_outlined,
              scene: openBoxScene,
              title: 'Nothing here yet',
              body: 'Add the things in this room. A photo and a price is all it takes.',
            )
          : ItemList(items: items),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add item',
        onPressed: onAddItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ItemsTab extends ConsumerStatefulWidget {
  const ItemsTab({super.key});

  @override
  ConsumerState<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends ConsumerState<ItemsTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(itemsProvider).value ?? const <Item>[];
    final items = all
        .where((i) => _q.isEmpty || '${i.name} ${i.brand} ${i.serial} ${i.category}'.toLowerCase().contains(_q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            key: const Key('item-search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search name, brand or serial',
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: all.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  scene: openBoxScene,
                  title: 'Start your tally',
                  body: 'Snap a photo of something you own, add what it cost, and it lands in its room.',
                )
              : ItemList(items: items),
        ),
      ],
    );
  }
}

class ItemList extends ConsumerWidget {
  const ItemList({super.key, required this.items});
  final List<Item> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(coreSettingsProvider).currency;
    final dir = ref.watch(attachmentsPathProvider).value;
    final atts = ref.watch(attachmentsProvider).value ?? const <Attachment>[];
    final rooms = {for (final r in ref.watch(roomsProvider).value ?? const <Room>[]) r.id: r.name};
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        final photo = atts.where((a) => a.itemId == it.id && a.kind == 'photo').firstOrNull;
        final hasReceipt = atts.any((a) => a.itemId == it.id && a.kind == 'receipt');
        final room = rooms[it.roomId] ?? '';
        return Appear(
          index: i,
          child: Card(
            child: ListTile(
              key: Key('item-${it.id}'),
              contentPadding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
              leading: photo != null && dir != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(p.join(dir, photo.fileName)),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                      ),
                    )
                  : IconBadge(icon: roomIcon(room), size: 48),
              title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Row(
                children: [
                  Flexible(child: Text(room, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (hasReceipt) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.receipt_long_rounded, size: 14, color: theme.colorScheme.primary),
                  ],
                  if (it.warrantyExpires != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified_rounded, size: 14, color: BrandColors.of(context).success),
                  ],
                ],
              ),
              trailing: Text(
                Money.format(valueOf(it), currency: currency),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemEditScreen(item: it))),
            ),
          ),
        );
      },
    );
  }
}

class WarrantiesTab extends ConsumerWidget {
  const WarrantiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final now = ref.watch(clockProvider)();
    final byId = {for (final i in items) '${i.id}': i};
    final order = sortForWarrantyList([for (final i in items) (id: '${i.id}', expires: i.warrantyExpires)], now);
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    if (order.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_outlined,
        scene: shieldScene,
        title: 'No warranties yet',
        body: 'Add a warranty end date to an item and Housetally counts down to it for you.',
      );
    }
    final soon = order.where((id) => warrantyStatus(byId[id]!.warrantyExpires, now).state == WarrantyState.soon).length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        SectionHeader(
          'Warranties',
          trailing: soon == 0
              ? Pill(text: 'All covered', icon: Icons.verified_rounded, color: brand.success)
              : Pill(text: '$soon ending soon', icon: Icons.timer_outlined, color: brand.warning),
        ),
        for (final (i, id) in order.indexed)
          Builder(
            builder: (context) {
              final it = byId[id]!;
              final s = warrantyStatus(it.warrantyExpires, now);
              final (label, color, icon) = switch (s.state) {
                WarrantyState.soon => (
                  s.daysLeft == 0 ? 'Ends today' : 'Ends in ${s.daysLeft} days',
                  brand.warning,
                  Icons.timer_rounded,
                ),
                WarrantyState.active => ('Active', brand.success, Icons.verified_rounded),
                WarrantyState.expired => ('Expired', theme.colorScheme.error, Icons.gpp_bad_rounded),
                WarrantyState.none => ('', theme.colorScheme.outline, Icons.help_outline),
              };
              final start = it.purchaseDate ?? it.createdAt;
              final span = it.warrantyExpires!.difference(start).inHours;
              final used = span <= 0 ? 1.0 : (now.difference(start).inHours / span).clamp(0.0, 1.0);
              return Appear(
                index: i,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: Key('warranty-${it.id}'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemEditScreen(item: it))),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                      child: Row(
                        children: [
                          IconBadge(icon: icon, color: color),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(it.name, style: theme.textTheme.titleMedium)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        label,
                                        key: Key('warranty-state-${it.id}'),
                                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('Ends ${niceDate(it.warrantyExpires!)}', style: theme.textTheme.bodySmall),
                                const SizedBox(height: 8),
                                _ValueBar(fraction: used, color: color),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
