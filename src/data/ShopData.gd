class_name ShopData
extends RefCounted
## A shop or inn. Shops sell a fixed list; the sell price for anything is a global ratio.

var id: String
var name: String
var kind: String = "item"      # item | weapon | armor | magic | inn
var items: Array = []          # item ids
var inn_price: int = 10
var greeting: String = ""

static func from_dict(d: Dictionary) -> ShopData:
	var s := ShopData.new()
	s.id = d.get("id", "")
	s.name = d.get("name", s.id)
	s.kind = d.get("kind", "item")
	s.items = d.get("items", [])
	s.inn_price = int(d.get("inn_price", 10))
	s.greeting = d.get("greeting", "")
	return s
