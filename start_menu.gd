# start_menu.gd
extends Control

# --- الثوابت والخصائص ---
@export var game_scene_path: String = "res://main.tscn"
# تأكد أن هذا المسار يطابق مكان ملف شاشة التحميل لديك
const LOADING_SCREEN_PATH = "res://atk_1/LoadingScreen.tscn"

# --- العقد ---
@onready var menu_background = $MenuBackground
@onready var player_anim: AnimatedSprite2D = menu_background.get_node_or_null("PlayerAnimation")
@onready var boss_anim: AnimatedSprite2D = menu_background.get_node_or_null("BossAnimation")

@onready var start_button: TextureButton = $VBoxContainer/Button
@onready var quit_button: TextureButton = $VBoxContainer/Button2 as TextureButton

# 💡 عقدة الموسيقى الجديدة 💡
@onready var menu_music_player: AudioStreamPlayer2D = $MenuMusicPlayer 


func _ready() -> void:
	get_tree().paused = false
	
	# 🔊 تشغيل موسيقى القائمة الرئيسية فور تحميل المشهد
	if menu_music_player and not menu_music_player.is_playing():
		menu_music_player.play()
	
	# تشغيل أنيميشن الخلفية
	if player_anim: player_anim.play("idle")
	if boss_anim: boss_anim.play("idle")
		
	# ربط الأزرار
	if start_button:
		start_button.pressed.connect(_on_StartGameButton_pressed)
	else:
		print("Error: Start Button not found")
		

# --- دالة الانتقال إلى اللعبة ---
func _on_StartGameButton_pressed() -> void:
	if game_scene_path == "":
		print("Error: Game scene path is empty!")
		return
		
	# 1. إيقاف الموسيقى لمنع استمرارها في مشهد التحميل أو اللعب
	if menu_music_player:
		menu_music_player.stop()
		
	# 2. نخبر المدير العام ما هو المشهد القادم
	# (يفترض أن لديك سكريبت GameManager يعمل في Project Settings أو كـ AutoLoad)
	if is_instance_valid(GameManager):
		GameManager.next_scene_path = game_scene_path
	else:
		print("Error: GameManager is not available. Cannot set next scene path.")
		return
	
	# 3. ننتقل إلى شاشة التحميل
	var error = get_tree().change_scene_to_file(LOADING_SCREEN_PATH)
	
	if error != OK:
		print("Error changing to loading screen. Check path: ", LOADING_SCREEN_PATH)

func _on_Quit_pressed() -> void:
	get_tree().quit()
