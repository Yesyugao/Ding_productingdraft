extends Control

class_name Card

# 卡牌拖拽相关信号
signal card_dragged(card)
signal card_dropped(card)
signal card_hovered(card)
signal card_unhovered(card)
signal card_drag_cancelled(card)  # 新增：拖拽取消信号

# 使用setter来确保当card_data被赋值时，卡牌的显示会自动更新
@export var card_data: CardData:
	set(new_data):
		card_data = new_data
		if is_node_ready():
			update_display()

# 节点引用
@onready var name_label: Label = $CardFace/Name
@onready var description_label: Label = $CardFace/Description
@onready var cost_label: Label = $CardFace/Cost
@onready var art_texture: TextureRect = $CardFace/Art
@onready var background_panel: Panel = $CardFace/Background
@onready var glow_effect: ColorRect = $CardFace/GlowEffect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 动画和交互状态
var is_dragging := false
var is_hovering := false
var drag_offset: Vector2
var original_scale: Vector2 = Vector2.ONE
var original_z_index: int = 0

# 视觉效果常量
const HOVER_SCALE = Vector2(1.1, 1.1)
const DRAG_SCALE = Vector2(1.15, 1.15)
const HOVER_Z_INDEX = 10
const DRAG_Z_INDEX = 20

func _ready():
	# 记录原始状态
	original_scale = scale
	original_z_index = z_index
	
	# 初始化发光效果
	if glow_effect:
		glow_effect.color = Color(0.3, 0.6, 1, 0)
		glow_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 连接鼠标事件
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# 初始化显示
	if card_data:
		update_display()

func update_display():
	if not card_data:
		return
		
	if name_label:
		name_label.text = card_data.card_name
	if description_label:
		description_label.text = card_data.description
	if cost_label:
		cost_label.text = str(card_data.cost)
		cost_label.visible = card_data.cost > 0
	
	# 根据卡牌类型设置颜色
	if background_panel:
		var card_color = get_card_type_color()
		background_panel.modulate = card_color
	
	# 设置卡牌图标
	if art_texture and card_data.texture:
		art_texture.texture = card_data.texture

func get_card_type_color() -> Color:
	if not card_data:
		return Color.WHITE
		
	match card_data.card_type:
		CardData.CardType.ROCK:
			return Color(0.8, 0.5, 0.3)  # 棕色
		CardData.CardType.PAPER:
			return Color(0.9, 0.9, 0.85) # 米白色
		CardData.CardType.SCISSORS:
			return Color(0.7, 0.7, 0.8)  # 银灰色
		CardData.CardType.BLANK:
			return Color(0.6, 0.9, 0.6)  # 浅绿色
		CardData.CardType.BLACK:
			return Color(0.3, 0.2, 0.4)  # 深紫色
		_:
			return Color.WHITE

func _on_mouse_entered():
	if not is_dragging:
		is_hovering = true
		emit_signal("card_hovered", self)
		# 简单的悬停效果
		scale = HOVER_SCALE
		z_index = HOVER_Z_INDEX
		if glow_effect:
			glow_effect.color.a = 0.3

func _on_mouse_exited():
	if not is_dragging:
		is_hovering = false
		emit_signal("card_unhovered", self)
		# 恢复原始状态
		scale = original_scale
		z_index = original_z_index
		if glow_effect:
			glow_effect.color.a = 0.0

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# 开始拖拽
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			
			# 拖拽时的视觉效果
			scale = DRAG_SCALE
			z_index = DRAG_Z_INDEX
			if glow_effect:
				glow_effect.color.a = 0.5
			
			emit_signal("card_dragged", self)
		else:
			# 结束拖拽
			if is_dragging:
				is_dragging = false
				
				# 检查是否在有效的投放区域
				var valid_drop = false
				
				# 简单检查：如果鼠标在屏幕中央区域，认为是有效投放区域
				var screen_size = get_viewport().get_visible_rect().size
				var center_area = Rect2(
					screen_size.x * 0.25, 
					screen_size.y * 0.25,
					screen_size.x * 0.5, 
					screen_size.y * 0.5
				)
				
				if center_area.has_point(get_global_mouse_position()):
					valid_drop = true
				
				if not valid_drop:
					# 区域外松开，发出取消信号
					print("卡牌投放到无效区域，取消拖拽")
					reset_visual_state()
					emit_signal("card_drag_cancelled", self)
				else:
					# 有效投放
					reset_visual_state()
					emit_signal("card_dropped", self)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and is_dragging:
		# 右键取消拖拽
		print("右键取消拖拽")
		is_dragging = false
		reset_visual_state()
		emit_signal("card_drag_cancelled", self)

	elif event is InputEventMouseMotion and is_dragging:
		# 拖拽中的位置更新
		global_position = get_global_mouse_position() - drag_offset

func reset_visual_state():
	"""重置视觉状态"""
	scale = original_scale
	z_index = original_z_index
	if glow_effect:
		glow_effect.color.a = 0.0

func cancel_drag():
	"""取消拖拽并回到原位"""
	if not is_dragging:
		return
		
	is_dragging = false
	reset_visual_state()
	emit_signal("card_drag_cancelled", self)

func return_to_original_position():
	"""这个函数现在不再需要了"""
	pass

func destroy_with_animation():
	# 简单的销毁动画
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free() 
