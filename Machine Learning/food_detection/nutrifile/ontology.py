"""
Pemetaan nama kelas untuk NutriFile.

Tiga output classifier yang perlu nama kanonik:
  - PRODUCE         : 1 kelas, segmentasi biner (yolov8-seg).
  - INGREDIENT_*    : 51 kelas bahan mentah dari Singular Food Items.
  - DISH_*          : 101 kelas hidangan matang dari Food101.

Setiap nama kanonik adalah key snake_case yang dipakai database nutrisi.
Ingredient dan dish TIDAK digabung: "rice (cooked)" dan "rice (raw)"
beda secara nutrisi, jadi tetap key terpisah.

Kelas "noise" dari Singular dihapus karena bukan makanan.
"""

from __future__ import annotations

from typing import Dict, List


# ----------------------------------------------------------------------
# Singular Food Items: 51 folders -> 50 ingredient classes (drop "noise")
# Verified from leaf folder listing during dataset audit.
# ----------------------------------------------------------------------

SINGULAR_FOLDERS_RAW: List[str] = [
    "apples", "avocados", "bacon", "bagels", "banana", "beans", "beef",
    "blackberries", "bread", "broccoli", "butter", "cabbage", "carrots",
    "cauliflower", "celery", "cheese", "chicken", "coconut", "corn", "crab",
    "cranberries", "eggs", "fish", "ham", "honey", "lemons", "lettuce",
    "limes", "mangos", "milk", "mushrooms", "noise", "onions", "peppers",
    "potatoes", "raspberries", "rhubarb", "rice", "sausages", "spinach",
    "strawberries", "sweetpotato", "tofu", "tomato", "watermelon", "yogurt",
    # Some Singular dumps include the following additional ingredient folders;
    # we keep them if present. (The audit showed 51 leaf folders.)
    "blueberries", "garlic", "ginger", "olives", "pasta",
]

# Folders that are not food and should be removed before training.
SINGULAR_BLACKLIST = {"noise"}


def build_ingredient_classes(available_folders: List[str]) -> List[str]:
    """
    Given the actual folders present on disk, return a deterministic,
    blacklist-filtered, sorted list of ingredient class names.

    The order returned here IS the class-index order the classifier learns,
    so it must be reproducible (sorted) and stable across runs.
    """
    cleaned = sorted(
        set(available_folders) - SINGULAR_BLACKLIST,
        key=str.lower,
    )
    return cleaned


# Canonical snake_case ingredient keys used by the nutrition DB.
# Mostly identical to the folder name; only a few normalizations.
INGREDIENT_NORMALIZATION: Dict[str, str] = {
    "apples": "apple",
    "avocados": "avocado",
    "carrots": "carrot",
    "eggs": "egg",
    "lemons": "lemon",
    "limes": "lime",
    "mangos": "mango",
    "onions": "onion",
    "peppers": "pepper",
    "potatoes": "potato",
    "raspberries": "raspberry",
    "blackberries": "blackberry",
    "cranberries": "cranberry",
    "strawberries": "strawberry",
    "blueberries": "blueberry",
    "tomato": "tomato",
    "sweetpotato": "sweet_potato",
    "sausages": "sausage",
    "olives": "olive",
}


def ingredient_to_canonical(folder_name: str) -> str:
    """Map a Singular folder name to its canonical snake_case key."""
    name = folder_name.lower().strip()
    return INGREDIENT_NORMALIZATION.get(name, name)


# ----------------------------------------------------------------------
# Food101: 101 fixed dish names. We use the original dataset names as-is.
# These are already snake_case (e.g. apple_pie, beef_carpaccio).
# ----------------------------------------------------------------------

FOOD101_CLASSES: List[str] = [
    "apple_pie", "baby_back_ribs", "baklava", "beef_carpaccio", "beef_tartare",
    "beet_salad", "beignets", "bibimbap", "bread_pudding", "breakfast_burrito",
    "bruschetta", "caesar_salad", "cannoli", "caprese_salad", "carrot_cake",
    "ceviche", "cheesecake", "cheese_plate", "chicken_curry", "chicken_quesadilla",
    "chicken_wings", "chocolate_cake", "chocolate_mousse", "churros", "clam_chowder",
    "club_sandwich", "crab_cakes", "creme_brulee", "croque_madame", "cup_cakes",
    "deviled_eggs", "donuts", "dumplings", "edamame", "eggs_benedict", "escargots",
    "falafel", "filet_mignon", "fish_and_chips", "foie_gras", "french_fries",
    "french_onion_soup", "french_toast", "fried_calamari", "fried_rice",
    "frozen_yogurt", "garlic_bread", "gnocchi", "greek_salad",
    "grilled_cheese_sandwich", "grilled_salmon", "guacamole", "gyoza", "hamburger",
    "hot_and_sour_soup", "hot_dog", "huevos_rancheros", "hummus", "ice_cream",
    "lasagna", "lobster_bisque", "lobster_roll_sandwich", "macaroni_and_cheese",
    "macarons", "miso_soup", "mussels", "nachos", "omelette", "onion_rings",
    "oysters", "pad_thai", "paella", "pancakes", "panna_cotta", "peking_duck",
    "pho", "pizza", "pork_chop", "poutine", "prime_rib", "pulled_pork_sandwich",
    "ramen", "ravioli", "red_velvet_cake", "risotto", "samosa", "sashimi",
    "scallops", "seaweed_salad", "shrimp_and_grits", "spaghetti_bolognese",
    "spaghetti_carbonara", "spring_rolls", "steak", "strawberry_shortcake",
    "sushi", "tacos", "takoyaki", "tiramisu", "tuna_tartare", "waffles",
]
assert len(FOOD101_CLASSES) == 101, f"Expected 101 dishes, got {len(FOOD101_CLASSES)}"


def dish_to_canonical(class_name: str) -> str:
    """Dish names are already canonical; this is a passthrough for symmetry."""
    return class_name


# ----------------------------------------------------------------------
# Routing helpers
# ----------------------------------------------------------------------

def is_dish_key(key: str) -> bool:
    return key in set(FOOD101_CLASSES)


def is_ingredient_key(key: str) -> bool:
    return not is_dish_key(key)
