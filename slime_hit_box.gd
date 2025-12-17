class_name SlimeHitBox
extends Area2D

signal hit_target(damage_amount, source_position)

@export var damage_amount := 10
@export var hit_cooldown := 0.2

var _can_hit := true

func _ready():
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	if not _can_hit:
		return

	if area is HurtBox:
		_can_hit = false
		emit_signal("hit_target", damage_amount, global_position)
		_start_cooldown()

func _start_cooldown():
	await get_tree().create_timer(hit_cooldown).timeout
	_can_hit = true
