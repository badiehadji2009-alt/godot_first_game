extends Node

# --- إعدادات ثابتة وموارد ---
const MUSHROOM_SCENE = preload("res://fungal_tank.tscn")
const SLIME_SCENE = preload("res://Slime.tscn")

const SPAWN_INTERVAL = 1.5
const WAVE_BREAK_TIME = 5.0
const ANNOUNCEMENT_DURATION = 3.0 # مدة عرض الإعلان

# 🛑 الأصوات الفردية (تم تحميلها مسبقاً في الكود)
const WAVE_ONE_VOICE = preload("res://iloveimg-resized (1)/bot enemey/FlyingForestEnemies_FREE/FlyingForestEnemies_FREE/Enemy3/Enemy3-Movement-In-Animation/الموجات اصوات/الموجة الا.wav")
const WAVE_TWO_VOICE = preload("res://iloveimg-resized (1)/bot enemey/FlyingForestEnemies_FREE/FlyingForestEnemies_FREE/Enemy3/Enemy3-Movement-In-Animation/الموجات اصوات/الموجة الث.wav")
const WAVE_THREE_VOICE = preload("res://iloveimg-resized (1)/bot enemey/FlyingForestEnemies_FREE/FlyingForestEnemies_FREE/Enemy3/Enemy3-Movement-In-Animation/الموجات اصوات/الموجة الأ.wav")
const WAVE_VOICES = [WAVE_ONE_VOICE, WAVE_TWO_VOICE, WAVE_THREE_VOICE]

var WAVES = [
	[{"type": MUSHROOM_SCENE, "count": 10}],
	[{"type": SLIME_SCENE, "count": 10}],
	[
		{"type": SLIME_SCENE, "count": 7},
		{"type": MUSHROOM_SCENE, "count": 7}
		]
]

# --- مراجع العقد (@onready) ---
@onready var enemy_container = $EnemyContainer
@onready var arena_area = $ArenaArea
@onready var player = get_parent().get_node("Player")
@onready var arena_camera: Camera2D = $ArenaCamera

@onready var slime_spawn_points = ($SpawnPoints/SlimeSpawnPoints as Node).get_children()
@onready var mushroom_spawn_points = ($SpawnPoints/MushroomSpawnPoints as Node).get_children()

@onready var wave_announcement_ui = $WaveAnnouncement
@onready var wave_title_label = $WaveAnnouncement/CenterContainer/VBoxContainer/WaveTitle
@onready var wave_composition_label = $WaveAnnouncement/CenterContainer/VBoxContainer/WaveComposition

# 🛑 مشغلان منفصلان
@onready var wave_audio_player = $WaveAudioPlayer # لـ SFX الإعلان الفردي
@onready var ost_player = $OstPlayer           # للأغنية الخلفية المستمرة

# 🆕 مرجع بوابة البوس (مطلوب لفتح الباب)
@onready var boss_gate = $"../BossGateArea"


# --- متغيرات الحالة ---
var current_wave_index = 0
var current_enemy_batch_index = 0
var enemies_left_to_spawn_in_batch = 0
var spawning_active = false
var fight_started = false
var arena_bounds = Rect2()
var active_enemies: Array[Node2D] = []

# --- المؤقتات ---
@onready var spawn_timer = Timer.new()
@onready var break_timer = Timer.new()

func _ready():
	add_child(spawn_timer)
	add_child(break_timer)
	
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	break_timer.timeout.connect(_on_break_timer_timeout)
	
	arena_area.body_entered.connect(_on_ArenaArea_body_entered)

	# ===============================================
	# 🚨 DEBUG: وظيفة لفتح الباب فوراً للاختبار
	# ⚠️ قم بإزالة هذه الأسطر عند الانتهاء من الاختبار.
	# ===============================================
	if is_instance_valid(boss_gate) and boss_gate.has_method("open_gate"):
		boss_gate.open_gate()
		print("WaveManager: [DEBUG] تم فتح بوابة البوس فوراً لغرض الاختبار.")
	else:
		print("WaveManager: [DEBUG] المرجع 'boss_gate' غير جاهز أو غير موجود بعد.")
	# ===============================================


