# HurtBox.gd (المصحح)
class_name HurtBox
extends Area2D

# إشارة يتم إطلاقها عند تلقي ضربة إلى العقدة الأم (الوحش)
signal hit_received(damage_amount, source_position)

func _ready():
	# إلغاء أي منطق ربط لإشارات area_entered
	monitorable = true # يمكن للهجوم اكتشاف هذه المنطقة
	pass


# 💡 الدالة الرئيسية: تستدعى مباشرة من سكريبت HitBox.gd
func receive_hit(damage: int, source_position: Vector2):
	# التحقق من حالة المناعة قبل إطلاق الإشارة
	if monitorable:
		# إطلاق الإشارة إلى العقدة الأم (الوحش) لتنفيذ منطق take_damage
		emit_signal("hit_received", damage, source_position)


# دالة للحصانة (تعطيل/تفعيل الاستقبال)
# يتم استدعاؤها من سكريبت الأب (fungal_tank.gd أو slime.gd)
func set_invulnerable(invulnerable: bool):
	# استخدام set_deferred لتجنب مشاكل الفيزياء/الترتيب
	set_deferred("monitorable", not invulnerable)
