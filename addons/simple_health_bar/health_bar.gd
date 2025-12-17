extends ProgressBar

@onready var timer := $Timer
@onready var damageBar := $DamageBar 

var _current_health: float

# ----------------------------------------------------------------------
# 1. دالة الإعداد الأولية
# ----------------------------------------------------------------------
func init_bar(_max_health:float, _initial_health: float) -> void:
	# استخدام float لضمان التوافق
	max_value = _max_health
	
	_current_health = _initial_health
	value = _current_health
	
	damageBar.max_value = _max_health
	damageBar.value = _current_health
	
# ----------------------------------------------------------------------
# 2. دالة تحديث الشريط (تقبل float وتستخدمها للتأثير)
# ----------------------------------------------------------------------
# 💡 قمنا بتغيير نوع new_health إلى float ليتوافق مع init_bar و _current_health
func update_bar(new_health:float) -> void: 
	
	var prev_health: float = _current_health
	
	_current_health = min(max_value, new_health)
	
	# تحديث شريط التقدم الرئيسي فوراً
	value = _current_health
	
	# منطق تأخير الضرر (كما في الكود الأصلي)
	if _current_health < prev_health:
		timer.start()
	else:
		damageBar.value = _current_health
	
func _on_timer_timeout() -> void:
	damageBar.value = _current_health