# ===============================================
# 🚀 منطق التفعيل والقفل
# ===============================================

func _on_ArenaArea_body_entered(body: Node2D):
	if body == player and not fight_started:
		fight_started = true
		
		var collision_shape = arena_area.get_node("CollisionShape2D")
		var shape = collision_shape.shape as RectangleShape2D
		var arena_center = arena_area.global_transform.origin
		var size = shape.size
		var half_size = size / 2.0
		arena_bounds = Rect2(arena_center - half_size, size)
		
		lock_player_and_camera()
		arena_area.set_deferred("monitoring", false)
		
		# إذا كان الباب مفتوحاً في _ready، فقد لا تحتاج لبدء الموجة فوراً إلا إذا أردت ذلك
		if current_wave_index == 0:
			start_next_wave()

func lock_player_and_camera():
	player.call("set_movement_limit", arena_bounds)
	var player_camera = player.find_child("Camera2D", true, false)
	
	if player_camera and is_instance_valid(arena_camera):
		player_camera.enabled = false
		
		arena_camera.global_position = arena_bounds.get_center()
		arena_camera.drag_horizontal_enabled = false
		arena_camera.drag_vertical_enabled = false
		arena_camera.enabled = true
		arena_camera.make_current()
		
	var player_sfx = player.find_child("PlayerSFX")
	if player_sfx and player_sfx.has_method("reset_volume"):
		player_sfx.call_deferred("reset_volume")

func unlock_player_and_camera():
	
	# 🛑 إيقاف الأغنية الخلفية عند انتهاء جميع الموجات
	if ost_player and ost_player.is_playing():
		ost_player.stop()
	
	player.call("set_movement_limit", Rect2())
	var player_camera = player.find_child("Camera2D", true, false)
	
	if player_camera and is_instance_valid(arena_camera):
		arena_camera.enabled = false
		player_camera.enabled = true
		player_camera.make_current()
		player_camera.drag_horizontal_enabled = true
		player_camera.drag_vertical_enabled = true
		player_camera.limit_left = -10000
		player_camera.limit_right = 10000
		player_camera.limit_top = -10000
		player_camera.limit_bottom = 10000
		
	fight_started = false


# ===============================================
# 🌊 منطق الموجات والتوليد والإعلانات
# ===============================================

func get_enemy_name(enemy_scene):
	if enemy_scene == MUSHROOM_SCENE:
		return "الفطر (Mushrooms)"
	if enemy_scene == SLIME_SCENE:
		return "الوحل (Slimes)"
	return "أعداء"
	
func get_wave_composition(wave_index: int) -> String:
	var batch = WAVES[wave_index]
	var enemy_names = []
	
	for item in batch:
		var name = get_enemy_name(item.type)
		if not enemy_names.has(name):
			enemy_names.append(name)
			
	if enemy_names.size() == 1:
		return "النوع الوحيد: " + enemy_names[0]
	elif enemy_names.size() > 1:
		return "مزيج من: " + " و ".join(enemy_names)
	return "أعداء متنوعون"

