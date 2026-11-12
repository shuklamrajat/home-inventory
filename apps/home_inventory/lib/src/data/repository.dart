import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/inventory_logic.dart';
import 'database.dart';

export 'database.dart';

final inventoryDbProvider = Provider<InventoryDb>((ref) {
  final db = InventoryDb(openAppDatabase('inventory'));
  ref.onDispose(db.close);
  return db;
});

/// Folder that holds photos and receipts.
final attachmentsDirProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'attachments')).create(recursive: true);
  },
);

class PickedImage {
  const PickedImage(this.bytes, this.extension);
  final Uint8List bytes;
  final String extension;
}

/// Where photos come from: the camera or the photo library.
abstract class PhotoSource {
  Future<PickedImage?> pick({required bool camera});
}

class DevicePhotoSource implements PhotoSource {
  @override
  Future<PickedImage?> pick({required bool camera}) async {
    // Downscaled on pick so a 30-item claim PDF stays a sensible size.
    final x = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (x == null) return null;
    final ext = p.extension(x.path).replaceFirst('.', '').toLowerCase();
    return PickedImage(await x.readAsBytes(), ext.isEmpty ? 'jpg' : ext);
  }
}

final photoSourceProvider = Provider<PhotoSource>((ref) => DevicePhotoSource());

final repositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(inventoryDbProvider), ref.watch(attachmentsDirProvider)),
);

const freeItemLimit = 25;

class InventoryRepository {
  InventoryRepository(this.db, this._dir);
  final InventoryDb db;
  final Future<Directory> Function() _dir;

  Future<String> attachmentsPath() async => (await _dir()).path;

  Stream<List<Room>> watchRooms() => (db.select(db.rooms)..orderBy([(r) => OrderingTerm(expression: r.id)])).watch();

  Future<int> addRoom(String name) => db.into(db.rooms).insert(RoomsCompanion.insert(name: name.trim()));

  Future<void> renameRoom(int id, String name) =>
      (db.update(db.rooms)..where((r) => r.id.equals(id))).write(RoomsCompanion(name: Value(name.trim())));

  /// Deletes an empty room; returns false when it still has items.
  Future<bool> deleteRoom(int id) async {
    final n = await (db.select(db.items)..where((i) => i.roomId.equals(id))).get();
    if (n.isNotEmpty) return false;
    await (db.delete(db.rooms)..where((r) => r.id.equals(id))).go();
    return true;
  }

  Stream<List<Item>> watchItems() =>
      (db.select(db.items)..orderBy([(i) => OrderingTerm(expression: i.name.collate(Collate.noCase))])).watch();

  Stream<List<Attachment>> watchAttachments() => db.select(db.attachments).watch();

  Future<int> itemCount() async => (await db.select(db.items).get()).length;

  Future<int> saveItem(ItemsCompanion c) async {
    if (c.id.present) {
      await (db.update(db.items)..where((i) => i.id.equals(c.id.value))).write(c);
      return c.id.value;
    }
    return db.into(db.items).insert(c.copyWith(createdAt: Value(DateTime.now())));
  }

  /// Deletes the item, its attachment rows and the files on disk.
  Future<void> deleteItem(int id) async {
    final atts = await (db.select(db.attachments)..where((a) => a.itemId.equals(id))).get();
    await db.transaction(() async {
      await (db.delete(db.attachments)..where((a) => a.itemId.equals(id))).go();
      await (db.delete(db.items)..where((i) => i.id.equals(id))).go();
    });
    final dir = await attachmentsPath();
    for (final a in atts) {
      final f = File(p.join(dir, a.fileName));
      if (await f.exists()) await f.delete();
    }
  }

  Future<String> storeFile(Uint8List bytes, String ext) async {
    final name = '${const Uuid().v4()}.$ext';
    await File(p.join(await attachmentsPath(), name)).writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<void> addAttachment(int itemId, String kind, String fileName) =>
      db.into(db.attachments).insert(AttachmentsCompanion.insert(itemId: itemId, kind: kind, fileName: fileName));

  Future<void> removeAttachment(Attachment a) async {
    await (db.delete(db.attachments)..where((x) => x.id.equals(a.id))).go();
    final f = File(p.join(await attachmentsPath(), a.fileName));
    if (await f.exists()) await f.delete();
  }
}

// ---------- providers ----------

final attachmentsPathProvider = FutureProvider<String>((ref) => ref.watch(repositoryProvider).attachmentsPath());
final roomsProvider = StreamProvider<List<Room>>((ref) => ref.watch(repositoryProvider).watchRooms());
final itemsProvider = StreamProvider<List<Item>>((ref) => ref.watch(repositoryProvider).watchItems());
final attachmentsProvider = StreamProvider<List<Attachment>>((ref) => ref.watch(repositoryProvider).watchAttachments());

int valueOf(Item i) => itemValue(valueCents: i.valueCents, priceCents: i.priceCents);
