# HitBox.gd (المصحح والمدعوم للكومبو)
class_name HitBox
extends Area2D

@export var damage_amount: int = 15
var is_active: bool = false 
# مصفوفة لتتبع نسخ الأعداء (HurtBox) التي تم ضربها في تفعيل HitBox الحالي
var targets_hit_in_current_activation: Array[HurtBox] = [] 

func _ready():
	# ربط دالة _on_area_entered مباشرة لاكتشاف HurtBox
	area_entered.connect(_on_area_entered)
	monitoring = false 

func _on_area_entered(area: Area2D):
	# 1. التحقق من أن المنطقة الملموسة هي HurtBox وأن HitBox فعال حالياً
	if area is HurtBox and is_active: 
		
		# 2. التحقق من أن هذا العدو لم يضرب بعد في نفس تفعيل الهجوم الحالي
		if not targets_hit_in_current_activation.has(area):
			
			# 3. تسجيل الضربة: إضافة العدو للقائمة لمنع تكرار الضربة في الإطار نفسه
			targets_hit_in_current_activation.append(area)
			
			# 4. إرسال الضرر مباشرة: استدعاء دالة receive_hit على نسخة HurtBox الملموسة فقط
			area.receive_hit(damage_amount, global_position)
			
			# 💡 لا يتم تعطيل HitBox هنا. سكريبت اللاعب هو من يتحكم في ذلك 
			# للسماح بضرب أعداء آخرين أو إعداد الضربة الثانية للكومبو.


# تفعيل الـ HitBox عند بدء الهجوم
func activate():
	is_active = true
	monitoring = true
	# تفريغ القائمة عند كل تفعيل جديد لتبدأ الضربة نظيفة
	targets_hit_in_current_activation.clear()

# تعطيل الـ HitBox بعد انتهاء الضربة (يتم استدعاؤها من سكريبت اللاعب)
func deactivate():
	is_active = false
	monitoring = false
	# لا نفرغ القائمة هنا، نتركها للتفريغ في الدالة activate() التالية.
