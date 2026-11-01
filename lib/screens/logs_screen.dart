import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';

enum LogGroupBy { none, month, week }

class LogsScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const LogsScreen({super.key, required this.onDataChanged});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final StorageService _storage = StorageService();
  LogGroupBy _groupBy = LogGroupBy.none;

  String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _getCategoryName(int id) {
    if (_storage.categories.isEmpty) return 'General';
    final match = _storage.categories.where((c) => c.id == id);
    if (match.isNotEmpty) {
      return match.first.name;
    }
    return _storage.categories.first.name;
  }

  String _getWeekRangeString(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final startMonth = months[monday.month - 1];
    final endMonth = months[sunday.month - 1];
    final startDay = monday.day.toString().padLeft(2, '0');
    final endDay = sunday.day.toString().padLeft(2, '0');

    if (monday.month == sunday.month) {
      return '$startMonth $startDay - $endDay, ${monday.year}';
    } else {
      return '$startMonth $startDay - $endMonth $endDay, ${monday.year}';
    }
  }

  Map<String, List<Expense>> _getGroupedExpenses() {
    final Map<String, List<Expense>> groups = {};
    for (var exp in _storage.expenses) {
      String key;
      if (_groupBy == LogGroupBy.month) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        key = '${months[exp.date.month - 1]} ${exp.date.year}';
      } else if (_groupBy == LogGroupBy.week) {
        final firstDayOfYear = DateTime(exp.date.year, 1, 1);
        final weekNum = ((exp.date.difference(firstDayOfYear).inDays) / 7).floor() + 1;
        final rangeStr = _getWeekRangeString(exp.date);
        key = '${exp.date.year} Week $weekNum ($rangeStr)';
      } else {
        key = 'All Expenses';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(exp);
    }
    return groups;
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

  void _showEditDialog(Expense expense) {
    final amountController = TextEditingController(text: expense.amount.toString());
    final noteController = TextEditingController(text: expense.note ?? '');
    int? selectedCatId = expense.categoryId;
    DateTime selectedDateTime = expense.date;

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
                'Edit Expense',
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

                    final updated = Expense(
                      id: expense.id,
                      amount: amount,
                      categoryId: selectedCatId!,
                      date: selectedDateTime,
                      note: noteController.text.trim(),
                    );
                    await _storage.updateExpense(updated);

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {});
                      widget.onDataChanged();
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this record (${_storage.currency} ${expense.amount})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () async {
              if (expense.id != null) {
                await _storage.deleteExpense(expense.id!);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                widget.onDataChanged();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense exp) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).cardColor,
      child: ListTile(
        title: Text(
          '${_getCategoryName(exp.categoryId)} ${exp.note != null && exp.note!.isNotEmpty ? "• ${exp.note}" : ""}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatDateTime(exp.date),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-${_storage.currency} ${exp.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
              onPressed: () => _showEditDialog(exp),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
              onPressed: () => _confirmDelete(exp),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedMap = _getGroupedExpenses();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Group By:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SegmentedButton<LogGroupBy>(
                    segments: const [
                      ButtonSegment(value: LogGroupBy.none, label: Text('All')),
                      ButtonSegment(value: LogGroupBy.month, label: Text('Month')),
                      ButtonSegment(value: LogGroupBy.week, label: Text('Week')),
                    ],
                    selected: {_groupBy},
                    onSelectionChanged: (Set<LogGroupBy> newSelection) {
                      setState(() {
                        _groupBy = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _storage.expenses.isEmpty
                      ? const Center(child: Text('No expense records found', style: TextStyle(color: Colors.grey)))
                      : _groupBy == LogGroupBy.none
                          ? ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _storage.expenses.length,
                              itemBuilder: (ctx, index) => _buildExpenseTile(_storage.expenses[index]),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: groupedMap.keys.length,
                              itemBuilder: (ctx, index) {
                                final key = groupedMap.keys.elementAt(index);
                                final list = groupedMap[key]!;
                                final totalGroupAmount = list.fold(0.0, (sum, item) => sum + item.amount);
                                return ExpansionTile(
                                  initiallyExpanded: true,
                                  title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Total: ${_storage.currency} ${totalGroupAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  children: list.map((exp) => _buildExpenseTile(exp)).toList(),
                                );
                              },
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}