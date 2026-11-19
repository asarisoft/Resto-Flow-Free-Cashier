import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../onboarding/onboarding_page.dart';
import '../settings/settings_providers.dart';
import '../pos/pos_page.dart';
import '../products/product_list_page.dart';
import '../reports/report_page.dart';
import '../settings/settings_page.dart';
import '../users/user_list_page.dart';
import '../users/users_providers.dart';
import '../expenses/expense_list_page.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/tap_area.dart';
enum HomeTab { pos, products, expenses, reports, settings, users }

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

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _tab == index;
    return TapArea(
      label: label,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
      onTap: () => setState(() => _tab = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
          border: isSelected
              ? const Border(left: BorderSide(color: AppColors.primary, width: 4))
              : const Border(left: BorderSide(color: Colors.transparent, width: 4)),
        ),
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
    );
  }

  Widget _pageFor(HomeTab tab) => switch (tab) {
        HomeTab.pos => const PosPage(),
        HomeTab.products => const ProductListPage(),
        HomeTab.expenses => const ExpenseListPage(),
        HomeTab.reports => const ReportPage(),
        HomeTab.settings => const SettingsPage(),
        HomeTab.users => const UserListPage(),
      };

  NavigationDestination _navDestination(HomeTab tab) {
    final (icon, selectedIcon, label) = switch (tab) {
      HomeTab.pos => (AppIcons.pos, AppIcons.pos, 'Kasir'),
      HomeTab.products => (AppIcons.product, AppIcons.product, 'Produk'),
      HomeTab.expenses => (AppIcons.expense, AppIcons.expense, 'Pengeluaran'),
      HomeTab.reports => (AppIcons.report, AppIcons.report, 'Laporan'),
      HomeTab.settings => (AppIcons.settings, AppIcons.settings, 'Pengaturan'),
      HomeTab.users => (AppIcons.users, AppIcons.users, 'Pengguna'),
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
              children: [
                // Sidebar
                Container(
                  width: 250,
                  color: AppColors.surface,
                  child: SingleChildScrollView(child: Column(
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
                    ],
                  )),
                ),
                // Main Content
                Expanded(
                  child: IndexedStack(
                    index: current,
                    children: pages,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: current,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: current,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.2),
            destinations: [for (final tab in tabs) _navDestination(tab)],
          ),
        );
      },
    );
  }
}
