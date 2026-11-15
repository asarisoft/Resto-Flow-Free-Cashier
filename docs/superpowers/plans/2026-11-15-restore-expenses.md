# Restore Expenses Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the Expenses (pengeluaran) feature that was deleted in the offline rebuild, but keep it fully offline on Drift/SQLite — no Firebase.

**Architecture:** SQLite `Expenses` table → `ExpensesDao` → `ExpenseRepository` → Riverpod providers → `ExpenseListPage` / form. Reports read expenses through `ReportsDao` for totals/net profit.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), go_router.

**Context:** `docs/superpowers/plans/2026-11-15-offline-pos-rebuild.md` Task 9 removed Expenses. This plan intentionally reverses that removal. The old plan stays as historical record; do not edit it.

## Global Constraints

- 100% offline. No Firebase.
- Money is `int` rupiah. Never `double`.
- Expenses are Owner-only.
- Existing data must survive migration: v2 → v3 only adds a table; never drop user data.
- Every write path needs a test (money/data rule from AGENTS.md).

---

## Task 1: DB schema v3 — add Expenses table

**Files:**
- Modify: `lib/core/services/database.dart`
- Test: `test/database_test.dart`

**Interfaces:**
- Produces `class Expenses extends Table`:
  - `id (text, pk)`
  - `category (text, nullable)`
  - `note (text, nullable)`
  - `amount (int)`
  - `date (dateTime)`
  - `createdAt (dateTime)`
- `AppDatabase.schemaVersion => 3`.
- Migration: `if (from < 3) await m.createTable(expenses);`
- Keep v1→v2 migration unchanged.

- [x] **Step 1: Write failing test**
  - Insert an expense through Drift, read it back, assert `amount`.
  - Assert `schemaVersion == 3`.
- [x] **Step 2: Run, verify fail.**
  - `fvm flutter test test/database_test.dart`
- [x] **Step 3: Add table + migration.**
  - Run `fvm dart run build_runner build`.
- [x] **Step 4: Run, verify pass.**
- [x] **Step 5: Commit**
  ```bash
  git add lib/core/services/database.dart lib/core/services/database.g.dart test/database_test.dart
  git commit -m "feat: restore Expenses table (schema v3)"
  ```

---

## Task 2: Expense model + DAO

**Files:**
- Create: `lib/models/expense.dart`
- Create: `lib/core/services/daos/expenses_dao.dart`
- Test: `test/models/expense_test.dart`
- Test: `test/daos/expenses_dao_test.dart`

**Interfaces:**
- `class Expense { String? id; String? category; String? note; int amount; DateTime date; DateTime createdAt; }`
- `ExpensesDao(AppDatabase db)`:
  - `getAll() -> Future<List<Expense>>` ordered by date desc
  - `watchAll() -> Stream<List<Expense>>`
  - `add(Expense e) -> Future<String>`
  - `save(Expense e) -> Future<void>`
  - `delete(String id) -> Future<void>`
  - `sum(DateTime start, DateTime end) -> Future<int>`
- DAO maps Drift row → `Expense`; model stays plain.

- [x] **Step 1: Write failing model test** (amount int, copyWith).
- [x] **Step 2: Write failing DAO tests**:
  - add then getAll returns row
  - delete removes row
  - sum only counts range
- [x] **Step 3: Run, verify fail.**
- [x] **Step 4: Implement model + DAO.**
- [x] **Step 5: Run, verify pass.**
  - `fvm flutter test test/models/expense_test.dart test/daos/expenses_dao_test.dart`
- [x] **Step 6: Commit**

---

## Task 3: Repository + providers

**Files:**
- Create: `lib/features/expenses/expense_repository.dart`
- Create: `lib/features/expenses/expense_providers.dart`
- Test: `test/features/expenses/expense_repository_test.dart`

**Interfaces:**
- `ExpenseRepository(ExpensesDao dao)`:
  - `getAll`, `stream`, `add`, `save`, `delete`, `sum`
- Providers:
  - `expensesDaoProvider = Provider<ExpensesDao>`
  - `expenseRepositoryProvider = Provider<ExpenseRepository>`
  - `expenseListProvider = StreamProvider<List<Expense>>`
- Tests use in-memory `AppDatabase.forTest()`.

- [x] **Step 1: Write failing repository test** (add → stream contains row; sum range).
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement repository + providers.**
- [x] **Step 4: Run, verify pass.**
- [x] **Step 5: Commit**

---

## Task 4: Expenses UI + navigation

**Files:**
- Create: `lib/features/expenses/expense_list_page.dart`
- Create: `lib/features/expenses/expense_form_dialog.dart`
- Modify: `lib/features/home/home_shell.dart`
- Test: `test/features/expenses/expense_page_test.dart` (widget test if practical)

**Interfaces:**
- `ExpenseListPage`: list expenses (category, note, amount, date), total this month, FAB "Tambah".
- `ExpenseFormDialog`: fields category, note, amount (int), date; save via repository.
- Home shell: add Expenses tab after Products, **Owner-only** using `canSeeExpensesProvider`.
- Bottom navigation and side rail must use the same filtered tab list. Do not repeat the old index-mismatch bug.

- [ ] **Step 1: Write failing test** for amount parsing (reject non-int/negative).
- [ ] **Step 2: Implement list page + dialog** using existing `AppCard`/`PrimaryButton`.
- [ ] **Step 3: Add tab + provider guard.**
- [ ] **Step 4: Run `fvm flutter analyze` + relevant tests.**
- [ ] **Step 5: Commit**

---

## Task 5: Reports integration

**Files:**
- Modify: `lib/features/reports/report_repository.dart`
- Modify: `lib/features/reports/report_providers.dart`
- Modify: `lib/features/reports/report_page.dart`
- Modify: `lib/core/services/daos/reports_dao.dart`
- Test: `test/daos/reports_dao_test.dart`

**Interfaces:**
- `ReportSummary` gets back `totalExpense`.
- `totalProfit` = revenue − HPP/profit − expenses? Keep existing profit semantics: `sumProfit` from transactions, then `netProfit = totalProfit - totalExpense`.
- `ReportsDao.sumExpenses(start, end) -> Future<int>`.
- `reportSummaryProvider` reads `ReportsDao.sumExpenses`.
- `report_page.dart` restores "Pengeluaran" card and net profit.

- [ ] **Step 1: Write failing DAO test** for `sumExpenses`.
- [ ] **Step 2: Write failing `ReportSummary` test** (totalExpense exists).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `fvm flutter test test/daos/reports_dao_test.dart test/features/reports/`.**
- [ ] **Step 5: Commit**

---

## Task 6: Verification

- [ ] `fvm flutter analyze` — no errors.
- [ ] `fvm flutter test` — all green.
- [ ] Manual: Owner can add expense, see total, see report expense card; Kasir cannot see Expenses.
- [ ] Confirm no Firebase imports.
- [ ] Update `docs/SPEC.md`:
  - remove "Fitur pengeluaran / catatan belanja" from Non-Goals
  - add Expenses to goals/features and role table (Owner only)
- [ ] Commit docs.

## Rollback safety

If restore goes wrong:
- Do **not** downgrade schema. Migrations are forward-only.
- Restore from a backup ZIP made before v3.