# 🛑 دالة عرض الإعلان وتشغيل الصوت
func display_wave_announcement(wave_index: int):
	var wave_number = wave_index + 1
	
	# 1. تحديث النصوص
	wave_title_label.text = "الموجة " + str(wave_number)
	wave_composition_label.text = get_wave_composition(wave_index)
	
	# 2. عرض الواجهة وتشغيل الصوت الفردي
	wave_announcement_ui.show()
	
	# 🛑 تشغيل الصوت الفردي للموجة (باستخدام المسارات المُحمّلة)
	if wave_index < WAVE_VOICES.size():
		var target_sound = WAVE_VOICES[wave_index]
		
		if wave_audio_player and target_sound:
			wave_audio_player.stream = target_sound # تعيين الملف الصوتي
			wave_audio_player.play()        
	
	# 3. إخفاء الواجهة بعد مدة زمنية
	var hide_timer = Timer.new()
	add_child(hide_timer)
	hide_timer.wait_time = ANNOUNCEMENT_DURATION
	hide_timer.one_shot = true
	hide_timer.timeout.connect(func():
		wave_announcement_ui.hide()
		hide_timer.queue_free()
		
		# 🛑 إعادة تشغيل OST بعد انتهاء الإعلان مباشرة (يعتمد على التعيين اليدوي)
		if ost_player and ost_player.stream:
			ost_player.play()

		start_spawning_batch()
	)
	hide_timer.start()


func start_next_wave():
	if current_wave_index >= WAVES.size():
		unlock_player_and_camera()
		# 💡 منطق فتح الباب الحقيقي (للتطبيق بعد انتهاء الموجات)
		if is_instance_valid(boss_gate) and boss_gate.has_method("open_gate"):
			boss_gate.open_gate()
		return
		
	current_enemy_batch_index = 0
	
	display_wave_announcement(current_wave_index)


func start_spawning_batch():
	if current_enemy_batch_index >= WAVES[current_wave_index].size():
		check_enemies_in_scene()
		return

	var batch_data = WAVES[current_wave_index][current_enemy_batch_index]
	enemies_left_to_spawn_in_batch = batch_data.count
	spawning_active = true

	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.start()

func _on_spawn_timer_timeout():
	if not spawning_active:
		return

	if enemies_left_to_spawn_in_batch > 0:
		spawn_enemy()
		enemies_left_to_spawn_in_batch -= 1
		
		if enemies_left_to_spawn_in_batch <= 0:
			spawn_timer.stop()
			spawning_active = false
			
			current_enemy_batch_index += 1
			start_spawning_batch()

func spawn_enemy():
	var batch_data = WAVES[current_wave_index][current_enemy_batch_index]
	var EnemyScene = batch_data.type
	
	if not EnemyScene: return
		
	var new_enemy = EnemyScene.instantiate()
	
	var spawn_points_array = []
	
	if EnemyScene == SLIME_SCENE:
		spawn_points_array = slime_spawn_points
	elif EnemyScene == MUSHROOM_SCENE:
		spawn_points_array = mushroom_spawn_points
	
	if spawn_points_array.is_empty(): return
		
	var random_spawn_point = spawn_points_array[randi() % spawn_points_array.size()] as Node2D
	
	new_enemy.global_position = random_spawn_point.global_position
	
	if new_enemy.has_signal("died"):
		new_enemy.died.connect(_on_enemy_died.bind(new_enemy))
		active_enemies.append(new_enemy)
	
	enemy_container.add_child(new_enemy)
	
func _on_enemy_died(enemy_node: Node2D):
	if active_enemies.has(enemy_node):
		active_enemies.erase(enemy_node)
	
	if not spawning_active and current_enemy_batch_index >= WAVES[current_wave_index].size():
		check_enemies_in_scene()


# ===============================================
# ⏳ منطق التوقف بين الموجات
# ===============================================

func check_enemies_in_scene():
	
	if active_enemies.size() > 0:
		if break_timer.is_stopped():
			break_timer.start(0.5)
		return
		
	
	# 🛑 إيقاف OST عند انتهاء الموجة
	if ost_player and ost_player.is_playing():
		ost_player.stop()

	current_wave_index += 1
	
	if current_wave_index < WAVES.size():
		break_timer.start(WAVE_BREAK_TIME)
	else:
		start_next_wave()

func _on_break_timer_timeout():
	break_timer.stop()
	
	if active_enemies.size() > 0:
		check_enemies_in_scene()
	else:
		start_next_wave()
