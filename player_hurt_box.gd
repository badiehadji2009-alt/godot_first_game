# ملف HurtBox.gd
extends Area2D

# إشارة يتم إطلاقها عند تلقي ضربة
# body: الكائن الذي سبب الضربة (عادة هو HitBox)
# damage_amount: قيمة الضرر
signal hit_received(damage_amount) 

# يجب أن يتم تعطيل الـ HurtBox عند موت الكائن أو أثناء الدودج
# monitorable: يُستخدم للسماح للعقدة بالكشف عن اصطدام الـ HitBox بها
# monitoring: يُستخدم للكشف عن اصطدام HurtBox بأشياء أخرى (ليس ضرورياً هنا)

# دالة تستدعيها عقدة HitBox عند الاصطدام
func get_hit(damage: int):
	if monitorable: # للتأكد من أن الكائن غير محصن
		# إطلاق الإشارة نحو العقدة الأم (اللاعب أو البوس)
		emit_signal("hit_received", damage)

# دالة للحصانة
func set_invulnerable(invulnerable: bool):
	monitorable = not invulnerable
