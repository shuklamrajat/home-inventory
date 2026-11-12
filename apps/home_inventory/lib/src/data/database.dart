import 'package:drift/drift.dart';

part 'database.g.dart';

class Rooms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
}

class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get roomId => integer().references(Rooms, #id)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get brand => text().withDefault(const Constant(''))();
  TextColumn get serial => text().withDefault(const Constant(''))();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  IntColumn get priceCents => integer().nullable()();

  /// What it would cost to replace today; falls back to the price.
  IntColumn get valueCents => integer().nullable()();
  DateTimeColumn get warrantyExpires => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
}

/// A photo or receipt. [fileName] is relative to the attachments folder so
/// the path survives the app's folder moving (it does on iOS updates).
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()(); // 'photo' | 'receipt'
  TextColumn get fileName => text()();
}

@DriftDatabase(tables: [Rooms, Items, Attachments])
class InventoryDb extends _$InventoryDb {
  InventoryDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final r in const ['Living room', 'Kitchen', 'Bedroom', 'Office', 'Garage']) {
            await into(rooms).insert(RoomsCompanion.insert(name: r));
          }
        },
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
