import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/clay.dart';
import '../onboarding/onboarding_page.dart';
import '../settings/settings_providers.dart';
import '../pos/pos_page.dart';
import '../products/product_list_page.dart';
import '../reports/report_page.dart';
import '../settings/settings_page.dart';
import '../users/user_list_page.dart';
import '../users/users_providers.dart';
import '../auth/auth_controller.dart' show currentUserProvider;
import '../users/password_dialogs.dart';
import '../expenses/expense_list_page.dart';
import '../backup/backup_reminder.dart';
import '../support/support_page.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/tap_area.dart';
enum HomeTab { pos, products, expenses, reports, settings, users, support }

/// Tabs visible for the current role. Pages, sidebar and bottom nav all use
/// this list so their order and indexes stay in sync.
List<HomeTab> visibleHomeTabs({
  required bool canReports,
  required bool canSettings,
  required bool canUsers,
  required bool canExpenses,
}) =>
    [
      HomeTab.pos,
      HomeTab.products,
      if (canExpenses) HomeTab.expenses,
      if (canReports) HomeTab.reports,
      if (canSettings) HomeTab.settings,
      if (canUsers) HomeTab.users,
      HomeTab.support,
    ];

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (profile) {
        if (profile == null) return const OnboardingPage();
        return const _MainShell();
      },
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _forceDefaultPasswordChange());
  }

  /// Password owner bawaan tertulis di kode: wajib diganti sebelum bekerja.
  Future<void> _forceDefaultPasswordChange() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (!await ref.read(usersDaoProvider).usesDefaultPassword(user.id)) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangePasswordDialog(userId: user.id, forced: true),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      child: TapArea(
        label: label,
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _tab = index),
        child: Container(
          decoration: isSelected ? ClayDecoration.box(radius: 18) : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.titleMedium?.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _pageFor(HomeTab tab) => switch (tab) {
        HomeTab.pos => const PosPage(),
        HomeTab.products => const ProductListPage(),
        HomeTab.expenses => const ExpenseListPage(),
        HomeTab.reports => const ReportPage(),
        HomeTab.settings => const SettingsPage(),
        HomeTab.users => const UserListPage(),
        HomeTab.support => const SupportPage(),
      };

  NavigationDestination _navDestination(HomeTab tab) {
    final (icon, selectedIcon, label) = switch (tab) {
      HomeTab.pos => (AppIcons.pos, AppIcons.pos, 'Kasir'),
      HomeTab.products => (AppIcons.product, AppIcons.product, 'Produk'),
      HomeTab.expenses => (AppIcons.expense, AppIcons.expense, 'Pengeluaran'),
      HomeTab.reports => (AppIcons.report, AppIcons.report, 'Laporan'),
      HomeTab.settings => (AppIcons.settings, AppIcons.settings, 'Pengaturan'),
      HomeTab.users => (AppIcons.users, AppIcons.users, 'Pengguna'),
      HomeTab.support => (AppIcons.support, AppIcons.support, 'Dukung'),
    };
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon, color: AppColors.primary),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canReports = ref.watch(canSeeReportsProvider);
    final canSettings = ref.watch(canSeeSettingsProvider);
    final canUsers = ref.watch(canManageUsersProvider);
    final canExpenses = ref.watch(canSeeExpensesProvider);
    final tabs = visibleHomeTabs(
      canReports: canReports,
      canSettings: canSettings,
      canUsers: canUsers,
      canExpenses: canExpenses,
    );
    final pages = [for (final tab in tabs) _pageFor(tab)];
    // Role can change while the shell is alive; ignore stale tab indexes.
    final current = _tab < tabs.length ? _tab : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              // Sidebar setinggi layar (bukan kotak mengambang di tengah).
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar
                Container(
                  width: 250,
                  color: AppColors.background,
                  child: SingleChildScrollView(clipBehavior: Clip.none, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Icon(AppIcons.brand, color: AppColors.primary, size: AppIcons.xl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Resto Flow Free',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text('MENU UTAMA', style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
                      ),
                      _buildSidebarItem(tabs.indexOf(HomeTab.pos), AppIcons.pos, 'Kasir'),
                      if (canReports) _buildSidebarItem(tabs.indexOf(HomeTab.reports), AppIcons.report, 'Laporan'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(top: 16),
                        child: Text('KELOLA', style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
                      ),
                      _buildSidebarItem(tabs.indexOf(HomeTab.products), AppIcons.product, 'Produk'),
                      if (canExpenses) _buildSidebarItem(tabs.indexOf(HomeTab.expenses), AppIcons.expense, 'Pengeluaran'),
                      if (canUsers) _buildSidebarItem(tabs.indexOf(HomeTab.users), AppIcons.users, 'Pengguna'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(top: 16),
                        child: Text('BANTUAN', style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
                      ),
                      if (canSettings) _buildSidebarItem(tabs.indexOf(HomeTab.settings), AppIcons.settings, 'Pengaturan'),
                      _buildSidebarItem(tabs.indexOf(HomeTab.support), AppIcons.support, 'Dukung Developer'),
                    ],
                  )),
                ),
                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      const BackupReminderBanner(),
                      Expanded(
                        child: IndexedStack(
                          index: current,
                          children: pages,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // HP: maks 5 tab agar label tidak patah; Pengguna & Dukung Developer
        // dibuka dari Pengaturan (Dukung tetap di bar bila tab < 5, mis. Kasir).
        final navTabs = [
          for (final t in tabs)
            if (t != HomeTab.users &&
                !(t == HomeTab.support && canSettings))
              t
        ];
        final navCurrent = _tab < navTabs.length ? _tab : 0;
        final navPages = [for (final t in navTabs) pages[tabs.indexOf(t)]];

        return Scaffold(
          body: Column(
            children: [
              const BackupReminderBanner(),
              Expanded(
                child: IndexedStack(
                  index: navCurrent,
                  children: navPages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(color: AppColors.clayShadow, offset: Offset(0, -6), blurRadius: 18),
              ],
            ),
            child: NavigationBar(
              selectedIndex: navCurrent,
              onDestinationSelected: (i) => setState(() => _tab = i),
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.peach,
              destinations: [for (final tab in navTabs) _navDestination(tab)],
            ),
          ),
        );
      },
    );
  }
}
