"""
Database nutrisi untuk NutriFile.

Semua nilai per 100g porsi yang bisa dimakan. Sumber:
  - USDA FoodData Central (dibulatkan ke integer untuk kkal/natrium,
    1 desimal untuk makro).
  - Untuk hidangan komposit (Food101), dirata-rata dari kartu resep umum
    dan diberi tag kepercayaan.

Skema:
    {
      "<key_kanonik>": {
        "kcal":   <float>,    # per 100g
        "carbs":  <float g>,
        "protein":<float g>,
        "fat":    <float g>,
        "sugar":  <float g>,
        "sodium": <float mg>,
        "fiber":  <float g>,
        "density_g_per_cm2": <float>,   # dipakai oleh estimator porsi
        "confidence": "high" | "med" | "low",
        "category": "ingredient" | "dish",
      }
    }

Key yang tidak ada di database akan fallback ke FALLBACK_ENTRY supaya pipeline tidak crash.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, Optional

from . import ontology


# ----------------------------------------------------------------------
# Reference: typical food density on a plate (grams per cm^2 of visible area).
# Empirical: 1 cm^2 of food viewed from above weighs roughly density g.
# Tuned so a 25 cm plate fully covered in rice weighs ~150–200 g.
# ----------------------------------------------------------------------

_INGREDIENT_DB: Dict[str, Dict[str, float]] = {
    # Fruits
    "apple":       dict(kcal=52,  carbs=14,  protein=0.3, fat=0.2, sugar=10.4, sodium=1,  fiber=2.4, density_g_per_cm2=0.40),
    "avocado":     dict(kcal=160, carbs=8.5, protein=2.0, fat=14.7, sugar=0.7, sodium=7,  fiber=6.7, density_g_per_cm2=0.50),
    "banana":      dict(kcal=89,  carbs=23,  protein=1.1, fat=0.3, sugar=12.2, sodium=1,  fiber=2.6, density_g_per_cm2=0.45),
    "blackberry":  dict(kcal=43,  carbs=10,  protein=1.4, fat=0.5, sugar=4.9,  sodium=1,  fiber=5.3, density_g_per_cm2=0.30),
    "blueberry":   dict(kcal=57,  carbs=14,  protein=0.7, fat=0.3, sugar=10,   sodium=1,  fiber=2.4, density_g_per_cm2=0.30),
    "coconut":     dict(kcal=354, carbs=15,  protein=3.3, fat=33.5, sugar=6.2, sodium=20, fiber=9.0, density_g_per_cm2=0.50),
    "cranberry":   dict(kcal=46,  carbs=12,  protein=0.4, fat=0.1, sugar=4.0,  sodium=2,  fiber=4.6, density_g_per_cm2=0.30),
    "lemon":       dict(kcal=29,  carbs=9,   protein=1.1, fat=0.3, sugar=2.5,  sodium=2,  fiber=2.8, density_g_per_cm2=0.40),
    "lime":        dict(kcal=30,  carbs=11,  protein=0.7, fat=0.2, sugar=1.7,  sodium=2,  fiber=2.8, density_g_per_cm2=0.40),
    "mango":       dict(kcal=60,  carbs=15,  protein=0.8, fat=0.4, sugar=13.7, sodium=1,  fiber=1.6, density_g_per_cm2=0.45),
    "olive":       dict(kcal=115, carbs=6.3, protein=0.8, fat=10.7, sugar=0.5, sodium=735,fiber=3.2, density_g_per_cm2=0.40),
    "raspberry":   dict(kcal=52,  carbs=12,  protein=1.2, fat=0.7, sugar=4.4,  sodium=1,  fiber=6.5, density_g_per_cm2=0.30),
    "rhubarb":     dict(kcal=21,  carbs=4.5, protein=0.9, fat=0.2, sugar=1.1,  sodium=4,  fiber=1.8, density_g_per_cm2=0.30),
    "strawberry":  dict(kcal=32,  carbs=7.7, protein=0.7, fat=0.3, sugar=4.9,  sodium=1,  fiber=2.0, density_g_per_cm2=0.30),
    "watermelon":  dict(kcal=30,  carbs=7.6, protein=0.6, fat=0.2, sugar=6.2,  sodium=1,  fiber=0.4, density_g_per_cm2=0.40),

    # Vegetables
    "broccoli":    dict(kcal=34,  carbs=7.0, protein=2.8, fat=0.4, sugar=1.7,  sodium=33, fiber=2.6, density_g_per_cm2=0.30),
    "cabbage":     dict(kcal=25,  carbs=5.8, protein=1.3, fat=0.1, sugar=3.2,  sodium=18, fiber=2.5, density_g_per_cm2=0.30),
    "carrot":      dict(kcal=41,  carbs=10,  protein=0.9, fat=0.2, sugar=4.7,  sodium=69, fiber=2.8, density_g_per_cm2=0.40),
    "cauliflower": dict(kcal=25,  carbs=5.0, protein=1.9, fat=0.3, sugar=1.9,  sodium=30, fiber=2.0, density_g_per_cm2=0.30),
    "celery":      dict(kcal=16,  carbs=3.0, protein=0.7, fat=0.2, sugar=1.3,  sodium=80, fiber=1.6, density_g_per_cm2=0.25),
    "corn":        dict(kcal=86,  carbs=19,  protein=3.3, fat=1.4, sugar=3.2,  sodium=15, fiber=2.7, density_g_per_cm2=0.45),
    "garlic":      dict(kcal=149, carbs=33,  protein=6.4, fat=0.5, sugar=1.0,  sodium=17, fiber=2.1, density_g_per_cm2=0.40),
    "ginger":      dict(kcal=80,  carbs=18,  protein=1.8, fat=0.8, sugar=1.7,  sodium=13, fiber=2.0, density_g_per_cm2=0.40),
    "lettuce":     dict(kcal=15,  carbs=2.9, protein=1.4, fat=0.2, sugar=0.8,  sodium=28, fiber=1.3, density_g_per_cm2=0.20),
    "mushroom":    dict(kcal=22,  carbs=3.3, protein=3.1, fat=0.3, sugar=2.0,  sodium=5,  fiber=1.0, density_g_per_cm2=0.30),
    "mushrooms":   dict(kcal=22,  carbs=3.3, protein=3.1, fat=0.3, sugar=2.0,  sodium=5,  fiber=1.0, density_g_per_cm2=0.30),
    "onion":       dict(kcal=40,  carbs=9.3, protein=1.1, fat=0.1, sugar=4.2,  sodium=4,  fiber=1.7, density_g_per_cm2=0.40),
    "pepper":      dict(kcal=31,  carbs=6.0, protein=1.0, fat=0.3, sugar=4.2,  sodium=4,  fiber=2.1, density_g_per_cm2=0.30),
    "potato":      dict(kcal=77,  carbs=17,  protein=2.0, fat=0.1, sugar=0.8,  sodium=6,  fiber=2.2, density_g_per_cm2=0.45),
    "spinach":     dict(kcal=23,  carbs=3.6, protein=2.9, fat=0.4, sugar=0.4,  sodium=79, fiber=2.2, density_g_per_cm2=0.20),
    "sweet_potato":dict(kcal=86,  carbs=20,  protein=1.6, fat=0.1, sugar=4.2,  sodium=55, fiber=3.0, density_g_per_cm2=0.45),
    "tomato":      dict(kcal=18,  carbs=3.9, protein=0.9, fat=0.2, sugar=2.6,  sodium=5,  fiber=1.2, density_g_per_cm2=0.35),

    # Protein
    "bacon":       dict(kcal=541, carbs=1.4, protein=37,  fat=42,  sugar=0.0,  sodium=1717,fiber=0.0, density_g_per_cm2=0.45),
    "beans":       dict(kcal=127, carbs=23,  protein=8.7, fat=0.5, sugar=0.3,  sodium=6,  fiber=6.4, density_g_per_cm2=0.40),
    "beef":        dict(kcal=250, carbs=0.0, protein=26,  fat=15,  sugar=0.0,  sodium=72, fiber=0.0, density_g_per_cm2=0.55),
    "chicken":     dict(kcal=165, carbs=0.0, protein=31,  fat=3.6, sugar=0.0,  sodium=74, fiber=0.0, density_g_per_cm2=0.50),
    "crab":        dict(kcal=83,  carbs=0.0, protein=18,  fat=1.0, sugar=0.0,  sodium=395,fiber=0.0, density_g_per_cm2=0.45),
    "egg":         dict(kcal=143, carbs=0.7, protein=12.6,fat=9.5, sugar=0.4,  sodium=142,fiber=0.0, density_g_per_cm2=0.45),
    "fish":        dict(kcal=140, carbs=0.0, protein=20,  fat=6.3, sugar=0.0,  sodium=85, fiber=0.0, density_g_per_cm2=0.50),
    "ham":         dict(kcal=145, carbs=1.5, protein=21,  fat=5.5, sugar=0.8,  sodium=1203,fiber=0.0, density_g_per_cm2=0.50),
    "sausage":     dict(kcal=301, carbs=2.0, protein=12,  fat=27,  sugar=0.6,  sodium=698,fiber=0.0, density_g_per_cm2=0.50),
    "tofu":        dict(kcal=76,  carbs=1.9, protein=8.0, fat=4.8, sugar=0.6,  sodium=7,  fiber=0.3, density_g_per_cm2=0.45),

    # Grains / breads / pasta
    "bagel":       dict(kcal=257, carbs=51,  protein=10,  fat=1.5, sugar=5.0,  sodium=439,fiber=2.1, density_g_per_cm2=0.45),
    "bagels":      dict(kcal=257, carbs=51,  protein=10,  fat=1.5, sugar=5.0,  sodium=439,fiber=2.1, density_g_per_cm2=0.45),
    "bread":       dict(kcal=265, carbs=49,  protein=9.0, fat=3.2, sugar=5.0,  sodium=491,fiber=2.7, density_g_per_cm2=0.30),
    "pasta":       dict(kcal=131, carbs=25,  protein=5.0, fat=1.1, sugar=0.6,  sodium=6,  fiber=1.8, density_g_per_cm2=0.40),
    "rice":        dict(kcal=130, carbs=28,  protein=2.7, fat=0.3, sugar=0.1,  sodium=1,  fiber=0.4, density_g_per_cm2=0.45),

    # Dairy / fats / sweet
    "butter":      dict(kcal=717, carbs=0.1, protein=0.9, fat=81,  sugar=0.1,  sodium=11, fiber=0.0, density_g_per_cm2=0.60),
    "cheese":      dict(kcal=402, carbs=1.3, protein=25,  fat=33,  sugar=0.5,  sodium=621,fiber=0.0, density_g_per_cm2=0.55),
    "honey":       dict(kcal=304, carbs=82,  protein=0.3, fat=0.0, sugar=82,   sodium=4,  fiber=0.2, density_g_per_cm2=0.70),
    "milk":        dict(kcal=42,  carbs=5.0, protein=3.4, fat=1.0, sugar=5.0,  sodium=44, fiber=0.0, density_g_per_cm2=0.50),
    "yogurt":      dict(kcal=59,  carbs=3.6, protein=10,  fat=0.4, sugar=3.2,  sodium=36, fiber=0.0, density_g_per_cm2=0.50),
}


_DISH_DB: Dict[str, Dict[str, float]] = {
    # Cooked dishes — typical per-100g; portion sizes vary so calorie totals
    # rely on visible area + density_g_per_cm2 below.
    "apple_pie":               dict(kcal=237, carbs=34, protein=2.4, fat=11,  sugar=18,  sodium=266, fiber=1.4, density_g_per_cm2=0.40),
    "baby_back_ribs":          dict(kcal=292, carbs=0.0,protein=23,  fat=21,  sugar=0.0, sodium=590, fiber=0.0, density_g_per_cm2=0.60),
    "baklava":                 dict(kcal=403, carbs=46, protein=6.0, fat=22,  sugar=33,  sodium=205, fiber=2.0, density_g_per_cm2=0.45),
    "beef_carpaccio":          dict(kcal=180, carbs=2.0,protein=22,  fat=9.0, sugar=0.5, sodium=420, fiber=0.5, density_g_per_cm2=0.45),
    "beef_tartare":            dict(kcal=190, carbs=2.0,protein=21,  fat=10,  sugar=0.5, sodium=400, fiber=0.5, density_g_per_cm2=0.45),
    "beet_salad":              dict(kcal=110, carbs=14, protein=2.5, fat=5.0, sugar=10,  sodium=350, fiber=3.5, density_g_per_cm2=0.30),
    "beignets":                dict(kcal=400, carbs=45, protein=6.0, fat=22,  sugar=15,  sodium=260, fiber=1.5, density_g_per_cm2=0.40),
    "bibimbap":                dict(kcal=160, carbs=22, protein=7.0, fat=5.0, sugar=3.0, sodium=480, fiber=2.5, density_g_per_cm2=0.50),
    "bread_pudding":           dict(kcal=240, carbs=35, protein=6.0, fat=9.0, sugar=20,  sodium=240, fiber=1.0, density_g_per_cm2=0.45),
    "breakfast_burrito":       dict(kcal=215, carbs=25, protein=10,  fat=9.0, sugar=2.0, sodium=620, fiber=2.0, density_g_per_cm2=0.50),
    "bruschetta":              dict(kcal=200, carbs=28, protein=6.0, fat=7.0, sugar=2.5, sodium=380, fiber=2.0, density_g_per_cm2=0.35),
    "caesar_salad":            dict(kcal=158, carbs=8.0,protein=6.0, fat=12,  sugar=2.0, sodium=470, fiber=2.0, density_g_per_cm2=0.30),
    "cannoli":                 dict(kcal=370, carbs=43, protein=7.0, fat=19,  sugar=28,  sodium=180, fiber=1.0, density_g_per_cm2=0.45),
    "caprese_salad":           dict(kcal=145, carbs=4.5,protein=8.0, fat=11,  sugar=3.0, sodium=380, fiber=1.0, density_g_per_cm2=0.30),
    "carrot_cake":             dict(kcal=380, carbs=46, protein=4.5, fat=20,  sugar=30,  sodium=270, fiber=1.5, density_g_per_cm2=0.45),
    "ceviche":                 dict(kcal=110, carbs=4.0,protein=18,  fat=2.0, sugar=2.0, sodium=420, fiber=1.0, density_g_per_cm2=0.40),
    "cheesecake":              dict(kcal=321, carbs=26, protein=5.5, fat=22,  sugar=22,  sodium=210, fiber=0.5, density_g_per_cm2=0.55),
    "cheese_plate":            dict(kcal=380, carbs=4.0,protein=22,  fat=30,  sugar=2.0, sodium=620, fiber=0.5, density_g_per_cm2=0.50),
    "chicken_curry":           dict(kcal=160, carbs=8.0,protein=14,  fat=8.0, sugar=3.0, sodium=480, fiber=1.5, density_g_per_cm2=0.50),
    "chicken_quesadilla":      dict(kcal=270, carbs=22, protein=14,  fat=14,  sugar=2.0, sodium=560, fiber=1.5, density_g_per_cm2=0.50),
    "chicken_wings":           dict(kcal=290, carbs=1.0,protein=27,  fat=20,  sugar=0.5, sodium=600, fiber=0.0, density_g_per_cm2=0.55),
    "chocolate_cake":          dict(kcal=370, carbs=51, protein=4.5, fat=17,  sugar=37,  sodium=300, fiber=2.5, density_g_per_cm2=0.50),
    "chocolate_mousse":        dict(kcal=270, carbs=29, protein=4.5, fat=15,  sugar=24,  sodium=60,  fiber=1.5, density_g_per_cm2=0.50),
    "churros":                 dict(kcal=370, carbs=44, protein=5.0, fat=20,  sugar=15,  sodium=250, fiber=1.5, density_g_per_cm2=0.45),
    "clam_chowder":            dict(kcal=95,  carbs=10, protein=5.0, fat=4.0, sugar=2.0, sodium=480, fiber=1.0, density_g_per_cm2=0.50),
    "club_sandwich":           dict(kcal=290, carbs=22, protein=15,  fat=15,  sugar=3.0, sodium=620, fiber=2.0, density_g_per_cm2=0.40),
    "crab_cakes":              dict(kcal=215, carbs=12, protein=14,  fat=12,  sugar=1.0, sodium=560, fiber=1.0, density_g_per_cm2=0.50),
    "creme_brulee":            dict(kcal=290, carbs=20, protein=4.0, fat=21,  sugar=18,  sodium=70,  fiber=0.0, density_g_per_cm2=0.55),
    "croque_madame":           dict(kcal=300, carbs=20, protein=16,  fat=17,  sugar=2.0, sodium=580, fiber=1.5, density_g_per_cm2=0.50),
    "cup_cakes":               dict(kcal=370, carbs=48, protein=4.0, fat=18,  sugar=35,  sodium=290, fiber=1.0, density_g_per_cm2=0.45),
    "deviled_eggs":            dict(kcal=190, carbs=1.5,protein=11,  fat=15,  sugar=1.0, sodium=300, fiber=0.0, density_g_per_cm2=0.45),
    "donuts":                  dict(kcal=420, carbs=51, protein=5.5, fat=22,  sugar=25,  sodium=320, fiber=1.5, density_g_per_cm2=0.40),
    "dumplings":               dict(kcal=240, carbs=33, protein=8.0, fat=8.0, sugar=2.0, sodium=420, fiber=1.5, density_g_per_cm2=0.50),
    "edamame":                 dict(kcal=121, carbs=9.0,protein=12,  fat=5.0, sugar=2.0, sodium=6,   fiber=5.0, density_g_per_cm2=0.40),
    "eggs_benedict":           dict(kcal=230, carbs=14, protein=11,  fat=15,  sugar=2.0, sodium=440, fiber=1.0, density_g_per_cm2=0.50),
    "escargots":               dict(kcal=200, carbs=2.0,protein=16,  fat=14,  sugar=0.0, sodium=420, fiber=0.5, density_g_per_cm2=0.55),
    "falafel":                 dict(kcal=333, carbs=32, protein=14,  fat=18,  sugar=1.0, sodium=294, fiber=4.9, density_g_per_cm2=0.45),
    "filet_mignon":             dict(kcal=270, carbs=0.0,protein=27,  fat=18,  sugar=0.0, sodium=70,  fiber=0.0, density_g_per_cm2=0.60),
    "fish_and_chips":          dict(kcal=290, carbs=27, protein=11,  fat=15,  sugar=1.0, sodium=520, fiber=2.5, density_g_per_cm2=0.50),
    "foie_gras":               dict(kcal=460, carbs=4.0,protein=12,  fat=44,  sugar=2.0, sodium=700, fiber=0.0, density_g_per_cm2=0.60),
    "french_fries":            dict(kcal=312, carbs=41, protein=3.4, fat=15,  sugar=0.3, sodium=210, fiber=3.8, density_g_per_cm2=0.40),
    "french_onion_soup":       dict(kcal=95,  carbs=9.0,protein=4.0, fat=5.0, sugar=4.0, sodium=560, fiber=1.5, density_g_per_cm2=0.50),
    "french_toast":            dict(kcal=240, carbs=27, protein=8.0, fat=11,  sugar=8.0, sodium=320, fiber=1.0, density_g_per_cm2=0.45),
    "fried_calamari":          dict(kcal=250, carbs=15, protein=14,  fat=14,  sugar=0.5, sodium=480, fiber=0.5, density_g_per_cm2=0.50),
    "fried_rice":              dict(kcal=180, carbs=24, protein=5.0, fat=7.0, sugar=1.0, sodium=480, fiber=1.0, density_g_per_cm2=0.50),
    "frozen_yogurt":           dict(kcal=159, carbs=24, protein=4.0, fat=4.0, sugar=23,  sodium=70,  fiber=0.0, density_g_per_cm2=0.55),
    "garlic_bread":            dict(kcal=350, carbs=43, protein=8.0, fat=15,  sugar=2.0, sodium=540, fiber=2.0, density_g_per_cm2=0.40),
    "gnocchi":                 dict(kcal=170, carbs=32, protein=4.0, fat=2.0, sugar=1.0, sodium=240, fiber=1.5, density_g_per_cm2=0.50),
    "greek_salad":             dict(kcal=120, carbs=6.0,protein=4.0, fat=9.0, sugar=3.0, sodium=480, fiber=2.0, density_g_per_cm2=0.30),
    "grilled_cheese_sandwich": dict(kcal=320, carbs=28, protein=13,  fat=17,  sugar=4.0, sodium=620, fiber=2.0, density_g_per_cm2=0.45),
    "grilled_salmon":          dict(kcal=208, carbs=0.0,protein=22,  fat=13,  sugar=0.0, sodium=80,  fiber=0.0, density_g_per_cm2=0.55),
    "guacamole":               dict(kcal=150, carbs=8.0,protein=2.0, fat=14,  sugar=1.0, sodium=300, fiber=6.0, density_g_per_cm2=0.55),
    "gyoza":                   dict(kcal=220, carbs=27, protein=7.0, fat=8.0, sugar=2.0, sodium=460, fiber=1.5, density_g_per_cm2=0.50),
    "hamburger":               dict(kcal=295, carbs=22, protein=17,  fat=15,  sugar=4.0, sodium=480, fiber=1.5, density_g_per_cm2=0.50),
    "hot_and_sour_soup":       dict(kcal=70,  carbs=8.0,protein=4.0, fat=2.5, sugar=2.0, sodium=620, fiber=1.0, density_g_per_cm2=0.50),
    "hot_dog":                 dict(kcal=290, carbs=18, protein=10,  fat=20,  sugar=4.0, sodium=680, fiber=1.0, density_g_per_cm2=0.50),
    "huevos_rancheros":        dict(kcal=180, carbs=18, protein=9.0, fat=8.0, sugar=2.0, sodium=420, fiber=2.5, density_g_per_cm2=0.50),
    "hummus":                  dict(kcal=166, carbs=14, protein=8.0, fat=10,  sugar=0.5, sodium=380, fiber=6.0, density_g_per_cm2=0.50),
    "ice_cream":               dict(kcal=207, carbs=24, protein=3.5, fat=11,  sugar=21,  sodium=80,  fiber=0.5, density_g_per_cm2=0.55),
    "lasagna":                 dict(kcal=180, carbs=18, protein=10,  fat=8.0, sugar=3.0, sodium=480, fiber=2.0, density_g_per_cm2=0.55),
    "lobster_bisque":          dict(kcal=110, carbs=6.0,protein=6.0, fat=7.0, sugar=2.0, sodium=540, fiber=0.5, density_g_per_cm2=0.50),
    "lobster_roll_sandwich":   dict(kcal=240, carbs=18, protein=14,  fat=12,  sugar=3.0, sodium=520, fiber=1.0, density_g_per_cm2=0.45),
    "macaroni_and_cheese":     dict(kcal=210, carbs=22, protein=9.0, fat=10,  sugar=2.0, sodium=480, fiber=1.0, density_g_per_cm2=0.50),
    "macarons":                dict(kcal=420, carbs=60, protein=6.0, fat=18,  sugar=45,  sodium=80,  fiber=2.0, density_g_per_cm2=0.50),
    "miso_soup":               dict(kcal=40,  carbs=5.0,protein=2.5, fat=1.0, sugar=1.0, sodium=620, fiber=0.5, density_g_per_cm2=0.50),
    "mussels":                 dict(kcal=172, carbs=7.0,protein=24,  fat=4.5, sugar=0.5, sodium=369, fiber=0.0, density_g_per_cm2=0.55),
    "nachos":                  dict(kcal=343, carbs=36, protein=8.0, fat=18,  sugar=2.0, sodium=560, fiber=3.0, density_g_per_cm2=0.40),
    "omelette":                dict(kcal=154, carbs=1.0,protein=11,  fat=12,  sugar=0.5, sodium=300, fiber=0.0, density_g_per_cm2=0.50),
    "onion_rings":             dict(kcal=330, carbs=39, protein=5.0, fat=17,  sugar=4.0, sodium=440, fiber=2.0, density_g_per_cm2=0.40),
    "oysters":                 dict(kcal=68,  carbs=4.0,protein=7.0, fat=2.5, sugar=0.0, sodium=240, fiber=0.0, density_g_per_cm2=0.55),
    "pad_thai":                dict(kcal=180, carbs=24, protein=7.0, fat=6.0, sugar=4.0, sodium=480, fiber=1.5, density_g_per_cm2=0.50),
    "paella":                  dict(kcal=170, carbs=20, protein=8.0, fat=6.0, sugar=1.5, sodium=460, fiber=1.5, density_g_per_cm2=0.50),
    "pancakes":                dict(kcal=227, carbs=28, protein=6.4, fat=10,  sugar=6.0, sodium=439, fiber=1.0, density_g_per_cm2=0.45),
    "panna_cotta":             dict(kcal=240, carbs=22, protein=4.0, fat=15,  sugar=20,  sodium=60,  fiber=0.0, density_g_per_cm2=0.55),
    "peking_duck":             dict(kcal=337, carbs=2.0,protein=19,  fat=28,  sugar=1.0, sodium=84,  fiber=0.0, density_g_per_cm2=0.55),
    "pho":                     dict(kcal=85,  carbs=12, protein=5.5, fat=1.5, sugar=2.0, sodium=620, fiber=1.0, density_g_per_cm2=0.50),
    "pizza":                   dict(kcal=266, carbs=33, protein=11,  fat=10,  sugar=3.6, sodium=598, fiber=2.3, density_g_per_cm2=0.45),
    "pork_chop":               dict(kcal=231, carbs=0.0,protein=26,  fat=14,  sugar=0.0, sodium=60,  fiber=0.0, density_g_per_cm2=0.55),
    "poutine":                 dict(kcal=233, carbs=25, protein=6.0, fat=12,  sugar=1.0, sodium=480, fiber=2.0, density_g_per_cm2=0.50),
    "prime_rib":               dict(kcal=320, carbs=0.0,protein=25,  fat=24,  sugar=0.0, sodium=80,  fiber=0.0, density_g_per_cm2=0.60),
    "pulled_pork_sandwich":    dict(kcal=265, carbs=22, protein=15,  fat=12,  sugar=8.0, sodium=580, fiber=1.5, density_g_per_cm2=0.50),
    "ramen":                   dict(kcal=140, carbs=18, protein=5.0, fat=5.0, sugar=2.0, sodium=860, fiber=1.0, density_g_per_cm2=0.50),
    "ravioli":                 dict(kcal=180, carbs=24, protein=8.0, fat=6.0, sugar=2.0, sodium=420, fiber=1.5, density_g_per_cm2=0.50),
    "red_velvet_cake":         dict(kcal=370, carbs=49, protein=4.0, fat=18,  sugar=36,  sodium=290, fiber=1.0, density_g_per_cm2=0.50),
    "risotto":                 dict(kcal=175, carbs=25, protein=4.0, fat=6.0, sugar=1.0, sodium=440, fiber=1.0, density_g_per_cm2=0.50),
    "samosa":                  dict(kcal=308, carbs=32, protein=5.0, fat=18,  sugar=2.0, sodium=420, fiber=2.5, density_g_per_cm2=0.45),
    "sashimi":                 dict(kcal=130, carbs=0.0,protein=22,  fat=5.0, sugar=0.0, sodium=80,  fiber=0.0, density_g_per_cm2=0.55),
    "scallops":                dict(kcal=88,  carbs=2.0,protein=17,  fat=0.8, sugar=0.0, sodium=160, fiber=0.0, density_g_per_cm2=0.55),
    "seaweed_salad":           dict(kcal=70,  carbs=8.0,protein=2.0, fat=4.0, sugar=2.0, sodium=620, fiber=2.5, density_g_per_cm2=0.30),
    "shrimp_and_grits":        dict(kcal=200, carbs=20, protein=11,  fat=9.0, sugar=1.5, sodium=520, fiber=1.0, density_g_per_cm2=0.50),
    "spaghetti_bolognese":     dict(kcal=160, carbs=20, protein=8.0, fat=5.0, sugar=3.0, sodium=420, fiber=2.0, density_g_per_cm2=0.50),
    "spaghetti_carbonara":     dict(kcal=215, carbs=22, protein=9.0, fat=10,  sugar=1.5, sodium=520, fiber=1.5, density_g_per_cm2=0.50),
    "spring_rolls":            dict(kcal=190, carbs=22, protein=4.0, fat=9.0, sugar=2.0, sodium=380, fiber=1.5, density_g_per_cm2=0.45),
    "steak":                   dict(kcal=271, carbs=0.0,protein=26,  fat=18,  sugar=0.0, sodium=60,  fiber=0.0, density_g_per_cm2=0.60),
    "strawberry_shortcake":    dict(kcal=290, carbs=37, protein=4.0, fat=14,  sugar=24,  sodium=240, fiber=1.5, density_g_per_cm2=0.45),
    "sushi":                   dict(kcal=150, carbs=22, protein=6.0, fat=4.0, sugar=2.5, sodium=420, fiber=1.0, density_g_per_cm2=0.55),
    "tacos":                   dict(kcal=226, carbs=21, protein=9.0, fat=12,  sugar=2.0, sodium=410, fiber=2.5, density_g_per_cm2=0.45),
    "takoyaki":                dict(kcal=185, carbs=18, protein=8.0, fat=8.0, sugar=2.0, sodium=460, fiber=1.0, density_g_per_cm2=0.50),
    "tiramisu":                dict(kcal=340, carbs=30, protein=6.0, fat=22,  sugar=22,  sodium=170, fiber=0.5, density_g_per_cm2=0.55),
    "tuna_tartare":            dict(kcal=170, carbs=2.0,protein=24,  fat=7.0, sugar=0.5, sodium=320, fiber=0.5, density_g_per_cm2=0.50),
    "waffles":                 dict(kcal=291, carbs=33, protein=8.0, fat=15,  sugar=8.0, sodium=511, fiber=1.5, density_g_per_cm2=0.45),
}


# ----------------------------------------------------------------------
# Fallback for any missing canonical key.
# Values picked so that "unknown" food contributes a moderate generic load.
# ----------------------------------------------------------------------

FALLBACK_ENTRY: Dict[str, float] = dict(
    kcal=200, carbs=20, protein=8.0, fat=8.0,
    sugar=3.0, sodium=300, fiber=2.0, density_g_per_cm2=0.45,
)


# ----------------------------------------------------------------------
# Tag categories + confidence
# ----------------------------------------------------------------------

def _tag(entry: Dict[str, float], category: str, confidence: str) -> Dict[str, float]:
    out = dict(entry)
    out["category"] = category
    out["confidence"] = confidence
    return out


_DB_FINAL: Dict[str, Dict[str, float]] = {}

for key, entry in _INGREDIENT_DB.items():
    _DB_FINAL[key] = _tag(entry, "ingredient", "high")

for key, entry in _DISH_DB.items():
    _DB_FINAL[key] = _tag(entry, "dish", "med")


def lookup(canonical_key: str) -> Dict[str, float]:
    """Return nutrition entry for a key; fallback if missing."""
    if canonical_key in _DB_FINAL:
        return _DB_FINAL[canonical_key]
    return _tag(FALLBACK_ENTRY, "unknown", "low")


def has_entry(canonical_key: str) -> bool:
    return canonical_key in _DB_FINAL


def all_keys() -> list[str]:
    return sorted(_DB_FINAL.keys())


def coverage_report() -> Dict[str, list[str]]:
    """Report which ontology keys do/do not have nutrition entries."""
    expected = set(ontology.FOOD101_CLASSES)
    expected |= {
        ontology.ingredient_to_canonical(name)
        for name in ontology.SINGULAR_FOLDERS_RAW
        if name not in ontology.SINGULAR_BLACKLIST
    }
    have = set(_DB_FINAL.keys())
    return {
        "covered": sorted(expected & have),
        "missing": sorted(expected - have),
        "extra":   sorted(have - expected),
    }


def export_json(path: Path | str) -> Path:
    """Persist the database to disk for reuse outside the package."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(_DB_FINAL, f, indent=2, sort_keys=True)
    return path


def load_json(path: Path | str) -> Dict[str, Dict[str, float]]:
    """Override the in-memory DB from a JSON file (e.g. an updated copy)."""
    global _DB_FINAL
    with Path(path).open("r", encoding="utf-8") as f:
        _DB_FINAL = json.load(f)
    return _DB_FINAL
