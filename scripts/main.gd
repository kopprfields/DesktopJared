extends Node2D

@onready var _MainWindow: Window = get_window();
@onready var character_sprite: AnimatedSprite2D = $Jared/AnimatedSprite2D;
@onready var sprite_size = character_sprite.sprite_frames.get_frame_texture(character_sprite.animation, character_sprite.frame).get_size();

var screen_width: int = DisplayServer.screen_get_usable_rect().size.x;
var screen_height: int = DisplayServer.screen_get_usable_rect().size.y;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().get_root().set_transparent_background(true);
	set_passthrough(character_sprite);

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	set_passthrough(character_sprite);
	if(Input.is_action_just_pressed("ui_cancel")):
		$Jared.reset();

func set_passthrough(sprite: AnimatedSprite2D):
	#Set window size
	_MainWindow.min_size = Vector2i(sprite_size.x,sprite_size.y);
	_MainWindow.size = _MainWindow.min_size;
	#Set sprite geometry
	var texture_center: Vector2 = sprite_size / 2; # Center
	var texture_corners: PackedVector2Array = [
		sprite.global_position + texture_center * Vector2(-1, -1), # Top left corner
		sprite.global_position + texture_center * Vector2(1, -1), # Top right corner
		sprite.global_position + texture_center * Vector2(1 , 1), # Bottom right corner
		sprite.global_position + texture_center * Vector2(-1 ,1) # Bottom left corner
	];
	DisplayServer.window_set_mouse_passthrough(texture_corners);
