extends CanvasLayer

# 💡 يتم استخدام @onready للوصول إلى HealthBar مباشرة عبر مسار العقد
# يجب التأكد أن المسار صحيح (HUD -> HealthGroup -> HealthBar)
@onready var player_health_bar = $HealthGroup/HealthBar

var player_node: CharacterBody2D
const MARGIN_X: float = 32.0 
const MARGIN_Y: float = 32.0 

func _ready():
	# 1. الوصول إلى اللاعب (الأب هو الكاميرا، والجد هو اللاعب)
	player_node = get_parent()
	
	var health_group = get_node_or_null("HealthGroup")
	
	if not is_instance_valid(player_node) or not player_node is CharacterBody2D:
		push_error("HUD Error: Player node not found or not a CharacterBody2D. Check parent path (get_parent().get_parent()).")
		return
		
	if not is_instance_valid(player_health_bar):
		push_error("HUD Error: HealthBar node not found. Check the @onready path ($HealthGroup/HealthBar).")
		return

	# 2. تثبيت الموضع في الزاوية العلوية اليسرى
	if health_group:
		health_group.set_anchors_preset(Control.PRESET_TOP_LEFT)
		health_group.offset_left = MARGIN_X
		health_group.offset_top = MARGIN_Y
	
	# 3. ربط الإشارة وتعيين القيم الأولية
	if player_node.has_signal("health_changed"):
		
		# 💡 يتم الربط الآن بالدالة الجديدة في HUD: _update_player_health
		player_node.health_changed.connect(_update_player_health)
		
		# 4. تعيين القيم الأولية لملء الشريط عند بدء اللعب
		player_health_bar.max_value = player_node.MAX_HEALTH 
		player_health_bar.value = player_node.current_health
		
		# 💡 يجب استدعاء init_bar في HealthBar.gd إذا كانت موجودة
		if player_health_bar.has_method("init_bar"):
			player_health_bar.init_bar(player_node.MAX_HEALTH, player_node.current_health)
		
		print("HUD Debug: Player Health Bar Initialized and Signal Connected.")
	else:
		push_error("HUD Error: Player node does not have 'health_changed' signal defined.")


# ----------------------------------------------------
## 🔄 دالة التحديث (تعمل كوسيط لـ HealthBar.gd)
# ----------------------------------------------------
# 💡 هذه الدالة بسيطة وتقوم فقط بتمرير البيانات إلى الشريط (HealthBar.gd)

func _update_player_health(new_health: float, max_h: float):

	if is_instance_valid(player_health_bar):
		# 💡 نمرر البيانات إلى دالة التحديث في HealthBar.gd
		if player_health_bar.has_method("update_bar"):
			player_health_bar.update_bar(new_health)
		else:
			# إذا لم تكن update_bar موجودة، نقوم بالتحديث المباشر لشريط التقدم
			player_health_bar.max_value = max_h
			player_health_bar.value = new_health
