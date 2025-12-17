

extends CanvasLayer

# --- 🛠️ قسم تعريفات الأزرار باستخدام $ (تأكد من مطابقة الأسماء في شجرة العقد) ---

@onready var left_button    = $Control/MovementGroup/LeftButton    # زر الحركة لليسار
@onready var right_button   = $Control/MovementGroup/RightButton  # زر الحركة لليمين
@onready var attack_button  = $Control/Control/AttackButton # زر الهجوم (سيف)
@onready var dodge_button   = $Control/Control/DodgeButton   # زر الدودج (فوق الهجوم)
@onready var jump_button    = $Control/Control/JumpButton   # زر القفز (يسار الهجوم)

# --- ⚙️ أسماء الـ Actions (يجب أن تطابق الـ Input Map) ---
const ACTION_LEFT   = "ui_left"
const ACTION_RIGHT  = "ui_right"
const ACTION_ATTACK = "attack"
const ACTION_DODGE  = "dodge"
const ACTION_JUMP   = "jump"

# --- 🎨 إعدادات المظهر ---
const NORMAL_OPACITY = 0.5  # الشفافية في الحالة العادية
const PRESSED_OPACITY = 1.0 # الشفافية عند الضغط
const TWEEN_SPEED = 0.1     # سرعة الأنميشن

func _ready():
	# ربط الأزرار المعرفة بـ $ بالوظائف
	var buttons = [left_button, right_button, attack_button, dodge_button, jump_button]
	
	for btn in buttons:
		if is_instance_valid(btn) and btn is TouchScreenButton:
			_setup_button(btn)
		else:
			push_warning("MobileControls: أحد الأزرار غير موجود، تأكد من مطابقة الأسماء بعد علامة $")

func _setup_button(btn: TouchScreenButton):
	# ضبط الشفافية الأولية فقط (بدون تغيير الـ Scale للحفاظ على حجمك اليدوي)
	btn.self_modulate.a = NORMAL_OPACITY
	
	# ربط الإشارات
	btn.pressed.connect(_on_pressed.bind(btn))
	btn.released.connect(_on_released.bind(btn))

# --- ✨ تأثيرات بصرية عند الضغط (شفافية فقط) ---

func _on_pressed(btn: TouchScreenButton):
	var tween = create_tween()
	# تغيير الشفافية لتصبح أوضح عند الضغط
	tween.tween_property(btn, "self_modulate:a", PRESSED_OPACITY, TWEEN_SPEED)

func _on_released(btn: TouchScreenButton):
	var tween = create_tween()
	# العودة للشفافية الأصلية عند ترك الزر
	tween.tween_property(btn, "self_modulate:a", NORMAL_OPACITY, TWEEN_SPEED)
