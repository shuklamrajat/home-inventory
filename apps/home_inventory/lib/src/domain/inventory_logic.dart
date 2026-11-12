import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Adds calendar months, clamping to the month's last day (31 Jan + 1 = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12, m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}

enum WarrantyState { none, active, soon, expired }

class WarrantyStatus {
  const WarrantyStatus(this.state, this.daysLeft);
  final WarrantyState state;
  final int? daysLeft;
}

const warrantySoonDays = 30;

int _calendarDays(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// A warranty ending today is still valid today.
WarrantyStatus warrantyStatus(DateTime? expires, DateTime now) {
  if (expires == null) return const WarrantyStatus(WarrantyState.none, null);
  final days = _calendarDays(now, expires);
  if (days < 0) return WarrantyStatus(WarrantyState.expired, days);
  return WarrantyStatus(days <= warrantySoonDays ? WarrantyState.soon : WarrantyState.active, days);
}

/// Ids in list order: ending soon (soonest first), then active, then expired
/// (most recently expired first). Items with no warranty are left out.
List<String> sortForWarrantyList(List<({String id, DateTime? expires})> items, DateTime now) {
  int rank(WarrantyState s) => switch (s) {
        WarrantyState.soon => 0,
        WarrantyState.active => 1,
        WarrantyState.expired => 2,
        WarrantyState.none => 3,
      };
  final withW = items.where((i) => i.expires != null).toList()
    ..sort((a, b) {
      final ra = rank(warrantyStatus(a.expires, now).state), rb = rank(warrantyStatus(b.expires, now).state);
      if (ra != rb) return ra - rb;
      return ra == 2 ? b.expires!.compareTo(a.expires!) : a.expires!.compareTo(b.expires!);
    });
  return withW.map((i) => i.id).toList();
}

int itemValue({required int? valueCents, required int? priceCents}) => valueCents ?? priceCents ?? 0;

class LoadedAttachments {
  LoadedAttachments(this.loaded, this.missing);
  final Map<String, Uint8List> loaded;
  final List<String> missing;
}

/// Reads stored attachments by file name from [dir]. Names that are missing
/// or try to leave the folder are reported instead of throwing.
Future<LoadedAttachments> loadAttachments(String dir, List<String> names) async {
  final loaded = <String, Uint8List>{};
  final missing = <String>[];
  for (final n in names) {
    if (n != p.basename(n)) {
      missing.add(n);
      continue;
    }
    final f = File(p.join(dir, n));
    if (await f.exists()) {
      loaded[n] = await f.readAsBytes();
    } else {
      missing.add(n);
    }
  }
  return LoadedAttachments(loaded, missing);
}
