import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/expiry_notification_service.dart';
import '../services/fridge_item_service.dart';
import '../services/open_food_facts_service.dart';
import 'add_item_screen.dart';
import 'barcode_scanner_screen.dart';
import 'ocr_scanner_screen.dart';
import 'recipe_suggestions_screen.dart';
import 'shared_fridge_members_screen.dart';

class FridgeOverviewScreen extends StatefulWidget {
  const FridgeOverviewScreen({super.key, required this.userId});

  final String userId;

  @override
  State<FridgeOverviewScreen> createState() => _FridgeOverviewScreenState();
}

class _FridgeOverviewScreenState extends State<FridgeOverviewScreen> {
  static final _authService = AuthService();
  static final _itemService = FridgeItemService();
  static final _notificationService = ExpiryNotificationService.instance;
  static final _productService = OpenFoodFactsService();

  _ExpiryFilter _expiryFilter = _ExpiryFilter.all;
  String? _categoryFilter;

  String get userId => widget.userId;
  String get _itemsPath => 'users/$userId/fridges/default/items';

  void _goToAddItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(userId: userId)),
    );
  }

  void _goToRecipeSuggestions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeSuggestionsScreen(userId: userId),
      ),
    );
  }

  void _goToSharedFridge(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SharedFridgeMembersScreen()),
    );
  }

  void _syncExpiryNotifications(List<_FridgeItem> items) {
    final notificationItems = items
        .where((item) => item.expiryDate != null)
        .map(
          (item) => ExpiryNotificationItem(
            id: item.id,
            name: item.name,
            expiryDate: item.expiryDate!,
          ),
        )
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _notificationService.syncExpiryReminders(notificationItems);
    });
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Scan stregkode'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _goToBarcodeScanner(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Manuel'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _goToAddItem(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.document_scanner),
                  title: const Text('Tekstscan'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _goToOcrScanner(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _goToBarcodeScanner(BuildContext context) async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (!context.mounted || barcode == null) {
      return;
    }

    await _addScannedBarcode(context, barcode);
  }

  Future<void> _goToOcrScanner(BuildContext context) async {
    final didSave = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OcrScannerScreen(userId: userId)),
    );

    if (!context.mounted || didSave != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Varen blev tilføjet fra tekstscan')),
    );
  }

  Future<void> _signOut() {
    return _authService.signOut();
  }

  Future<void> _addScannedBarcode(BuildContext context, String barcode) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Henter produkt for stregkode $barcode...')),
    );

    final product = await _findProduct(barcode);
    messenger.hideCurrentSnackBar();

    if (!context.mounted) {
      return;
    }

    try {
      await _itemService.addItem(
        userId: userId,
        name: product.name,
        category: product.category,
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        source: 'barcode',
        imageUrl: product.imageUrl,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnackBar(context, 'Produktet kunne ikke tilføjes: $error');
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('${product.name} blev tilføjet')),
    );
  }

  Future<OpenFoodFactsProduct> _findProduct(String barcode) async {
    try {
      return await _productService
          .findByBarcode(barcode)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return OpenFoodFactsProduct(
        barcode: barcode,
        name: 'Stregkode $barcode',
        category: 'Ukendt',
      );
    }
  }

  Future<void> _deleteItemWithUndo(
    BuildContext context,
    _FridgeItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _itemService.deleteItem(userId: userId, itemId: item.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Varen kunne ikke slettes: $error')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('${item.name} blev slettet'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Fortryd',
          onPressed: () {
            _itemService.restoreItem(
              userId: userId,
              itemId: item.id,
              data: item.data,
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateItem(
    BuildContext context,
    String itemId, {
    String? name,
    String? category,
    DateTime? expiryDate,
  }) async {
    try {
      await _itemService.updateItem(
        userId: userId,
        itemId: itemId,
        name: name,
        category: category,
        expiryDate: expiryDate,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnackBar(context, 'Varen kunne ikke opdateres: $error');
    }
  }

  Future<void> _editText({
    required BuildContext context,
    required String label,
    required String value,
    required Future<void> Function(String value) save,
  }) async {
    final newValue = await _showInputDialog(
      context,
      title: 'Rediger $label',
      label: label,
      value: value,
    );

    if (newValue == null || newValue.isEmpty || newValue == value) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await save(newValue);
  }

  Future<String?> _showInputDialog(
    BuildContext context, {
    required String title,
    required String label,
    required String value,
    String? hintText,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Gem'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _pickDate({
    required BuildContext context,
    required String itemId,
    required DateTime? value,
  }) async {
    final today = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: value ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );

    if (pickedDate == null || !context.mounted) {
      return;
    }

    await _updateItem(context, itemId, expiryDate: pickedDate);
  }

  Color _expiryColor(DateTime? date) {
    if (date == null) {
      return Colors.grey;
    }

    final daysLeft = _daysLeft(date);

    if (daysLeft <= 3) return Colors.red;
    if (daysLeft <= 7) return Colors.orange;
    return Colors.green;
  }

  int _daysLeft(DateTime date) {
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    return itemDate.difference(currentDate).inDays;
  }

  String _expiryStatus(DateTime? date) {
    if (date == null) return 'Ingen dato';

    final daysLeft = _daysLeft(date);
    if (daysLeft < 0) return 'Udløbet';
    if (daysLeft == 0) return 'Udløber i dag';
    if (daysLeft == 1) return 'Udløber i morgen';
    return '$daysLeft dage tilbage';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  String _dateText(DateTime? date) {
    return date == null ? 'Ingen dato' : _formatDate(date);
  }

  String _errorMessage(Object error) {
    if (error is! FirebaseException) {
      return 'Varerne kunne ikke hentes fra databasen: $error';
    }

    switch (error.code) {
      case 'not-found':
        return 'Firestore databasen findes ikke.\n\n'
            'Tjek at appen bruger den rigtige Firestore database.';
      case 'permission-denied':
        return 'Ingen adgang til Firestore.\n\n'
            'Tjek security rules og data-stien:\n$_itemsPath';
      case 'unavailable':
        return 'Firestore kan ikke nås lige nu.\n\n'
            'Tjek internetforbindelsen og Firebase opsætningen.';
      default:
        return 'Firebase fejl (${error.code}): ${error.message ?? error}';
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _itemsView(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _itemService.watchItems(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageView(_errorMessage(snapshot.error!));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allItems =
            snapshot.data?.docs.map(_FridgeItem.fromDoc).toList() ?? [];
        _syncExpiryNotifications(allItems);

        if (allItems.isEmpty) {
          return Column(
            children: [
              _sharedFridgeCard(context),
              Expanded(child: _emptyView(context)),
            ],
          );
        }

        final categories = _availableCategories(allItems);
        final activeCategory = categories.contains(_categoryFilter)
            ? _categoryFilter
            : null;
        final items = _filteredAndSortedItems(
          allItems,
          category: activeCategory,
        );

        return Column(
          children: [
            _sharedFridgeCard(context),
            _filterBar(
              context,
              categories: categories,
              activeCategory: activeCategory,
            ),
            Expanded(
              child: items.isEmpty
                  ? _filteredEmptyView(context)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _productDropdown(context, items[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _sharedFridgeCard(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SharedFridgeMockState.sharedEmail,
      builder: (context, sharedEmail, _) {
        if (sharedEmail == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('F\u00e6lles k\u00f8leskab'),
              subtitle: Text('Delt med $sharedEmail'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _goToSharedFridge(context),
            ),
          ),
        );
      },
    );
  }

  List<String> _availableCategories(List<_FridgeItem> items) {
    final categories = <String>{};
    for (final item in items) {
      final category = item.category.trim();
      if (category.isNotEmpty) {
        categories.add(category);
      }
    }

    return categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<_FridgeItem> _filteredAndSortedItems(
    List<_FridgeItem> items, {
    required String? category,
  }) {
    final filtered = items.where((item) {
      final matchesStatus = _matchesExpiryFilter(item);
      final matchesCategory =
          category == null || item.category.trim() == category;
      return matchesStatus && matchesCategory;
    }).toList();

    filtered.sort(_compareByExpiryDate);
    return filtered;
  }

  bool _matchesExpiryFilter(_FridgeItem item) {
    switch (_expiryFilter) {
      case _ExpiryFilter.all:
        return true;
      case _ExpiryFilter.red:
        return item.expiryDate != null && _daysLeft(item.expiryDate!) <= 3;
      case _ExpiryFilter.orange:
        if (item.expiryDate == null) return false;
        final daysLeft = _daysLeft(item.expiryDate!);
        return daysLeft > 3 && daysLeft <= 7;
      case _ExpiryFilter.green:
        return item.expiryDate != null && _daysLeft(item.expiryDate!) > 7;
    }
  }

  int _compareByExpiryDate(_FridgeItem a, _FridgeItem b) {
    final aDate = a.expiryDate;
    final bDate = b.expiryDate;

    if (aDate == null && bDate == null) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    final dateOrder = aDate.compareTo(bDate);
    if (dateOrder != 0) return dateOrder;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Widget _filterBar(
    BuildContext context, {
    required List<String> categories,
    required String? activeCategory,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasActiveFilters =
        _expiryFilter != _ExpiryFilter.all || activeCategory != null;

    return Material(
      color: colorScheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _activeFilterText(activeCategory),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasActiveFilters
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                  fontWeight: hasActiveFilters
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _showFilterSheet(
                context,
                categories: categories,
                activeCategory: activeCategory,
              ),
              tooltip: 'Filtrer varer',
              icon: Icon(
                hasActiveFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activeFilterText(String? activeCategory) {
    final parts = <String>[];
    if (_expiryFilter != _ExpiryFilter.all) {
      parts.add(_expiryFilterLabel(_expiryFilter));
    }
    if (activeCategory != null) {
      parts.add(activeCategory);
    }

    return parts.isEmpty ? 'Alle varer' : 'Filter: ${parts.join(' · ')}';
  }

  Future<void> _showFilterSheet(
    BuildContext context, {
    required List<String> categories,
    required String? activeCategory,
  }) {
    var selectedStatus = _expiryFilter;
    var selectedCategory = activeCategory;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            void updateStatus(_ExpiryFilter value) {
              sheetSetState(() => selectedStatus = value);
              setState(() => _expiryFilter = value);
            }

            void updateCategory(String? value) {
              sheetSetState(() => selectedCategory = value);
              setState(() => _categoryFilter = value);
            }

            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filtrer varer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          sheetSetState(() {
                            selectedStatus = _ExpiryFilter.all;
                            selectedCategory = null;
                          });
                          setState(() {
                            _expiryFilter = _ExpiryFilter.all;
                            _categoryFilter = null;
                          });
                        },
                        child: const Text('Nulstil'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Status', style: Theme.of(context).textTheme.labelLarge),
                  _statusFilterTile(
                    value: _ExpiryFilter.all,
                    groupValue: selectedStatus,
                    label: 'Alle',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.grey,
                    onChanged: updateStatus,
                  ),
                  _statusFilterTile(
                    value: _ExpiryFilter.red,
                    groupValue: selectedStatus,
                    label: 'R\u00f8d',
                    icon: Icons.circle,
                    color: Colors.red,
                    onChanged: updateStatus,
                  ),
                  _statusFilterTile(
                    value: _ExpiryFilter.orange,
                    groupValue: selectedStatus,
                    label: 'Orange',
                    icon: Icons.circle,
                    color: Colors.orange,
                    onChanged: updateStatus,
                  ),
                  _statusFilterTile(
                    value: _ExpiryFilter.green,
                    groupValue: selectedStatus,
                    label: 'Gr\u00f8n',
                    icon: Icons.circle,
                    color: Colors.green,
                    onChanged: updateStatus,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kategori',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  _categoryFilterTile(
                    value: null,
                    selectedValue: selectedCategory,
                    title: const Text('Alle kategorier'),
                    icon: Icons.category_outlined,
                    onTap: updateCategory,
                  ),
                  ...categories.map(
                    (category) => _categoryFilterTile(
                      value: category,
                      selectedValue: selectedCategory,
                      title: Text(category, overflow: TextOverflow.ellipsis),
                      icon: Icons.label_outline,
                      onTap: updateCategory,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _categoryFilterTile({
    required String? value,
    required String? selectedValue,
    required Widget title,
    required IconData icon,
    required ValueChanged<String?> onTap,
  }) {
    final selected = value == selectedValue;

    return ListTile(
      onTap: () => onTap(value),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: title,
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
    );
  }

  Widget _statusFilterTile({
    required _ExpiryFilter value,
    required _ExpiryFilter groupValue,
    required String label,
    required IconData icon,
    required Color color,
    required ValueChanged<_ExpiryFilter> onChanged,
  }) {
    final selected = value == groupValue;

    return ListTile(
      onTap: () => onChanged(value),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
    );
  }

  String _expiryFilterLabel(_ExpiryFilter filter) {
    switch (filter) {
      case _ExpiryFilter.all:
        return 'Alle';
      case _ExpiryFilter.red:
        return 'R\u00f8d';
      case _ExpiryFilter.orange:
        return 'Orange';
      case _ExpiryFilter.green:
        return 'Gr\u00f8n';
    }
  }

  Widget _emptyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.kitchen_outlined, size: 56, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Dit køleskab er tomt',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Tilføj din første vare for at se udløbsdatoer her.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('Tilføj vare'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              SelectableText(
                'Appen læser fra:\n$_itemsPath',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messageView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _filteredEmptyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Ingen varer matcher filtrene',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _expiryFilter = _ExpiryFilter.all;
                  _categoryFilter = null;
                });
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Nulstil filtre'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productDropdown(BuildContext context, _FridgeItem item) {
    final expiryColor = _expiryColor(item.expiryDate);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItemWithUndo(context, item),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: ExpansionTile(
          leading: Container(
            width: 12,
            height: 44,
            decoration: BoxDecoration(
              color: expiryColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _miniInfoChip(
                  context,
                  Icons.event_outlined,
                  _dateText(item.expiryDate),
                ),
                _miniInfoChip(context, Icons.category_outlined, item.category),
              ],
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _statusChip(
                text: _expiryStatus(item.expiryDate),
                color: expiryColor,
              ),
            ),
            const SizedBox(height: 12),
            _detailRow(
              label: 'Navn',
              value: item.name,
              onEdit: () => _editText(
                context: context,
                label: 'navn',
                value: item.name,
                save: (value) => _updateItem(context, item.id, name: value),
              ),
            ),
            _detailRow(
              label: 'Kategori',
              value: item.category,
              onEdit: () => _editText(
                context: context,
                label: 'kategori',
                value: item.category,
                save: (value) => _updateItem(context, item.id, category: value),
              ),
            ),
            _detailRow(
              label: 'Udløbsdato',
              value: _dateText(item.expiryDate),
              onEdit: () => _pickDate(
                context: context,
                itemId: item.id,
                value: item.expiryDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfoChip(BuildContext context, IconData icon, String text) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Rediger $label',
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mit køleskab'),
        actions: [
          IconButton(
            onPressed: () => _goToSharedFridge(context),
            tooltip: 'Delt k\u00f8leskab',
            icon: const Icon(Icons.groups_outlined),
          ),
          IconButton(
            onPressed: () => _goToRecipeSuggestions(context),
            tooltip: 'Opskrifter',
            icon: const Icon(Icons.restaurant_menu),
          ),
          IconButton(
            onPressed: _signOut,
            tooltip: 'Log ud',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _itemsView(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        tooltip: 'Tilføj vare',
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum _ExpiryFilter { all, red, orange, green }

class _FridgeItem {
  const _FridgeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
    required this.data,
  });

  final String id;
  final String name;
  final String category;
  final DateTime? expiryDate;
  final Map<String, dynamic> data;

  factory _FridgeItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _FridgeItem(
      id: doc.id,
      name: data['name'] as String? ?? 'Ukendt vare',
      category: data['category'] as String? ?? 'Ingen kategori',
      expiryDate: _readDate(data['expiryDate']),
      data: data,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
