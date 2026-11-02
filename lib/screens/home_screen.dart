import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import 'logs_screen.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();

  int _currentIndex = 0;
  bool _isLoading = false;

  double _monthTotal = 0;
  double _weekTotal = 0;
  String _dailyAvgStr = 'N/A';
  String _weeklyAvgStr = 'N/A';
  String _monthlyAvgStr = 'N/A';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _calculateStats(_storage.expenses, _storage.currency);

    setState(() {
      _isLoading = false;
    });
  }

  void _calculateStats(List<Expense> expenses, String currency) {
    if (expenses.isEmpty) {
      _monthTotal = 0;
      _weekTotal = 0;
      _dailyAvgStr = 'N/A';
      _weeklyAvgStr = 'N/A';
      _monthlyAvgStr = 'N/A';
      return;
    }

    final now = DateTime.now();
    double mSum = 0;
    double wSum = 0;

    DateTime minDate = expenses.first.date;
    DateTime maxDate = expenses.first.date;

    for (var e in expenses) {
      if (e.date.isBefore(minDate)) minDate = e.date;
      if (e.date.isAfter(maxDate)) maxDate = e.date;

      if (e.date.year == now.year && e.date.month == now.month) {
        mSum += e.amount;
      }

      final diffDays = now.difference(e.date).inDays;
      if (diffDays >= 0 && diffDays <= 7) {
        wSum += e.amount;
      }
    }

    final startDate = DateTime(minDate.year, minDate.month, minDate.day);
    final endDate = DateTime(maxDate.year, maxDate.month, maxDate.day);
    final totalDays = endDate.difference(startDate).inDays + 1;

    final totalSum = expenses.fold(0.0, (sum, item) => sum + item.amount);
    final dailyAvg = totalSum / (totalDays < 1 ? 1 : totalDays);

    _monthTotal = mSum;
    _weekTotal = wSum;
    _dailyAvgStr = '$currency ${dailyAvg.toStringAsFixed(2)}';
    _weeklyAvgStr = totalDays >= 7 ? '$currency ${(dailyAvg * 7).toStringAsFixed(2)}' : 'N/A';
    _monthlyAvgStr = totalDays >= 30 ? '$currency ${(dailyAvg * 30).toStringAsFixed(2)}' : 'N/A';
  }

  void _showResetConfirmationDialog() {
    final confirmController = TextEditingController();
    bool isButtonEnabled = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reset All Data', style: TextStyle(color: Colors.redAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warning: This action will permanently delete all your expenses, custom tags, and local settings.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('To confirm, type "DELETE" in the box below:'),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Type DELETE here',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    isButtonEnabled = val.trim() == 'DELETE';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: isButtonEnabled
                  ? () async {
                      await _storage.clearAllData();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                        );
                      }
                    }
                  : null,
              child: const Text('Confirm Reset'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrentDateTime() {
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final year = now.year;
    final monthStr = months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    final weekday = weekdays[now.weekday - 1];
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$weekday, $day $monthStr $year  $hh:$mm';
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  void _showCurrencySettingDialog() {
    final currencyController = TextEditingController(text: _storage.currency);
    final rateController = TextEditingController(text: '1.0');
    bool shouldConvert = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Currency Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: currencyController,
                decoration: const InputDecoration(
                  labelText: 'New Currency Unit (e.g. USD, EUR, RM)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Convert existing amounts', style: TextStyle(fontSize: 14)),
                value: shouldConvert,
                onChanged: (val) {
                  setDialogState(() {
                    shouldConvert = val ?? false;
                  });
                },
              ),
              if (shouldConvert) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Exchange Rate (1 ${_storage.currency} = ? ${currencyController.text.trim()})',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newCurr = currencyController.text.trim();
                final rate = double.tryParse(rateController.text.trim()) ?? 1.0;
                if (newCurr.isNotEmpty) {
                  await _storage.updateCurrencyAndConvert(
                    newCurrency: newCurr,
                    shouldConvert: shouldConvert,
                    exchangeRate: rate,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _refreshData();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustBudgetDialog() {
    final controller = TextEditingController(text: _storage.monthlyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Budget Management'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monthly Budget (${_storage.currency})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBudget = double.tryParse(controller.text.trim());
              if (newBudget != null && newBudget >= 0) {
                _storage.monthlyBudget = newBudget;
                await _storage.save();
                if (ctx.mounted) Navigator.pop(ctx);
                _refreshData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCategoryManagerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Category Manager'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final newCatName = await _showNewCategoryDialog(context);
                    if (newCatName != null && newCatName.isNotEmpty) {
                      await _storage.addCategory(newCatName);
                      setDialogState(() {});
                      _refreshData();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Tag'),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _storage.categories.length,
                    itemBuilder: (ctx, index) {
                      final cat = _storage.categories[index];
                      return ListTile(
                        dense: true,
                        title: Text(cat.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          onPressed: () async {
                            if (cat.id != null) {
                              await _storage.deleteCategory(cat.id!);
                              setDialogState(() {});
                              _refreshData();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final jsonStr = await _storage.exportJsonString();
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Backup File',
      fileName: 'expense_tracker_backup.json',
      bytes: bytes,
    );

    if (result != null && mounted) {
      final file = File(result);
      if (!await file.exists() || (await file.length()) == 0) {
        await file.writeAsString(jsonStr);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data exported successfully!')),
      );
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final success = await _storage.importJsonString(content);

      if (mounted) {
        if (success) {
          _refreshData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup imported successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid backup file format.')),
          );
        }
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Expense Tracker',
      applicationVersion: 'v1.1.0 (Open Source)',
      applicationIcon: const Icon(Icons.account_balance_wallet, size: 40, color: Colors.deepPurpleAccent),
      children: const [
        SizedBox(height: 12),
        Text('A fast, minimal, tag-based offline expense manager built with Flutter.'),
        SizedBox(height: 8),
        Text('GitHub Repository:', style: TextStyle(fontWeight: FontWeight.bold)),
        SelectableText('https://github.com/xiaokuai0915/expense_tracker'),
      ],
    );
  }

  Future<String?> _showNewCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tag name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    int? selectedCatId = _storage.categories.isNotEmpty ? _storage.categories.first.id : null;
    DateTime selectedDateTime = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Expense',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (${_storage.currency})',
                  prefixText: '${_storage.currency} ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDateTime,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );
                    if (pickedTime != null) {
                      setModalState(() {
                        selectedDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade700),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date & Time: ${_formatDateTime(selectedDateTime)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Category:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._storage.categories.map((cat) {
                    final isSelected = cat.id == selectedCatId;
                    return ChoiceChip(
                      label: Text(cat.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setModalState(() => selectedCatId = cat.id);
                      },
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('New Tag'),
                    backgroundColor: Colors.deepPurple.shade900,
                    onPressed: () async {
                      final newCatName = await _showNewCategoryDialog(context);
                      if (newCatName != null && newCatName.isNotEmpty) {
                        final newId = await _storage.addCategory(newCatName);
                        setModalState(() {
                          selectedCatId = newId;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amount <= 0 || selectedCatId == null) return;

                    final newExp = Expense(
                      amount: amount,
                      categoryId: selectedCatId!,
                      date: selectedDateTime,
                      note: noteController.text.trim(),
                    );
                    await _storage.addExpense(newExp);

                    if (ctx.mounted) Navigator.pop(ctx);
                    _refreshData();
                  },
                  child: const Text('Save Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    final remainingBudget = _storage.monthlyBudget - _monthTotal;
    final isOverBudget = remainingBudget < 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _formatCurrentDateTime(),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text('Monthly Spending', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '${_storage.currency} ${_monthTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (_storage.monthlyBudget > 0) ? (_monthTotal / _storage.monthlyBudget).clamp(0.0, 1.0) : 0,
                    backgroundColor: Colors.grey.shade800,
                    color: isOverBudget ? Colors.redAccent : Colors.deepPurpleAccent,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Budget: ${_storage.currency} ${_storage.monthlyBudget.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        isOverBudget
                            ? 'Over: ${_storage.currency} ${(-remainingBudget).toStringAsFixed(2)}'
                            : 'Remaining: ${_storage.currency} ${remainingBudget.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isOverBudget ? Colors.redAccent : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildStatTile('Weekly Total', '${_storage.currency} ${_weekTotal.toStringAsFixed(2)}'),
              _buildStatTile('Daily Avg', _dailyAvgStr),
              _buildStatTile('Weekly Avg', _weeklyAvgStr),
              _buildStatTile('Monthly Avg', _monthlyAvgStr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = themeNotifier.value == ThemeMode.dark;

    final pages = [
      _buildDashboardView(),
      LogsScreen(onDataChanged: _refreshData),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Financial Dashboard' : 'Expense Logs'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.account_balance_wallet, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text('Expense Tracker', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Currency Settings'),
              onTap: () {
                Navigator.pop(context);
                _showCurrencySettingDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: const Text('Budget Management'),
              onTap: () {
                Navigator.pop(context);
                _showAdjustBudgetDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outlined),
              title: const Text('Category Manager'),
              onTap: () {
                Navigator.pop(context);
                _showCategoryManagerDialog();
              },
            ),
            SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Dark Mode'),
              value: isDark,
              onChanged: (val) async {
                themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                _storage.isDarkMode = val;
                await _storage.save();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Export Backup (.json)'),
              onTap: () {
                Navigator.pop(context);
                _exportData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Import Backup (.json)'),
              onTap: () {
                Navigator.pop(context);
                _importData();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About & GitHub'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Reset All Data', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _showResetConfirmationDialog();
              },
            ),
          ],
        ),
      ),
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showExpenseDialog,
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}