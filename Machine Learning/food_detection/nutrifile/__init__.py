"""
NutriFile — end-to-end food computer vision package.

Pipeline:
  image -> produce segmentation (YOLOv8-seg, 1 class)
        -> per-crop ingredient classifier (51 classes)  +  dish classifier (101 classes)
        -> portion estimation (mask area + density)
        -> nutrition aggregation
        -> rule-based recommendation + explanation
"""

from . import config
from . import ontology
from . import nutrition
from . import portion
from . import classifier
from . import pipeline
from . import recommend
from . import explain

__all__ = [
    "config",
    "ontology",
    "nutrition",
    "portion",
    "classifier",
    "pipeline",
    "recommend",
    "explain",
]
