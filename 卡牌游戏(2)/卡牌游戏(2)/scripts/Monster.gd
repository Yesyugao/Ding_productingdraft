extends Node2D

func _draw():
	# 一个简单的像素风格小怪
	# 身体
	draw_rect(Rect2(-25, -25, 50, 50), Color.DARK_GREEN)
	# 眼睛
	draw_rect(Rect2(-15, -15, 10, 10), Color.WHITE)
	draw_rect(Rect2(5, -15, 10, 10), Color.WHITE)
	draw_rect(Rect2(-12, -12, 4, 4), Color.BLACK)
	draw_rect(Rect2(8, -12, 4, 4), Color.BLACK)
	# 嘴巴
	draw_rect(Rect2(-10, 5, 20, 5), Color.BLACK) 