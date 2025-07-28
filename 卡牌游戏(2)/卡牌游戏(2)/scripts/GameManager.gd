extends Node

# --- 卡牌资源预加载 ---
const ROCK_CARD = preload("res://cards/rock_card.tres")
const PAPER_CARD = preload("res://cards/paper_card.tres")
const SCISSORS_CARD = preload("res://cards/scissors_card.tres")
const BLANK_CARD = preload("res://cards/blank_card.tres")
const BLACK_CARD = preload("res://cards/black_card.tres")

# --- 游戏状态 ---
var player_hp := 3
var enemy_hp := 3
var player_energy := 3

# --- 牌库管理 ---
var player_deck: Array[CardData] = []
var player_hand: Array[CardData] = []
var player_discard_pile: Array[CardData] = []

var enemy_deck: Array[CardData] = []
var enemy_hand: Array[CardData] = []
var enemy_discard: Array[CardData] = []

# --- 战斗状态 ---
var player_battle_card: CardData = null  # 玩家本回合的战斗卡牌
var enemy_battle_card: CardData = null   # 敌人本回合的战斗卡牌
var current_battle_card: CardData = null # 当前战斗区域显示的卡牌
var is_rps_reversed := false # 本回合剪刀石头布规则是否反转

# --- 回合系统 ---
enum Turn { PLAYER, ENEMY, BATTLE_RESOLUTION }
var current_turn: Turn = Turn.PLAYER
var can_end_turn_flag := false # 是否已经打出战斗卡牌

# --- 信号 ---
signal card_drawn(card_data)
signal player_stats_changed()
signal enemy_stats_changed()
signal turn_changed()
signal battle_result(result_text)
signal game_ended(winner)
signal hand_cleared
signal enemy_card_played(card_data)

func _ready():
	start_game()

func start_game():
	print("=== 游戏开始 ===")
	player_hp = 3
	enemy_hp = 3
	current_turn = Turn.PLAYER
	build_decks()
	start_player_turn()

func build_decks():
	var deck_composition = [
		{"card": ROCK_CARD, "count": 3},
		{"card": PAPER_CARD, "count": 3},
		{"card": SCISSORS_CARD, "count": 3},
		{"card": BLANK_CARD, "count": 2},
		{"card": BLACK_CARD, "count": 2}
	]
	
	# 清空所有牌堆
	player_deck.clear()
	enemy_deck.clear()
	player_hand.clear()
	player_discard_pile.clear()
	enemy_hand.clear()
	enemy_discard.clear()
	
	# 构建牌组
	for item in deck_composition:
		for i in range(item.count):
			player_deck.append(item.card)
			enemy_deck.append(item.card)
			
	player_deck.shuffle()
	enemy_deck.shuffle()

func start_player_turn():
	print("=== 玩家回合开始 ===")
	current_turn = Turn.PLAYER
	player_energy = 3
	is_rps_reversed = false
	player_battle_card = null
	current_battle_card = null
	can_end_turn_flag = false
	
	# 抽5张卡
	draw_cards_for_player(5)
	
	emit_signal("player_stats_changed")
	emit_signal("turn_changed")

func draw_cards_for_player(amount: int):
	for i in range(amount):
		if player_deck.is_empty():
			if player_discard_pile.is_empty():
				print("玩家没有卡牌可抽了")
				break
			# 弃牌堆洗回牌库
			player_deck = player_discard_pile.duplicate()
			player_deck.shuffle()
			player_discard_pile.clear()
			print("弃牌堆洗回牌库")
		
		if not player_deck.is_empty():
			var card = player_deck.pop_front()
			player_hand.append(card)
			emit_signal("card_drawn", card)
			
		# 手牌上限检查
		if player_hand.size() > 10:
			var excess_card = player_hand.pop_back()
			player_discard_pile.append(excess_card)
			print("我的手牌满了")

