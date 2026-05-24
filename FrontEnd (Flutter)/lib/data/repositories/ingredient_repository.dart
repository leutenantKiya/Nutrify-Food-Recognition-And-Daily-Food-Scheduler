import '../../core/services/hive_service.dart';
import '../models/ingredient.dart';
import '../local/ingredient_seed.dart';

class IngredientRepository {
  static List<Ingredient> getAll() {
    final box = HiveService.ingredientBox;
    return box.values
        .map((e) => Ingredient.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  static Ingredient? getById(String id) {
    final data = HiveService.ingredientBox.get(id);
    if (data == null) return null;
    return Ingredient.fromMap(Map<dynamic, dynamic>.from(data));
  }

  static Ingredient? getByName(String nama) {
    final all = getAll();
    try {
      return all.firstWhere(
        (i) => i.nama.toLowerCase() == nama.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Ingredient ingredient) async {
    await HiveService.ingredientBox.put(ingredient.id, ingredient.toMap());
  }

  static Future<void> delete(String id) async {
    await HiveService.ingredientBox.delete(id);
  }

  static Future<void> seedIfEmpty() async {
    if (HiveService.ingredientBox.isEmpty) {
      final seedData = IngredientSeed.data;
      for (final ingredient in seedData) {
        await HiveService.ingredientBox.put(ingredient.id, ingredient.toMap());
      }
    }
  }

  static List<Ingredient> search(String query) {
    final all = getAll();
    if (query.isEmpty) return all;
    return all
        .where((i) => i.nama.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
