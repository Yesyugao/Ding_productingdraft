extends Control

@export var card_scene: PackedScene

var player_hand_container: HBoxContainer
var battle_zone: NinePatchRect
var battle_card_display: Control
var battle_card_name: Label
var drop_zone_highlight: ColorRect
var drop_hint: Label
var end_turn_button: Button

# UI元素引用
var player_hp_label: Label
var player_energy_label: Label
var deck_count_label: Label
var discard_count_label: Label
var enemy_hp_label: Label
var current_turn_label: Label
var battle_result_label: Label
var enemy_battle_card_zone: Panel
var enemy_card_name_label: Label
var speech_bubble: NinePatchRect
var speech_bubble_label: Label

# 牌堆按钮
var deck_button: Button
var discard_button: Button
var my_deck_button: Button

var dragging_card: Card = null
var is_over_battle_zone: bool = false

func _ready():
	# 获取UI元素引用
	player_hand_container = $UI/PlayerHandContainer
	battle_zone = $UI/BattleZone
	battle_card_display = $UI/BattleZone/CardDisplay
	battle_card_name = $UI/BattleZone/CardDisplay/CardName
	drop_zone_highlight = $UI/BattleZone/DropZoneHighlight
	drop_hint = $UI/DropHint
	end_turn_button = $UI/EndTurnButton
	
	# 获取状态显示元素
	player_hp_label = $UI/LeftSidebar/PlayerStatus/HP
	player_energy_label = $UI/LeftSidebar/PlayerStatus/Energy
	deck_count_label = $UI/LeftSidebar/PlayerStatus/DeckCount
	discard_count_label = $UI/LeftSidebar/PlayerStatus/DiscardCount
	enemy_hp_label = $UI/RightSidebar/EnemyStatus/HP
	current_turn_label = $UI/RightSidebar/EnemyStatus/CurrentTurn
	battle_result_label = $UI/RightSidebar/EnemyStatus/BattleResult
	enemy_battle_card_zone = $UI/EnemyBattleCardZone
	enemy_card_name_label = $UI/EnemyBattleCardZone/CardName
	speech_bubble = $UI/SpeechBubble
	speech_bubble_label = $UI/SpeechBubble/Label
	
	# 获取牌堆按钮
	deck_button = $UI/LeftSidebar/PlayerStatus/PileButtons/DeckButton
	discard_button = $UI/LeftSidebar/PlayerStatus/PileButtons/DiscardButton
	my_deck_button = $UI/LeftSidebar/PlayerStatus/PileButtons/MyDeckButton
	
	# 连接信号
	GameManager.card_drawn.connect(_on_card_drawn)
	GameManager.player_stats_changed.connect(_on_player_stats_changed)
	GameManager.enemy_stats_changed.connect(_on_enemy_stats_changed)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.battle_result.connect(_on_battle_result)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.hand_cleared.connect(_on_hand_cleared)
	GameManager.enemy_card_played.connect(_on_enemy_card_played)
	
	# 连接UI信号
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	deck_button.pressed.connect(_on_deck_button_pressed)
	discard_button.pressed.connect(_on_discard_button_pressed)
	my_deck_button.pressed.connect(_on_my_deck_button_pressed)
	
	# 初始化界面
	drop_zone_highlight.visible = false
	drop_hint.visible = false
	update_player_hand()
	update_player_stats()
	update_enemy_stats()
	update_turn_info()
	update_battle_zone()

func _on_card_drawn(card_data: CardData):
	var card_instance = card_scene.instantiate()
	card_instance.card_data = card_data
	card_instance.card_dragged.connect(_on_card_dragged)
	card_instance.card_dropped.connect(_on_card_dropped)
	player_hand_container.add_child(card_instance)

func _on_card_dragged(card: Card):
	dragging_card = card
	drop_hint.visible = true
	drop_hint.text = "将战斗卡牌拖拽到此处"

func update_player_hand():
	# 清空现有手牌
	for child in player_hand_container.get_children():
		child.queue_free()
	
	# 重新添加手牌
	for card_data in GameManager.player_hand:
		var card_instance = card_scene.instantiate()
		card_instance.card_data = card_data
		card_instance.card_dragged.connect(_on_card_dragged)
		card_instance.card_dropped.connect(_on_card_dropped)
		card_instance.card_drag_cancelled.connect(_on_card_drag_cancelled)
		player_hand_container.add_child(card_instance)

func _on_card_drag_cancelled(card: Card):
	"""处理拖拽取消"""
	print("处理拖拽取消，重新布局手牌")
	
	# 重置拖拽状态
	dragging_card = null
	drop_hint.visible = false
	drop_zone_highlight.visible = false
	is_over_battle_zone = false
	
	# 重新布局手牌 - 这会让卡牌回到正确位置
	update_player_hand()

func _on_card_dropped(card: Card):
	if dragging_card != card:
		return
		
	dragging_card = null
	drop_hint.visible = false
	drop_zone_highlight.visible = false
	
	# 只有在战斗区域内投放才尝试使用卡牌
	if is_over_battle_zone:
		var success = GameManager.play_card(card.card_data)
		if success:
			print("✓ 成功使用卡牌: %s" % card.card_data.card_name)
			card.destroy_with_animation()
			# 更新UI状态
			update_turn_info()
			update_battle_zone()
		else:
			print("✗ 无法使用卡牌")
			# 使用失败，重新布局手牌
			update_player_hand()
	else:
		# 如果不在战斗区域，重新布局手牌
		print("卡牌未放置在战斗区域，重新布局")
		update_player_hand()
	
	# 重置拖拽状态
	is_over_battle_zone = false

