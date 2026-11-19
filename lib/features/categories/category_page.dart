import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/categories_dao.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/choice_segment.dart';
import '../../core/widgets/empty_state.dart';
import 'category_form_dialog.dart';
import 'category_providers.dart';
import '../users/users_providers.dart';

/// Kelola kategori produk & pengeluaran (Owner).
class CategoryPage extends ConsumerStatefulWidget {
  final String initialType;
  const CategoryPage({super.key, this.initialType = CategoryType.product});

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  late String _type = widget.initialType;

  Future<void> _delete(CategoryEntry c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text('Hapus kategori "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(categoriesDaoProvider).delete(c.id);
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canManageProductsProvider)) {
      return const Scaffold(body: Center(child: Text('Hanya Owner yang bisa mengelola kategori')));
    }
    final list = ref.watch(categoryListProvider(_type));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kategori'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_category',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(AppIcons.add),
        label: const Text('Tambah'),
        onPressed: () => showDialog(context: context, builder: (_) => CategoryFormDialog(type: _type)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              ChoiceSegment<String>(
                value: _type,
                options: const [(CategoryType.product, 'Produk'), (CategoryType.expense, 'Pengeluaran')],
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 16),
              list.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (rows) => AppDataTable<CategoryEntry>(
                  rows: rows,
                  empty: const EmptyState(
                    icon: AppIcons.category,
                    title: 'Belum ada kategori',
                    subtitle: 'Tambah kategori pertama Anda',
                  ),
                  columns: [
                    AppColumn(label: 'Nama', flex: 3, minWidth: 180, cell: (c) => Text(c.name)),
                    AppColumn(label: 'Dipakai', minWidth: 100, numeric: true, cell: (c) => Text('${c.usage} item')),
                    AppColumn(
                      label: '',
                      minWidth: 120,
                      numeric: true,
                      cell: (c) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Ubah ${c.name}',
                            icon: const Icon(AppIcons.edit),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => CategoryFormDialog(type: _type, entry: c),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hapus ${c.name}',
                            icon: const Icon(AppIcons.delete),
                            onPressed: () => _delete(c),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
