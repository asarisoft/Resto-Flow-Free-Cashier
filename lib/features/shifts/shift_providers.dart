import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_provider.dart';
import '../../core/services/daos/shifts_dao.dart';
import '../../models/shift.dart';

final shiftsDaoProvider =
    Provider<ShiftsDao>((ref) => ShiftsDao(ref.watch(databaseProvider)));

final openShiftProvider = StreamProvider<Shift?>((ref) {
  return ref.watch(shiftsDaoProvider).watchOpen();
});

final shiftHistoryProvider = StreamProvider<List<Shift>>((ref) {
  return ref.watch(shiftsDaoProvider).watchAll();
});
