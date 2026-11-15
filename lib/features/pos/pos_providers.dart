import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_provider.dart';
import '../../core/services/daos/sales_dao.dart';
import 'transaction_repository.dart';

final salesDaoProvider =
    Provider<SalesDao>((ref) => SalesDao(ref.watch(databaseProvider)));

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) => TransactionRepository(ref.watch(salesDaoProvider)));
