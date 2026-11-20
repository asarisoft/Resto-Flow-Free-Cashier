import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/product.dart';
import '../products/product_providers.dart';
import 'product_image.dart';
import 'product_image_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/tap_area.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../categories/category_field.dart';
import '../../core/services/daos/categories_dao.dart';
import '../activity_log/activity_log_providers.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormDialog({super.key, this.product});
  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _hppCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String? _imagePath;
  bool _ready = true;
  bool _saving = false;
  final _imageService = ProductImageService();
  XFile? _pickedFile;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl.text = p?.name ?? '';
    _categoryCtrl.text = p?.category ?? '';
    _priceCtrl.text = p != null ? p.price.toString() : '';
    _hppCtrl.text = p != null ? p.hpp.toString() : '';
    _stockCtrl.text = p?.stock?.toString() ?? '';
    _imagePath = p?.imagePath;
    _ready = p?.ready ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _hppCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return AppFormDialog(
      title: _editing ? 'Edit Produk' : 'Tambah Produk',
      formKey: _formKey,
      saving: _saving,
      submitLabel: _editing ? 'Simpan Perubahan' : 'Tambah',
      onSubmit: _save,
      fields: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: TapArea(
              label: 'Pilih foto produk',
              borderRadius: BorderRadius.circular(12),
              onTap: _saving ? null : _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedFile != null
                    ? Image.file(File(_pickedFile!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                    : (_imagePath != null
                        ? ProductImage(
                            path: _imagePath,
                            placeholder: const Center(
                                child: Icon(AppIcons.brokenImage, size: AppIcons.hero)))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(AppIcons.addPhoto,
                                  size: AppIcons.xl, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              Text('Tap untuk tambah foto',
                                  style: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary)),
                            ],
                          )),
              ),
            ),
                ),
              ),
            ),
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Nama Produk *'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
          textCapitalization: TextCapitalization.words,
        ),
        CategoryField(
          type: CategoryType.product,
          value: _categoryCtrl.text,
          onChanged: (v) => setState(() => _categoryCtrl.text = v ?? ''),
        ),
        TextFormField(
          controller: _priceCtrl,
          decoration: const InputDecoration(labelText: 'Harga Jual (Rp) *', prefixText: 'Rp '),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
            if (int.tryParse(v.trim()) == null) return 'Angka tidak valid';
            return null;
          },
        ),
        TextFormField(
          controller: _hppCtrl,
          decoration: const InputDecoration(labelText: 'HPP (Rp)', hintText: '0', prefixText: 'Rp '),
          keyboardType: TextInputType.number,
        ),
        TextFormField(
          controller: _stockCtrl,
          decoration: const InputDecoration(
            labelText: 'Stok (porsi)',
            hintText: 'Kosong = tidak dilacak',
            helperText: 'Berkurang otomatis saat bayar; 0 = otomatis habis',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Status Ready', style: textTheme.bodyLarge),
          subtitle: Text(_ready ? 'Produk siap dijual' : 'Produk tidak tersedia',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          value: _ready,
          onChanged: (v) => setState(() => _ready = v),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final file = await _imageService.pickImage();
    if (file == null) return;
    setState(() {
      _pickedFile = file;
      _imagePath = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final now = DateTime.now();
      String? imagePath = _imagePath;
      final product = Product(
        id: widget.product?.id,
        name: _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        price: int.parse(_priceCtrl.text.trim()),
        hpp: _hppCtrl.text.trim().isEmpty ? 0 : int.parse(_hppCtrl.text.trim()),
        ready: _ready,
        archived: widget.product?.archived ?? false,
        imagePath: imagePath,
        stock: _stockCtrl.text.trim().isEmpty ? null : int.parse(_stockCtrl.text.trim()),
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );

      String? savedId = product.id;
      if (savedId == null) {
        savedId = await repo.add(product);
      } else {
        await repo.save(product);
      }

      if (_pickedFile != null) {
        if (widget.product?.imagePath != null) {
          await _imageService.deleteLocal(savedId);
        }
        final path = await _imageService.saveLocal(savedId, _pickedFile!);
        final updated = product.copyWith(id: savedId, imagePath: path, updatedAt: now);
        await repo.save(updated);
      }

      await logActivity(
        ref,
        widget.product?.id == null ? 'product.add' : 'product.update',
        product.name,
        detail: 'harga ${product.price}',
      );
      ref.invalidate(productListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal simpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
