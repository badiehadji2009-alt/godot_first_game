# LoadingScreen.gd
extends Control

@onready var loading_label = $LoadingLabel

var target_path: String = ""
var dot_timer: float = 0.0
var load_status: int = 0
var progress: Array = [] # مصفوفة فارغة مطلوبة لدالة get_status

func _ready() -> void:
	# 1. جلب المسار من السكربت العام
	target_path = GameManager.next_scene_path
	
	if target_path == "":
		print("Error: No scene path set in GameManager!")
		return
		
	# 2. بدء التحميل في الخلفية
	var error = ResourceLoader.load_threaded_request(target_path)
	if error != OK:
		print("Error starting load: ", error)

func _process(delta: float) -> void:
	# --- منطق حركة النقاط (Loading...) ---
	dot_timer += delta
	var dot_count = int(dot_timer * 3.0) % 4
	if loading_label:
		loading_label.text = "Loading" + ".".repeat(dot_count)
	
	# --- منطق مراقبة التحميل ---
	if target_path == "":
		return
		
	load_status = ResourceLoader.load_threaded_get_status(target_path, progress)
	
	match load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# التحميل جارٍ... لا نفعل شيئًا
			pass
			
		ResourceLoader.THREAD_LOAD_LOADED:
			# انتهى التحميل! نجلب المشهد وننتقل إليه
			var packed_scene = ResourceLoader.load_threaded_get(target_path)
			get_tree().change_scene_to_packed(packed_scene)
			
		ResourceLoader.THREAD_LOAD_FAILED:
			print("Loading failed!")
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("Invalid resource!")
