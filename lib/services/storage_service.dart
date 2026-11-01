import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  File? _localFile;

  String currency = 'RM';
  double monthlyBudget = 1000.0;
  bool isDarkMode = true;
  bool isFirstLaunch = true;
  List<ExpenseCategory> categories = [];
  List<Expense> expenses = [];

  Future<File> _getFile() async {
    if (_localFile != null) return _localFile!;
    final directory = await getApplicationDocumentsDirectory();
    _localFile = File('${directory.path}/expense_tracker_data.json');
    return _localFile!;
  }

  Future<void> init() async {
    final file = await _getFile();
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);

        currency = json['currency'] ?? 'RM';
        monthlyBudget = (json['monthlyBudget'] as num?)?.toDouble() ?? 1000.0;
        isDarkMode = json['isDarkMode'] ?? true;
        isFirstLaunch = json['isFirstLaunch'] ?? false;

        if (json['categories'] != null) {
          categories = (json['categories'] as List)
              .map((c) => ExpenseCategory.fromMap(Map<String, dynamic>.from(c)))
              .toList();
        }

        if (json['expenses'] != null) {
          expenses = (json['expenses'] as List)
              .map((e) => Expense.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (e) {
        _initDefaults();
      }
    } else {
      _initDefaults();
    }
  }

  void _initDefaults() {
    isFirstLaunch = true;
    categories = [
      ExpenseCategory(id: 1, name: 'Food', iconName: 'restaurant', colorHex: '#FF9800'),
      ExpenseCategory(id: 2, name: 'Transport', iconName: 'directions_car', colorHex: '#2196F3'),
      ExpenseCategory(id: 3, name: 'Drinks', iconName: 'local_cafe', colorHex: '#795548'),
      ExpenseCategory(id: 4, name: 'Parking', iconName: 'local_parking', colorHex: '#607D8B'),
      ExpenseCategory(id: 5, name: 'Shopping', iconName: 'shopping_bag', colorHex: '#E91E63'),
    ];
    expenses = [];
  }

  Future<void> save() async {
    final file = await _getFile();
    final data = {
      'currency': currency,
      'monthlyBudget': monthlyBudget,
      'isDarkMode': isDarkMode,
      'isFirstLaunch': isFirstLaunch,
      'categories': categories.map((c) => c.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> updateCurrencyAndConvert({
    required String newCurrency,
    required bool shouldConvert,
    required double exchangeRate,
  }) async {
    currency = newCurrency;
    if (shouldConvert && exchangeRate > 0) {
      monthlyBudget = double.parse((monthlyBudget * exchangeRate).toStringAsFixed(2));
      for (int i = 0; i < expenses.length; i++) {
        expenses[i] = Expense(
          id: expenses[i].id,
          amount: double.parse((expenses[i].amount * exchangeRate).toStringAsFixed(2)),
          categoryId: expenses[i].categoryId,
          date: expenses[i].date,
          note: expenses[i].note,
        );
      }
    }
    await save();
  }

  Future<int> addCategory(String name) async {
    final newId = categories.isEmpty
        ? 1
        : (categories.map((c) => c.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    final newCat = ExpenseCategory(id: newId, name: name, iconName: 'category', colorHex: '#9C27B0');
    categories.add(newCat);
    await save();
    return newId;
  }

  Future<void> deleteCategory(int id) async {
    categories.removeWhere((c) => c.id == id);
    await save();
  }

  Future<void> addExpense(Expense expense) async {
    final newId = expenses.isEmpty
        ? 1
        : (expenses.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    final newExp = Expense(
      id: newId,
      amount: expense.amount,
      categoryId: expense.categoryId,
      date: expense.date,
      note: expense.note,
    );
    expenses.insert(0, newExp);
    await save();
  }

  Future<void> updateExpense(Expense expense) async {
    final index = expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      expenses[index] = expense;
      await save();
    }
  }

  Future<void> deleteExpense(int id) async {
    expenses.removeWhere((e) => e.id == id);
    await save();
  }

  Future<String> exportJsonString() async {
    final file = await _getFile();
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<bool> importJsonString(String jsonStr) async {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      currency = json['currency'] ?? 'RM';
      monthlyBudget = (json['monthlyBudget'] as num?)?.toDouble() ?? 1000.0;
      isDarkMode = json['isDarkMode'] ?? true;
      isFirstLaunch = false;

      if (json['categories'] != null) {
        categories = (json['categories'] as List)
            .map((c) => ExpenseCategory.fromMap(Map<String, dynamic>.from(c)))
            .toList();
      }
      if (json['expenses'] != null) {
        expenses = (json['expenses'] as List)
            .map((e) => Expense.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      await save();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearAllData() async {
    _initDefaults();
    isFirstLaunch = true;
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}