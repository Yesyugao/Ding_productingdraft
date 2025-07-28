extends Resource
class_name CardData

enum CardType {
	ROCK,
	PAPER,
	SCISSORS,
	BLANK,
	BLACK
}

@export var id: String
@export var card_name: String
@export var card_type: CardType
@export var description: String
@export var cost: int
@export var texture: Texture2D 
