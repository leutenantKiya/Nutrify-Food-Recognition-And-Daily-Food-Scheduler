"""
Knowledge base: dish → expected hidden ingredients.

When the pipeline detects a dish (e.g. fried_rice), it knows that the dish
*inherently* contains ingredients that are NOT visible in the image.

This mapping powers the `estimated_hidden_ingredients` field in the API
response, making nutrition estimation much more realistic.
"""

from __future__ import annotations

from typing import Dict, List


# ── Dish → hidden ingredients lookup ──────────────────────────────────
# These are ingredients that are typically INSIDE the dish but NOT
# individually detectable by the YOLO ingredient detector.

DISH_HIDDEN_INGREDIENTS: Dict[str, List[str]] = {
    # Rice dishes
    "fried_rice":              ["oil", "garlic", "soy_sauce", "salt", "pepper"],
    "bibimbap":                ["sesame_oil", "gochujang", "soy_sauce", "garlic"],
    "risotto":                 ["butter", "parmesan", "white_wine", "onion", "broth"],
    "paella":                  ["olive_oil", "saffron", "garlic", "broth", "salt"],

    # Noodle / pasta
    "pad_thai":                ["fish_sauce", "tamarind", "sugar", "oil", "garlic"],
    "ramen":                   ["soy_sauce", "miso", "broth", "sesame_oil", "salt"],
    "pho":                     ["broth", "fish_sauce", "star_anise", "cinnamon", "salt"],
    "spaghetti_bolognese":     ["olive_oil", "garlic", "tomato_sauce", "onion", "salt"],
    "spaghetti_carbonara":     ["egg", "parmesan", "black_pepper", "olive_oil"],
    "lasagna":                 ["olive_oil", "garlic", "tomato_sauce", "bechamel", "salt"],
    "ravioli":                 ["olive_oil", "butter", "salt"],
    "macaroni_and_cheese":     ["butter", "milk", "flour", "salt"],
    "gnocchi":                 ["butter", "salt"],

    # Sandwiches / burgers
    "hamburger":               ["ketchup", "mustard", "mayonnaise", "salt"],
    "club_sandwich":           ["mayonnaise", "butter", "salt"],
    "hot_dog":                 ["ketchup", "mustard", "salt"],
    "grilled_cheese_sandwich": ["butter", "salt"],
    "pulled_pork_sandwich":    ["bbq_sauce", "vinegar", "sugar", "salt"],
    "lobster_roll_sandwich":   ["mayonnaise", "butter", "lemon_juice", "salt"],

    # Egg dishes
    "omelette":                ["butter", "salt", "pepper", "milk"],
    "eggs_benedict":           ["butter", "hollandaise", "vinegar", "salt"],
    "huevos_rancheros":        ["oil", "salsa", "cumin", "salt"],
    "deviled_eggs":            ["mayonnaise", "mustard", "vinegar", "salt"],

    # Chicken
    "chicken_curry":           ["oil", "curry_powder", "coconut_milk", "garlic", "onion", "salt"],
    "chicken_wings":           ["oil", "hot_sauce", "butter", "garlic", "salt"],
    "chicken_quesadilla":      ["oil", "cheese", "salt"],

    # Beef
    "beef_carpaccio":          ["olive_oil", "lemon_juice", "capers", "salt"],
    "beef_tartare":            ["egg_yolk", "mustard", "capers", "worcestershire", "salt"],
    "filet_mignon":            ["butter", "garlic", "thyme", "salt", "pepper"],
    "prime_rib":               ["garlic", "rosemary", "salt", "pepper", "au_jus"],
    "steak":                   ["butter", "garlic", "salt", "pepper"],

    # Fish / seafood
    "grilled_salmon":          ["olive_oil", "lemon_juice", "dill", "salt", "pepper"],
    "sashimi":                 ["soy_sauce", "wasabi"],
    "sushi":                   ["rice_vinegar", "sugar", "soy_sauce", "wasabi", "nori"],
    "ceviche":                 ["lime_juice", "onion", "cilantro", "chili", "salt"],
    "fish_and_chips":          ["oil", "flour", "batter", "salt"],
    "fried_calamari":          ["oil", "flour", "salt"],

    # Soups
    "miso_soup":               ["miso_paste", "dashi", "salt"],
    "french_onion_soup":       ["butter", "broth", "gruyere", "salt"],
    "hot_and_sour_soup":       ["vinegar", "soy_sauce", "sesame_oil", "cornstarch", "salt"],
    "clam_chowder":            ["butter", "flour", "cream", "salt"],
    "lobster_bisque":          ["butter", "cream", "brandy", "salt"],

    # Salads
    "caesar_salad":            ["caesar_dressing", "parmesan", "croutons", "anchovy"],
    "greek_salad":             ["olive_oil", "oregano", "salt", "vinegar"],
    "caprese_salad":           ["olive_oil", "balsamic", "basil", "salt"],
    "beet_salad":              ["olive_oil", "vinegar", "salt"],
    "seaweed_salad":           ["sesame_oil", "rice_vinegar", "soy_sauce", "sugar"],

    # Mexican
    "tacos":                   ["oil", "cumin", "chili_powder", "salt", "salsa"],
    "nachos":                  ["oil", "salt"],
    "guacamole":               ["lime_juice", "salt", "cilantro", "onion"],
    "breakfast_burrito":       ["oil", "salsa", "salt", "cheese"],

    # Asian
    "dumplings":               ["soy_sauce", "sesame_oil", "ginger", "garlic"],
    "gyoza":                   ["soy_sauce", "sesame_oil", "ginger", "garlic"],
    "spring_rolls":            ["oil", "soy_sauce", "garlic"],
    "takoyaki":                ["dashi", "soy_sauce", "ginger", "oil"],
    "edamame":                 ["salt"],
    "samosa":                  ["oil", "cumin", "coriander", "salt"],
    "falafel":                 ["oil", "cumin", "coriander", "garlic", "salt"],

    # Pizza / Italian
    "pizza":                   ["olive_oil", "tomato_sauce", "oregano", "salt"],
    "bruschetta":              ["olive_oil", "garlic", "basil", "salt"],
    "garlic_bread":            ["butter", "garlic", "parsley", "salt"],

    # Fried
    "french_fries":            ["oil", "salt"],
    "onion_rings":             ["oil", "flour", "batter", "salt"],

    # Desserts
    "chocolate_cake":          ["butter", "sugar", "flour", "cocoa", "eggs", "vanilla"],
    "cheesecake":              ["cream_cheese", "sugar", "eggs", "vanilla", "butter"],
    "tiramisu":                ["mascarpone", "espresso", "cocoa", "sugar", "eggs"],
    "apple_pie":               ["butter", "sugar", "flour", "cinnamon"],
    "carrot_cake":             ["oil", "sugar", "flour", "cinnamon", "eggs"],
    "red_velvet_cake":         ["butter", "sugar", "flour", "cocoa", "eggs", "cream_cheese"],
    "cup_cakes":               ["butter", "sugar", "flour", "eggs", "vanilla"],
    "pancakes":                ["butter", "milk", "flour", "eggs", "sugar"],
    "waffles":                 ["butter", "milk", "flour", "eggs", "sugar"],
    "french_toast":            ["butter", "egg", "milk", "cinnamon", "sugar"],
    "churros":                 ["oil", "sugar", "cinnamon", "flour"],
    "donuts":                  ["oil", "sugar", "flour", "yeast"],
    "ice_cream":               ["cream", "sugar", "milk", "vanilla"],
    "frozen_yogurt":           ["sugar", "milk"],
    "panna_cotta":             ["cream", "sugar", "vanilla", "gelatin"],
    "chocolate_mousse":        ["cream", "sugar", "eggs", "chocolate"],
    "creme_brulee":            ["cream", "sugar", "egg_yolk", "vanilla"],
    "macarons":                ["almond_flour", "sugar", "egg_white"],
    "cannoli":                 ["ricotta", "sugar", "chocolate_chips", "oil"],
    "baklava":                 ["butter", "honey", "sugar", "phyllo"],
    "beignets":                ["oil", "sugar", "flour", "yeast"],
    "bread_pudding":           ["butter", "eggs", "milk", "sugar", "vanilla"],
    "strawberry_shortcake":    ["cream", "sugar", "flour", "butter"],

    # Misc
    "hummus":                  ["tahini", "olive_oil", "lemon_juice", "garlic", "salt"],
    "pork_chop":               ["oil", "garlic", "salt", "pepper"],
    "peking_duck":             ["hoisin_sauce", "sugar", "five_spice", "salt"],
    "foie_gras":               ["butter", "salt", "pepper"],
    "escargots":               ["butter", "garlic", "parsley", "salt"],
    "poutine":                 ["gravy", "salt"],
    "shrimp_and_grits":        ["butter", "cream", "salt", "pepper"],
    "croque_madame":           ["butter", "bechamel", "gruyere", "salt"],
    "crab_cakes":              ["mayonnaise", "mustard", "egg", "breadcrumbs", "salt"],
}


def get_hidden_ingredients(dish_label: str) -> List[str]:
    """Return estimated hidden ingredients for a detected dish."""
    return DISH_HIDDEN_INGREDIENTS.get(dish_label, [])
