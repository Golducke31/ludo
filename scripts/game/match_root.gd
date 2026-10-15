extends Node2D
## Match scene root (gray M2). The setup screen configures Game before this
## scene loads; _ready attaches and begins. Children (board/piece/dice/hud/
## overlays/input) connect their signals in their own _ready, which runs
## before this node's, so every EventBus emission lands on ready views.

func _ready() -> void:
    Game.attach(self)
    Game.begin_match()