func play_card(card_data: CardData) -> bool:
	if current_turn != Turn.PLAYER:
		print("不是玩家回合！")
		return false
		
	# 检查是否已经出过战斗卡
	if card_data.card_type in [CardData.CardType.ROCK, CardData.CardType.PAPER, CardData.CardType.SCISSORS]:
		if player_battle_card != null:
			print("本回合已经出过战斗卡了，不能再出了！")
			# 注意：由于出牌失败，这里直接返回，不消耗能量也不弃牌
			return false
			
	if player_energy < card_data.cost:
		print("费用不足！需要 %d，当前只有 %d" % [card_data.cost, player_energy])
		return false
	
	# 扣除费用
	player_energy -= card_data.cost
	
	# 从手牌中移除
	player_hand.erase(card_data)
	
	# 根据卡牌类型执行效果
	match card_data.card_type:
		CardData.CardType.BLANK:
			print("使用空白卡：抽取2张卡牌")
			draw_cards_for_player(2)
			# 立即进入弃牌堆
			player_discard_pile.append(card_data)
			
		CardData.CardType.BLACK:
			print("使用黑卡：本回合剪刀石头布规则反转")
			is_rps_reversed = true
			# 立即进入弃牌堆
			player_discard_pile.append(card_data)
			
		CardData.CardType.ROCK, CardData.CardType.PAPER, CardData.CardType.SCISSORS:
			print("使用战斗卡：%s" % card_data.card_name)
			player_battle_card = card_data
			current_battle_card = card_data
			can_end_turn_flag = true
			# 立即进入弃牌堆
			player_discard_pile.append(card_data)
	
	# 发出信号更新UI
	emit_signal("player_stats_changed")
	
	return true

func can_end_turn() -> bool:
	return can_end_turn_flag

func end_turn():
	if current_turn == Turn.PLAYER:
		end_player_turn()
	elif current_turn == Turn.ENEMY:
		end_enemy_turn()

func end_player_turn():
	if not can_end_turn():
		pass
	
	print("=== 玩家回合结束 ===")
	
	# 剩余手牌进入弃牌堆
	player_discard_pile.append_array(player_hand)
	player_hand.clear()
	emit_signal("hand_cleared")
	
	# 开始敌人回合
	start_enemy_turn()

func start_enemy_turn():
	print("=== 敌人回合开始 ===")
	current_turn = Turn.ENEMY
	emit_signal("turn_changed")
	
	# 敌人随机选择一张战斗牌
	var battle_cards = [ROCK_CARD, PAPER_CARD, SCISSORS_CARD]
	enemy_battle_card = battle_cards.pick_random()
	print("敌人选择：%s" % enemy_battle_card.card_name)
	
	# 发出信号，让UI可以显示敌人出牌
	emit_signal("enemy_card_played", enemy_battle_card)
	
	# 等待UI显示完成
	await get_tree().create_timer(2.0).timeout
	
	# 敌人回合立即结束，进入战斗结算
	end_enemy_turn()

func end_enemy_turn():
	print("=== 敌人回合结束 ===")
	# 进入战斗结算阶段
	resolve_battle()

func resolve_battle():
	print("=== 战斗结算 ===")
	current_turn = Turn.BATTLE_RESOLUTION
	
	if not player_battle_card or not enemy_battle_card:
		print("战斗结算失败：缺少战斗卡牌")
		return
	
	var result = determine_winner(player_battle_card.card_type, enemy_battle_card.card_type)
	var result_text = ""
	
	if result == 0: # 平局
		result_text = "平局！无人受伤"
		print("结果：平局")
	elif result == 1: # 玩家胜利
		result_text = "你赢了！敌人受到1点伤害"
		print("结果：玩家胜利")
		enemy_hp -= 1
		emit_signal("enemy_stats_changed")
	else: # 敌人胜利
		result_text = "你输了！你受到1点伤害"
		print("结果：敌人胜利")
		player_hp -= 1
		emit_signal("player_stats_changed")
	
	emit_signal("battle_result", result_text)
	
	# 重置战斗卡牌
	player_battle_card = null
	enemy_battle_card = null
	current_battle_card = null
	
	# 检查游戏是否结束
	if player_hp <= 0:
		emit_signal("game_ended", "敌人")
		print("游戏结束：你失败了")
	elif enemy_hp <= 0:
		emit_signal("game_ended", "玩家")
		print("游戏结束：你获胜了")
	else:
		# 开始新的玩家回合
		await get_tree().create_timer(2.0).timeout  # 给玩家2秒时间看结果
		start_player_turn()

func determine_winner(player_type: CardData.CardType, enemy_type: CardData.CardType) -> int:
	if player_type == enemy_type:
		return 0 # 平局
	
	var win_conditions = {
		CardData.CardType.SCISSORS: CardData.CardType.PAPER,  # 剪刀 > 布
		CardData.CardType.PAPER: CardData.CardType.ROCK,     # 布 > 石头
		CardData.CardType.ROCK: CardData.CardType.SCISSORS   # 石头 > 剪刀
	}
	
	var player_wins = win_conditions[player_type] == enemy_type
	
	# 如果黑卡效果激活，反转结果
	if is_rps_reversed:
		player_wins = not player_wins
		print("黑卡效果：规则反转！")
	
	return 1 if player_wins else -1 
