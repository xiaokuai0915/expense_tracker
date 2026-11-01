import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _budgetController = TextEditingController(text: '1500');
  final TextEditingController _currencyController = TextEditingController(text: 'RM');
  final TextEditingController _newTagController = TextEditingController();

  late List<ExpenseCategory> _initialCategories;

  @override
  void initState() {
    super.initState();
    _initialCategories = List.from(_storage.categories);
  }

  void _addCustomTag() {
    final tagText = _newTagController.text.trim();
    if (tagText.isEmpty) return;

    setState(() {
      _initialCategories.add(
        ExpenseCategory(
          id: DateTime.now().millisecondsSinceEpoch,
          name: tagText,
          iconName: 'category',
          colorHex: '#9C27B0',
        ),
      );
      _newTagController.clear();
    });
  }

  Future<void> _finishSetup() async {
    final budget = double.tryParse(_budgetController.text.trim()) ?? 1000.0;
    final currencyText = _currencyController.text.trim().isEmpty ? 'RM' : _currencyController.text.trim();

    _storage.monthlyBudget = budget;
    _storage.currency = currencyText;
    _storage.isFirstLaunch = false;
    _storage.categories = _initialCategories;
    await _storage.save();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Currency & Monthly Budget',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      hintText: 'e.g., RM, USD',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monthly Budget',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const Text(
              '2. Preset Frequently Used Tags',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add tags for your regular expenses for quick 1-tap logging.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _initialCategories.map((cat) {
                return Chip(
                  label: Text(cat.name),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      _initialCategories.remove(cat);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTagController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Games, Gym',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addCustomTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: _finishSetup,
                child: const Text('Save & Get Started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}