extends Node2D
## Sandbox สำหรับทดสอบ InkArcher
## ลองเล่น: F6 หรือรัน scene นี้ตรง ๆ
## ควบคุม: เดิน WASD · ฟัน J / คลิกซ้าย · กลิ้งหลบ Space · Parry F / คลิกขวา (สะท้อนลูกธนู)

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	if player != null and camera != null:
		camera.position = player.position


func _physics_process(_delta: float) -> void:
	if player != null and camera != null:
		camera.position = camera.position.lerp(player.position, 0.1)
