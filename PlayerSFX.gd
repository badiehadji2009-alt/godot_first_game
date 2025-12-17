# PlayerSFX.gd

extends Node

# ربط عقد الصوت
@onready var jump_sound = $JumpSound
@onready var dodge_sound = $DodgeSound
@onready var attack_sound_1 = $AttackSound1 # صوت الهجوم 1
@onready var attack_sound_2 = $AttackSound2 # صوت الهجوم 2
@onready var hurt_sound = $HurtSound

# ------------------------------------
# دوال تشغيل الأصوات
# ------------------------------------

func play_jump():
	if jump_sound: jump_sound.play()

func play_dodge():
	if dodge_sound: dodge_sound.play()

func play_hurt():
	if hurt_sound: hurt_sound.play()

func play_attack(attack_number: int):
	match attack_number:
		1:
			if attack_sound_1: attack_sound_1.play()
		2:
			if attack_sound_2: attack_sound_2.play()
		_:
			pass

# 🛑 الدالة الجديدة: إعادة ضبط مستوى الصوت بعد تبديل الكاميرا
func reset_volume():
	# التأكد من أن جميع الأصوات مضبوطة على 0 dB (المستوى الافتراضي)
	if jump_sound: jump_sound.volume_db = 0.0
	if dodge_sound: dodge_sound.volume_db = 0.0
	if attack_sound_1: attack_sound_1.volume_db = 0.0
	if attack_sound_2: attack_sound_2.volume_db = 0.0
	if hurt_sound: hurt_sound.volume_db = 0.0
	print("DEBUG: تم إعادة ضبط مستوى صوت اللاعب إلى 0 dB.")
