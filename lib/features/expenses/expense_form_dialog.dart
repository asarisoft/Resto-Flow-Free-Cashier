import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import 'expense_providers.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/theme/app_colors.dart';

/// Parses an expense amount. Returns null unless it is a positive integer.
int? parseExpenseAmount(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) return null;
  return value;
}

String formatExpenseDate(DateTime date) =>
    DateFormat('dd/MM/yyyy').format(date);

class ExpenseFormDialog extends ConsumerStatefulWidget {
  /// `null` = tambah baru; terisi = ubah/hapus pengeluaran tsb.
  final Expense? expense;
  const ExpenseFormDialog({super.key, this.expense});

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _categoryCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _categoryCtrl.text = e.category ?? '';
      _noteCtrl.text = e.note ?? '';
      _amountCtrl.text = e.amount.toString();
      _date = e.date;
    }
    _dateCtrl.text = formatExpenseDate(_date);
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _dateCtrl.text = formatExpenseDate(picked);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseExpenseAmount(_amountCtrl.text)!;
    setState(() => _saving = true);
    try {
      final category = _categoryCtrl.text.trim();
      final note = _noteCtrl.text.trim();
      final repo = ref.read(expenseRepositoryProvider);
      final old = widget.expense;
      if (old != null) {
        await repo.save(old.copyWith(
          category: category.isEmpty ? null : category,
          note: note.isEmpty ? null : note,
          amount: amount,
          date: _date,
        ));
      } else {
        await repo.add(Expense(
          category: category.isEmpty ? null : category,
          note: note.isEmpty ? null : note,
          amount: amount,
          date: _date,
          createdAt: DateTime.now(),
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal simpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pengeluaran?'),
        content: const Text('Hapus pengeluaran ini? Tindakan ini tidak bisa dibatalkan.'),
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
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepositoryProvider).delete(widget.expense!.id!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: _editing ? 'Ubah Pengeluaran' : 'Tambah Pengeluaran',
      onDelete: _editing ? _delete : null,
      formKey: _formKey,
      saving: _saving,
      submitLabel: 'Simpan',
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _categoryCtrl,
          decoration: const InputDecoration(
            labelText: 'Kategori',
            hintText: 'Bahan, Listrik, Gaji, dll',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        TextFormField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: 'Catatan'),
          textCapitalization: TextCapitalization.sentences,
        ),
        TextFormField(
          controller: _amountCtrl,
          decoration: const InputDecoration(
            labelText: 'Nominal (Rp) *',
            prefixText: 'Rp ',
          ),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
            if (parseExpenseAmount(v) == null) {
              return 'Nominal harus angka lebih dari 0';
            }
            return null;
          },
        ),
        TextFormField(
          controller: _dateCtrl,
          decoration: const InputDecoration(
            labelText: 'Tanggal',
            suffixIcon: Icon(AppIcons.calendar),
          ),
          readOnly: true,
          onTap: _saving ? null : _pickDate,
        ),
      ],
    );
  }
}
