double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class MealAnalysisResult {
  final String status;
  final MealDetails? meal;
  final NutritionInfo? nutritionTotal;
  final GoalAnalysis? goalAnalysis;
  final List<String> recommendations;
  final List<dynamic> detailedSuggestions;
  final String explanation;
  final MealImages? images;

  MealAnalysisResult({
    required this.status,
    this.meal,
    this.nutritionTotal,
    this.goalAnalysis,
    required this.recommendations,
    required this.detailedSuggestions,
    required this.explanation,
    this.images,
  });

  factory MealAnalysisResult.fromJson(Map<String, dynamic> json) {
    final meal = json['meal'] != null ? MealDetails.fromJson(json['meal']) : null;
    
    NutritionInfo? total;
    if (json['nutrition_total'] != null) {
      total = NutritionInfo.fromJson(json['nutrition_total']);
    } else if (meal != null && meal.ingredients.isNotEmpty) {
      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;
      double fiber = 0;
      bool hasNutrition = false;
      for (var ing in meal.ingredients) {
        if (ing.nutrition != null) {
          hasNutrition = true;
          calories += ing.nutrition!.calories;
          protein += ing.nutrition!.protein;
          carbs += ing.nutrition!.carbs;
          fat += ing.nutrition!.fat;
          fiber += ing.nutrition!.fiber;
        }
      }
      if (hasNutrition) {
        total = NutritionInfo(
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
        );
      }
    }

    return MealAnalysisResult(
      status: json['status'] ?? '',
      meal: meal,
      nutritionTotal: total,
      goalAnalysis: json['goal_analysis'] != null
          ? GoalAnalysis.fromJson(json['goal_analysis'])
          : null,
      recommendations: List<String>.from(json['recommendations'] ?? []),
      detailedSuggestions: List<dynamic>.from(json['detailed_suggestions'] ?? []),
      explanation: json['explanation'] ?? '',
      images: json['images'] != null ? MealImages.fromJson(json['images']) : null,
    );
  }
}

class MealDetails {
  final DishPrediction? dishPrediction;
  final List<IngredientAnalysis> ingredients;
  final List<String> estimatedHiddenIngredients;
  final PortionEstimate? portionEstimate;

  MealDetails({
    this.dishPrediction,
    required this.ingredients,
    required this.estimatedHiddenIngredients,
    this.portionEstimate,
  });

  factory MealDetails.fromJson(Map<String, dynamic> json) {
    return MealDetails(
      dishPrediction: json['dish_prediction'] != null
          ? DishPrediction.fromJson(json['dish_prediction'])
          : null,
      ingredients: (json['ingredients'] as List?)
              ?.map((e) => IngredientAnalysis.fromJson(e))
              .toList() ??
          [],
      estimatedHiddenIngredients:
          List<String>.from(json['estimated_hidden_ingredients'] ?? []),
      portionEstimate: json['portion_estimate'] != null
          ? PortionEstimate.fromJson(json['portion_estimate'])
          : null,
    );
  }
}

class DishPrediction {
  final String label;
  final double confidence;
  final List<CandidatePrediction> topCandidates;

  DishPrediction({
    required this.label,
    required this.confidence,
    required this.topCandidates,
  });

  factory DishPrediction.fromJson(Map<String, dynamic> json) {
    return DishPrediction(
      label: json['label'] ?? '',
      confidence: _toDouble(json['confidence']),
      topCandidates: (json['top_candidates'] as List?)
              ?.map((e) => CandidatePrediction.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class CandidatePrediction {
  final String label;
  final double probability;

  CandidatePrediction({
    required this.label,
    required this.probability,
  });

  factory CandidatePrediction.fromJson(Map<String, dynamic> json) {
    return CandidatePrediction(
      label: json['label'] ?? '',
      probability: _toDouble(json['probability']),
    );
  }
}

class IngredientAnalysis {
  final String label;
  final double confidence;
  final double grams;
  final String source;
  final NutritionInfo? nutrition;

  IngredientAnalysis({
    required this.label,
    required this.confidence,
    required this.grams,
    required this.source,
    this.nutrition,
  });

  factory IngredientAnalysis.fromJson(Map<String, dynamic> json) {
    return IngredientAnalysis(
      label: json['label'] ?? '',
      confidence: _toDouble(json['confidence']),
      grams: _toDouble(json['grams']),
      source: json['source'] ?? '',
      nutrition: json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'])
          : null,
    );
  }
}

class NutritionInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: _toDouble(json['calories']),
      protein: _toDouble(json['protein']),
      carbs: _toDouble(json['carbs']),
      fat: _toDouble(json['fat']),
      fiber: _toDouble(json['fiber']),
    );
  }
}

class PortionEstimate {
  final String size;
  final double grams;
  final double areaCm2;
  final String method;

  PortionEstimate({
    required this.size,
    required this.grams,
    required this.areaCm2,
    required this.method,
  });

  factory PortionEstimate.fromJson(Map<String, dynamic> json) {
    return PortionEstimate(
      size: json['size'] ?? '',
      grams: _toDouble(json['grams']),
      areaCm2: _toDouble(json['area_cm2']),
      method: json['method'] ?? '',
    );
  }
}

class GoalAnalysis {
  final String goal;
  final double dailyTargetCalories;
  final double mealTargetCalories;
  final double proteinTarget;
  final List<String> warnings;

  GoalAnalysis({
    required this.goal,
    required this.dailyTargetCalories,
    required this.mealTargetCalories,
    required this.proteinTarget,
    required this.warnings,
  });

  factory GoalAnalysis.fromJson(Map<String, dynamic> json) {
    return GoalAnalysis(
      goal: json['goal'] ?? '',
      dailyTargetCalories: _toDouble(json['daily_target_calories']),
      mealTargetCalories: _toDouble(json['meal_target_calories']),
      proteinTarget: _toDouble(json['protein_target']),
      warnings: List<String>.from(json['warnings'] ?? []),
    );
  }
}

class MealImages {
  final String original;
  final String annotated;

  MealImages({
    required this.original,
    required this.annotated,
  });

  factory MealImages.fromJson(Map<String, dynamic> json) {
    return MealImages(
      original: json['original'] ?? '',
      annotated: json['annotated'] ?? '',
    );
  }
}