func _input(event):
	if event is InputEventMouseMotion and dragging_card:
		var mouse_pos = get_global_mouse_position()
		var battle_zone_rect = battle_zone.get_global_rect()
		
		if battle_zone_rect.has_point(mouse_pos):
			if not is_over_battle_zone:
				is_over_battle_zone = true
				show_drop_zone_highlight()
		else:
			if is_over_battle_zone:
				is_over_battle_zone = false
				hide_drop_zone_highlight()

func show_drop_zone_highlight():
	drop_zone_highlight.visible = true
	drop_zone_highlight.color = Color(0.3, 0.8, 0.3, 0.3)

func hide_drop_zone_highlight():
	drop_zone_highlight.visible = false

func update_player_stats():
	player_hp_label.text = "HP: %d ❤" % GameManager.player_hp
	player_energy_label.text = "能量: %d ⚡" % GameManager.player_energy
	deck_count_label.text = "牌堆: %d" % GameManager.player_deck.size()
	discard_count_label.text = "弃牌堆: %d" % GameManager.player_discard_pile.size()

func update_enemy_stats():
	enemy_hp_label.text = "HP: %d ❤" % GameManager.enemy_hp

func update_turn_info():
	match GameManager.current_turn:
		GameManager.Turn.PLAYER:
			current_turn_label.text = "当前回合: 玩家"
			end_turn_button.disabled = not GameManager.can_end_turn()
			if GameManager.can_end_turn():
				end_turn_button.text = "结束回合"
			else:
				end_turn_button.text = "需要战斗卡牌"
		GameManager.Turn.ENEMY:
			current_turn_label.text = "当前回合: 敌人"
			end_turn_button.disabled = true
			end_turn_button.text = "敌人回合"
		GameManager.Turn.BATTLE_RESOLUTION:
			current_turn_label.text = "战斗结算中"
			end_turn_button.disabled = true
			end_turn_button.text = "结算中..."

func update_battle_zone():
	if GameManager.current_battle_card:
		battle_card_name.text = GameManager.current_battle_card.card_name
		battle_card_display.modulate = get_card_type_color(GameManager.current_battle_card.card_type)
	else:
		battle_card_name.text = "无卡牌"
		battle_card_display.modulate = Color.WHITE

func get_card_type_color(card_type: CardData.CardType) -> Color:
	match card_type:
		CardData.CardType.ROCK:
			return Color(0.8, 0.6, 0.4)  # 棕色
		CardData.CardType.PAPER:
			return Color(0.9, 0.9, 0.9)  # 白色
		CardData.CardType.SCISSORS:
			return Color(0.8, 0.8, 0.8)  # 灰色
		CardData.CardType.BLANK:
			return Color(0.7, 0.9, 0.7)  # 绿色
		CardData.CardType.BLACK:
			return Color(0.3, 0.3, 0.3)  # 黑色
		_:
			return Color.WHITE

func _on_player_stats_changed():
	update_player_stats()

func _on_enemy_stats_changed():
	update_enemy_stats()

func _on_turn_changed():
	update_turn_info()
	update_battle_zone()

func _on_enemy_card_played(card_data: CardData):
	# 显示敌人出的牌
	enemy_card_name_label.text = card_data.card_name
	enemy_battle_card_zone.show()
	
	# 显示对话气泡
	speech_bubble_label.text = "我出 %s！" % card_data.card_name
	speech_bubble.show()
	
	# 1.5秒后隐藏
	await get_tree().create_timer(1.5).timeout
	enemy_battle_card_zone.hide()
	speech_bubble.hide()


func _on_battle_result(result: String):
	battle_result_label.text = "战斗结果: %s" % result
	
	# 根据结果显示不同颜色
	if "赢" in result:
		battle_result_label.modulate = Color.GREEN
	elif "输" in result:
		battle_result_label.modulate = Color.RED
	else:
		battle_result_label.modulate = Color.YELLOW

func _on_game_ended(winner: String):
	print("游戏结束! 获胜者: %s" % winner)
	
	# 简单的游戏结束提示
	var game_over_label = Label.new()
	game_over_label.text = "游戏结束！\n%s获胜！" % winner
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(game_over_label)

func _on_hand_cleared():
	# 清空手牌容器中的所有卡牌UI
	for card_node in player_hand_container.get_children():
		card_node.queue_free()

func _on_end_turn_button_pressed():
	if GameManager.current_turn == GameManager.Turn.PLAYER and GameManager.can_end_turn():
		GameManager.end_turn()
	else:
		print("无法结束回合：需要先出一张战斗卡牌")

func _on_deck_button_pressed():
	show_pile_popup("牌堆", GameManager.player_deck)

func _on_discard_button_pressed():
	show_pile_popup("弃牌堆", GameManager.player_discard_pile)

func _on_my_deck_button_pressed():
	show_deck_composition()

func show_pile_popup(title: String, cards: Array):
	# 创建弹出窗口显示牌堆内容
	var popup = AcceptDialog.new()
	popup.title = title
	popup.dialog_text = ""
	
	if cards.is_empty():
		popup.dialog_text = "%s为空" % title
	else:
		for i in range(cards.size()):
			var card = cards[i]
			popup.dialog_text += "%d. %s\n" % [i+1, card.card_name]
	
	add_child(popup)
	popup.popup_centered(Vector2(400, 500))
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)

func show_deck_composition():
	var popup = AcceptDialog.new()
	popup.title = "我的牌组"
	popup.dialog_text = "牌组构成：\n\n"
	popup.dialog_text += "3张 石头\n"
	popup.dialog_text += "3张 布\n"
	popup.dialog_text += "3张 剪刀\n"
	popup.dialog_text += "2张 空白卡\n"
	popup.dialog_text += "2张 黑卡\n"
	popup.dialog_text += "\n总共13张卡牌"
	
	add_child(popup)
	popup.popup_centered(Vector2(400, 400))
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free) 
