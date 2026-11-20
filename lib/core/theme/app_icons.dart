import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

/// Satu-satunya sumber ikon (set slim Lucide, garis tipis bobot 300).
/// Layar dilarang memakai `Icons.*` langsung.
class AppIcons {
  AppIcons._();

  // Ukuran (token)
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double hero = 48;

  // Navigasi / fitur
  static const IconData pos = LucideIcons300.calculator;
  static const IconData product = LucideIcons300.package2;
  static const IconData expense = LucideIcons300.receiptText;
  static const IconData report = LucideIcons300.chartColumn;
  static const IconData users = LucideIcons300.users;
  static const IconData category = LucideIcons300.tags;
  static const IconData settings = LucideIcons300.settings;
  static const IconData brand = LucideIcons300.flame;

  // Aksi
  static const IconData add = LucideIcons300.plus;
  static const IconData remove = LucideIcons300.minus;
  static const IconData edit = LucideIcons300.pencil;
  static const IconData check = LucideIcons300.check;
  static const IconData search = LucideIcons300.search;
  static const IconData export = LucideIcons300.fileDown;
  static const IconData delete = LucideIcons300.trash2;
  static const IconData close = LucideIcons300.x;
  static const IconData filterReset = LucideIcons300.filterX;
  static const IconData checkCircle = LucideIcons300.circleCheck;
  static const IconData cart = LucideIcons300.shoppingCart;
  static const IconData refresh = LucideIcons300.refreshCw;
  static const IconData arrowRight = LucideIcons300.arrowRight;
  static const IconData login = LucideIcons300.logIn;
  static const IconData logout = LucideIcons300.logOut;
  static const IconData visible = LucideIcons300.eye;
  static const IconData hidden = LucideIcons300.eyeOff;
  static const IconData key = LucideIcons300.keyRound;

  // Data / berkas
  static const IconData backup = LucideIcons300.download;
  static const IconData restore = LucideIcons300.fileUp;
  static const IconData print = LucideIcons300.printer;
  static const IconData receipt = LucideIcons300.receipt;
  static const IconData wallet = LucideIcons300.wallet;
  static const IconData calendar = LucideIcons300.calendar;
  static const IconData trendingUp = LucideIcons300.trendingUp;
  static const IconData star = LucideIcons300.star;

  // Makanan / gambar
  static const IconData food = LucideIcons300.utensils;
  static const IconData restaurant = LucideIcons300.utensilsCrossed;
  static const IconData addPhoto = LucideIcons300.imagePlus;
  static const IconData brokenImage = LucideIcons300.imageOff;

  // Bluetooth
  static const IconData bluetooth = LucideIcons300.bluetooth;
  static const IconData bluetoothOff = LucideIcons300.bluetoothOff;
  static const IconData bluetoothConnected = LucideIcons300.bluetoothConnected;
}
