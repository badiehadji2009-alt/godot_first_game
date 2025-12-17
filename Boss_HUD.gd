# ملف Boss_HUD.gd (مرفق بعقدة CanvasLayer)
extends CanvasLayer

# 💡 يتم البحث عن شريط التقدم عبر التسلسل الهرمي الجديد: BossContainer/BossHealthBar 💡
@onready var boss_health_bar = $BossContainer/BossHealthBar 

func _ready():
	# 1. التأكد من ظهور CanvasLayer دائماً
	set_deferred("visible", true) 
	
	# 2. البحث عن البوس لربط الإشارة
	# 💡 يجب أن يكون البوس مُضافاً لمجموعة "boss" 💡
	var boss = get_tree().get_first_node_in_group("boss")
	
	if boss:
		# 3. ربط الإشارة وتعيين القيم الأولية
		boss.connect("health_changed", Callable(self, "update_boss_health"))
		
		# 4. تعيين القيم الأولية إذا تم العثور على الشريط
		if is_instance_valid(boss_health_bar):
			boss_health_bar.max_value = boss.max_health 
			boss_health_bar.value = boss.current_health
		else:
			push_error("BossHealthBar Node not found. Check the @onready path!")
	else:
		push_error("Boss Node not found in 'boss' group!")


func update_boss_health(new_health: int, max_h: int):

	if is_instance_valid(boss_health_bar):
		boss_health_bar.max_value = max_h
		boss_health_bar.value = new_health
