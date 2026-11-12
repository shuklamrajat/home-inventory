import 'dart:io';

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
        ? await ex.writePdf('$base.pdf',
            await buildInventoryPdf(rooms, items, atts, await repo.attachmentsPath(), ref.read(coreSettingsProvider).currency, now))
        : await ex.writeCsv('$base.csv', buildInventoryCsv(rooms, items, atts, now));
    await ex.share(file, subject: 'Home inventory');
    await ref.read(ratingPrompterProvider).recordCompletedTask();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final currency = ref.watch(coreSettingsProvider).currency;
    final total = items.fold(0, (a, i) => a + valueOf(i));
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(appConfigProvider).appName),
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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoreSettingsScreen())),
          ),
        ],
      ),
      body: Column(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: StatTile(
                      label: 'Total value', value: Money.format(total, currency: currency), valueKey: const Key('total-value'))),
              Expanded(child: StatTile(label: 'Items', value: '${items.length}', valueKey: const Key('item-count'))),
            ]),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: [
            RoomsTab(onAddItem: (roomId) => _addItem(roomId: roomId)),
            const ItemsTab(),
            const WarrantiesTab(),
          ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-item'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add item'),
        onPressed: _addItem,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(key: Key('tab-rooms'), icon: Icon(Icons.meeting_room_outlined), label: 'Rooms'),
          NavigationDestination(key: Key('tab-items'), icon: Icon(Icons.list_alt), label: 'Items'),
          NavigationDestination(key: Key('tab-warranties'), icon: Icon(Icons.verified_outlined), label: 'Warranties'),
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
        title: const Text('New room'),
        content: TextField(key: const Key('room-name-field'), controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(key: const Key('room-add-ok'), onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Add')),
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
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      for (final r in rooms)
        Builder(builder: (context) {
          final inRoom = items.where((i) => i.roomId == r.id).toList();
          final value = inRoom.fold(0, (a, i) => a + valueOf(i));
          return Card(
            child: ListTile(
              key: Key('room-${r.id}'),
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text(r.name),
              subtitle: Text(inRoom.length == 1 ? '1 item' : '${inRoom.length} items', key: Key('room-count-${r.id}')),
              trailing: Text(Money.format(value, currency: currency), key: Key('room-value-${r.id}')),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => RoomScreen(room: r, onAddItem: () => onAddItem(r.id)))),
            ),
          );
        }),
      Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          key: const Key('add-room'),
          icon: const Icon(Icons.add),
          label: const Text('Add room'),
          onPressed: () => _addRoom(context, ref),
        ),
      ),
    ]);
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
      appBar: AppBar(title: Text(room.name)),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.chair_outlined, title: 'Nothing here yet', body: 'Add the things in this room.')
          : ItemList(items: items),
      floatingActionButton: FloatingActionButton(onPressed: onAddItem, child: const Icon(Icons.add)),
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
    final items = (ref.watch(itemsProvider).value ?? const <Item>[])
        .where((i) => _q.isEmpty || '${i.name} ${i.brand} ${i.serial} ${i.category}'.toLowerCase().contains(_q))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          key: const Key('item-search'),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, brand or serial'),
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        ),
      ),
      Expanded(child: ItemList(items: items)),
    ]);
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
    return Builder(
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final it = items[i];
          final photo = atts.where((a) => a.itemId == it.id && a.kind == 'photo').firstOrNull;
          return Card(
            child: ListTile(
              key: Key('item-${it.id}'),
              leading: photo != null && dir != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(p.join(dir, photo.fileName)),
                          width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image)),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              title: Text(it.name),
              subtitle: Text(rooms[it.roomId] ?? ''),
              trailing: Text(Money.format(valueOf(it), currency: currency)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemEditScreen(item: it))),
            ),
          );
        },
      ),
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
    if (order.isEmpty) {
      return const EmptyState(
          icon: Icons.verified_outlined, title: 'No warranties yet', body: 'Add a warranty end date to an item to see it here.');
    }
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      for (final id in order)
        Builder(builder: (context) {
          final it = byId[id]!;
          final s = warrantyStatus(it.warrantyExpires, now);
          final (label, color) = switch (s.state) {
            WarrantyState.soon => (s.daysLeft == 0 ? 'Ends today' : 'Ends in ${s.daysLeft} days', Colors.orange.shade800),
            WarrantyState.active => ('Active', theme.colorScheme.primary),
            WarrantyState.expired => ('Expired', theme.colorScheme.error),
            WarrantyState.none => ('', theme.colorScheme.outline),
          };
          return Card(
            child: ListTile(
              key: Key('warranty-${it.id}'),
              title: Text(it.name),
              subtitle: Text('Ends ${niceDate(it.warrantyExpires!)}'),
              trailing: Text(label, key: Key('warranty-state-${it.id}'), style: TextStyle(color: color)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemEditScreen(item: it))),
            ),
          );
        }),
    ]);
  }
}
