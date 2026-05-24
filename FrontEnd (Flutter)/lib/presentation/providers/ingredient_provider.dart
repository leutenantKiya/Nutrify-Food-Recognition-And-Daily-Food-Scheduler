import 'package:flutter/material.dart';
import '../../data/models/ingredient.dart';
import '../../data/repositories/ingredient_repository.dart';

class IngredientProvider extends ChangeNotifier {
  List<Ingredient> _ingredients = [];
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'avoided', 'custom'

  List<Ingredient> get ingredients {
    List<Ingredient> list = List.from(_ingredients);

    // 1. Filter based on type/avoided tag
    if (_selectedFilter == 'avoided') {
      list = list.where((i) => i.isAvoided).toList();
    } else if (_selectedFilter == 'custom') {
      list = list.where((i) => i.isCustom).toList();
    }

    // 2. Filter based on search query
    if (_searchQuery.isNotEmpty) {
      list = list.where((i) => i.nama.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // 3. Sort alphabetically by name
    list.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));

    return list;
  }

  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;
  List<Ingredient> get avoidedIngredients => _ingredients.where((i) => i.isAvoided).toList();

  Future<void> loadIngredients() async {
    await IngredientRepository.seedIfEmpty();
    _ingredients = IngredientRepository.getAll();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> toggleAvoidIngredient(String id) async {
    final index = _ingredients.indexWhere((i) => i.id == id);
    if (index != -1) {
      final updated = _ingredients[index].copyWith(isAvoided: !_ingredients[index].isAvoided);
      await IngredientRepository.save(updated);
      _ingredients = IngredientRepository.getAll();
      notifyListeners();
    }
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    await IngredientRepository.save(ingredient);
    _ingredients = IngredientRepository.getAll();
    notifyListeners();
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    await IngredientRepository.save(ingredient);
    _ingredients = IngredientRepository.getAll();
    notifyListeners();
  }

  Future<void> deleteIngredient(String id) async {
    await IngredientRepository.delete(id);
    _ingredients = IngredientRepository.getAll();
    notifyListeners();
  }
}
