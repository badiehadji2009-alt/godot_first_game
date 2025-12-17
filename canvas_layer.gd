extends CanvasLayer

# ----------------------------------------------------
# 💡 المراجع المطلوبة: يجب ربط هذه العقد في المحرر
# ----------------------------------------------------
# ColorRect لتغطية الشاشة (يجب أن يكون اللون البني هو لون النهاية في الحركة)
@onready var color_rect: ColorRect = $ColorRect 
# حاوية النصوص (تم تعديل المسار هنا ليتوافق مع ما قدمته)
@onready var end_screen_container: Control = $CenterContainer
# مشغل الحركات الذي يحتوي على حركة "fade_to_brown"
@onready var animator: AnimationPlayer = $AnimationPlayer 
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var developer_label: Label = $CenterContainer/VBoxContainer/DeveloperLabel
@onready var co_developer_label: Label = $CenterContainer/VBoxContainer/CoDeveloperLabel
@onready var end_music_player = $EndMusicPlayer # 🛠️ جديد: AudioStreamPlayer لموسيقى شاشة النهاية (يجب أن تكون عقدة تحت CanvasLayer)

# ----------------------------------------------------
# ⚙️ أسماء المطورين
# ----------------------------------------------------
const DEVELOPER_NAME = "حاجي محمد عبد البديع"
const CO_DEVELOPER_NAME = "محمد جيميني"

func _ready():
	# 🛠️ تمت إضافة العقدة إلى مجموعة لتسهيل الوصول إليها من البوس
	add_to_group("game_ender")
	
	# إخفاء شاشة النهاية في البداية
	end_screen_container.hide()
	
	# إعداد النصوص
	title_label.text = " شكراً لك على تختيم لعبتنا!"
	developer_label.text = "بتطوير: " + DEVELOPER_NAME
	co_developer_label.text = "بمساعدة: " + CO_DEVELOPER_NAME
	
	# يجب أن يكون اللون الأولي لـ ColorRect شفافاً لكي لا يحجب اللعبة
	color_rect.color = Color(0, 0, 0, 0)
	
	# ربط إشارة انتهاء الحركة لوظيفة عرض الشاشة
	if is_instance_valid(animator):
		animator.animation_finished.connect(_on_fade_animation_finished)

# ----------------------------------------------------
# 🚀 بدء النهاية (تُستدعى عند موت البوس)
# ----------------------------------------------------
func start_game_end():
	print("GameEnder: تم استدعاء إنهاء اللعبة.")
	
	# 1. إيقاف اللعبة مؤقتاً
	# إذا كنت تريد توقيف جميع الحركات والميكانيكيات، استخدم
	# get_tree().paused = true
	
	# 🎵 جديد: تشغيل موسيقى النهاية
	if is_instance_valid(end_music_player):
		end_music_player.play()
	
	# 2. بدء التعتيم
	if is_instance_valid(animator):
		# 💡 يجب عليك إنشاء حركة باسم "fade_to_brown"
		animator.play("fade_to_brown") 
		print("GameEnder: بدء التعتيم إلى البني.")
	else:
		# خطة احتياطية: إظهار الشاشة فوراً
		print("GameEnder: لا يوجد AnimationPlayer. عرض فوري لشاشة النهاية.")
		_on_fade_animation_finished("fallback")

# ----------------------------------------------------
# 🎬 انتهاء التعتيم (إظهار الشاشة)
# ----------------------------------------------------
func _on_fade_animation_finished(anim_name: String):
	# نتحقق من أن الحركة انتهت (أو أنها خطة احتياطية)
	if anim_name == "fade_to_brown" or anim_name == "fallback":
		# 3. التأكد من أن التعتيم كاملاً (إذا لم يكن كاملاً في نهاية الحركة)
		# 🛠️ استخدام القيمة السداسية (Hex) للبني الغامق
		color_rect.color = Color("654321")
		
		# 4. إظهار النصوص بعد اكتمال التعتيم
		end_screen_container.show()
		
		# (اختياري) يمكنك إضافة حركة ثانية هنا لجعل النصوص تظهر بشكل تدريجي.
