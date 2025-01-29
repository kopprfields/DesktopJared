extends Node2D

enum STATES {
	IDLE,
	GRABBED,
	CLICK_AWAIT, #Required to differenciate a short click vs click & hold
	CLICKED,
	DOUBLE_CLICKED,
	FALLING,
	WALKING,
	SHAKEN,
	DOWN
}

signal state_change;

@onready var _MainWindow: Window = get_window();
@onready var character_sprite: AnimatedSprite2D = $AnimatedSprite2D;
@onready var sprite_size = character_sprite.sprite_frames.get_frame_texture(character_sprite.animation, character_sprite.frame).get_size();
@onready var taskbar_pos: int = DisplayServer.screen_get_usable_rect().size.y - sprite_size.y;

const walk_speed: Array[int] = [100, 130]; #Window goes slower when walking right. No idea why and I'm too tired to figure it out.
const long_click_threshold: float = 0.15;
const shake_angle_threshold: int = 120;
const shake_number_threshold: int = 2;
const shake_timeout: float = 0.5;

var screen_width: int = DisplayServer.screen_get_usable_rect().size.x;
var screen_height: int = DisplayServer.screen_get_usable_rect().size.y;
var previousState: int = STATES.IDLE;
var currentState: int = STATES.IDLE;
var direction: int = 1;
var grabbed_positions: Array[Vector2i] = [];
var shake_count: int = 0;
var clicks_count: int = 0;
var fall_vector: Vector2 = Vector2.ZERO;
var high_fall_threshold: int =screen_height*9/5;
var fast_fall_threshold: int = 2*high_fall_threshold;

func _ready() -> void:
	#initialize position
	_MainWindow.position = Vector2i(screen_width/2, taskbar_pos);
	#initialize animation
	$AnimatedSprite2D.play("idle");

func _process(delta: float) -> void:
	var mouse_position = DisplayServer.mouse_get_position();
	
	#Chose state through event
	if(Input.is_action_just_pressed("left_click")):
		if(currentState != STATES.FALLING):
			clicks_count+=1;
			currentState = STATES.CLICK_AWAIT;
			#At timer end, check if left click still pressed => grab, otherwise => simple click
			$Timer.stop();
			$Timer.wait_time = long_click_threshold;
			$Timer.start();
		else: #if falling state, get straight back to grabbed
			currentState = STATES.GRABBED;
			fall_vector = Vector2.ZERO;
	if(Input.is_action_just_released("left_click")):
		if(currentState == STATES.GRABBED || currentState == STATES.SHAKEN):
			if(grabbed_positions.size() >= 2):
				var speed_intensity = (grabbed_positions[1] - grabbed_positions[0]).length()*20;
				var direction_vector: Vector2 = grabbed_positions[1] - grabbed_positions[0];
				direction_vector = direction_vector.normalized()
				fall_vector = direction_vector*speed_intensity;
			currentState = STATES.FALLING;
			grabbed_positions.clear();
			$Timer.stop();
	if(currentState == STATES.FALLING && _MainWindow.position.y >= taskbar_pos):
		if(abs(fall_vector.length()) > fast_fall_threshold || abs(fall_vector.y) > high_fall_threshold):
			currentState = STATES.DOWN;
		else:
			currentState = STATES.IDLE;
		$Timer.stop();
		$Timer.wait_time = randi_range(2, 4);
		$Timer.start();
		_MainWindow.position.y = taskbar_pos;
		fall_vector = Vector2.ZERO;
	
	if(previousState != currentState):
		state_change.emit();
	
	#State machine behavior
	match currentState:
		STATES.IDLE:
			$AnimatedSprite2D.play("idle");
		STATES.CLICKED:
			$AnimatedSprite2D.play("clicked");
		STATES.DOUBLE_CLICKED:
			$AnimatedSprite2D.play("double_clicked");
		STATES.DOWN:
			$AnimatedSprite2D.play("down");
		STATES.GRABBED:
			$AnimatedSprite2D.play("grabbed");
			_MainWindow.position = Vector2i(clamp_on_screen_width(mouse_position.x-sprite_size.x/2, sprite_size.x), clamp_on_screen_height(mouse_position.y-sprite_size.y/2)); 
			get_mouse_position();
			detect_jerk();
		STATES.SHAKEN:
			$AnimatedSprite2D.play("shaken");
			_MainWindow.position = Vector2i(clamp_on_screen_width(mouse_position.x-sprite_size.x/2, sprite_size.x), clamp_on_screen_height(mouse_position.y-sprite_size.y/2));
			get_mouse_position();
			detect_jerk(); 
		STATES.FALLING:
			$AnimatedSprite2D.play("falling");
			fall_vector.y -= 50;
			_MainWindow.position.x = clamp_on_screen_width(_MainWindow.position.x - fall_vector.x*delta, sprite_size.x); 
			_MainWindow.position.y = clamp_on_screen_height(_MainWindow.position.y - fall_vector.y*delta);
			if(_MainWindow.position.x >= screen_width - sprite_size.x || _MainWindow.position.x <= 0):
				fall_vector.x = -fall_vector.x;
			if(_MainWindow.position.y <= 0):
				if(fall_vector.y == 0):
					fall_vector.y -= 50;
				else:
					fall_vector.y = -fall_vector.y;
		STATES.WALKING:
			$AnimatedSprite2D.play("walking");
			var speed = walk_speed[1] if direction == 1 else walk_speed[0];
			_MainWindow.position.x = clamp_on_screen_width(_MainWindow.position.x+direction*speed*delta, sprite_size.x);
			turn_around(_MainWindow.position.x);

