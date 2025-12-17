# BossSFX.gd
extends Node

# ربط عقد الصوت (يجب أن تتطابق مع الأسماء في مشهد BossSFX.tscn)
@onready var walk_sound = $WalkSound
@onready var axe_swing_sound = $AxeSwingSound
@onready var hit_received_sound = $HitReceivedSound
@onready var death_sound = $DeathSound

# ------------------------------------
# دوال تشغيل الأصوات
# ------------------------------------

func play_walk():
	# 🔊 لتكرار الصوت (يبدو واقعيًا)، نضمن أنه غير قيد التشغيل ثم نبدأ. 
	# الأهم: يجب أن يكون ملف الصوت (Stream) نفسه مضبوطاً على خاصية "Loop" في المحرر.
	if walk_sound and not walk_sound.is_playing():
		walk_sound.play()
		
func stop_walk():
	if walk_sound:
		walk_sound.stop()

func play_axe_swing():
	# صوت الضرب بالفأس/الهجوم
	if axe_swing_sound: axe_swing_sound.play()

func play_hit_received():
	# صوت تلقي الضرر/الإصابة
	if hit_received_sound: hit_received_sound.play()

func play_death():
	# صوت موت البوس
	if death_sound: death_sound.play()