#Limit playable zone
func clamp_on_screen_width(pos, sprite_width):
	return clampi(pos, 0, screen_width - sprite_width);
func clamp_on_screen_height(pos):
	return clampi(pos, 0, taskbar_pos);

func turn_around(x_position: int):
	if(x_position >= screen_width - sprite_size.x || x_position <= 0):
		direction = -direction;

func get_mouse_position():
	grabbed_positions.insert(0, DisplayServer.mouse_get_position());
	if(grabbed_positions.size() > 10):
		grabbed_positions.resize(10)

func detect_jerk():
	if(grabbed_positions.size() >= 3):
		var speed1 = Vector2(grabbed_positions[1].x - grabbed_positions[0].x, grabbed_positions[1].y - grabbed_positions[0].y);
		var speed2 = Vector2(grabbed_positions[2].x - grabbed_positions[1].x, grabbed_positions[2].y - grabbed_positions[1].y);
		var angle = abs(rad_to_deg(speed1.angle_to(speed2)));
		if(angle > shake_angle_threshold):
			if(shake_count == 0):
				$TimerShake.stop();
				$TimerShake.wait_time = shake_timeout;
				$TimerShake.start();
			shake_count += 1;

func reset():
	currentState = STATES.IDLE;
	$Timer.stop();
	$Timer.wait_time = randi_range(3, 5);
	$Timer.start();
	_MainWindow.position = Vector2i(screen_width/2, taskbar_pos);
	grabbed_positions.clear()
	shake_count = 0;
	fall_vector = Vector2.ZERO;

#Chose state through timer timeout
func _on_timer_timeout() -> void:
	$Timer.stop();
	match currentState:
		STATES.IDLE:
			var direction_multiplier = [-1, 1];
			direction = direction_multiplier[randi_range(0, 1)];
			currentState = STATES.WALKING;
			$Timer.wait_time = randi_range(2, 4);
			$Timer.start();
		STATES.WALKING:
			currentState = STATES.IDLE;
			$Timer.wait_time = randi_range(3, 5);
			$Timer.start();
		STATES.DOWN:
			currentState = STATES.IDLE;
			$Timer.wait_time = randi_range(3, 5);
			$Timer.start();
		STATES.CLICK_AWAIT:
			if(Input.is_action_pressed("left_click")):
				currentState = STATES.GRABBED;
				clicks_count = 0;
			else:
				if(clicks_count == 1):
					currentState = STATES.CLICKED;
				else:
					currentState = STATES.DOUBLE_CLICKED;
				$Timer.wait_time = 1; #change for the animation duration
				$Timer.start();
				clicks_count = 0;
		STATES.CLICKED:
			currentState = STATES.IDLE;
			$Timer.wait_time = randi_range(3, 5);
			$Timer.start();
		STATES.DOUBLE_CLICKED:
			currentState = STATES.IDLE;
			$Timer.wait_time = randi_range(3, 5);
			$Timer.start()
		STATES.SHAKEN:
			if(Input.is_action_pressed("left_click")):
				currentState = STATES.GRABBED;
			else:
				currentState = STATES.FALLING;

func _on_timer_shake_timeout() -> void:
	if(shake_count > shake_number_threshold && Input.is_action_pressed("left_click")):
		currentState = STATES.SHAKEN;
		$Timer.stop();
		$Timer.wait_time = 2;
		$Timer.start();
	shake_count = 0;

#If code needs to be executed after a state change, example spawning a text message
func _on_state_change() -> void:
	previousState = currentState;
	$StateLabel.text = STATES.keys()[currentState];
