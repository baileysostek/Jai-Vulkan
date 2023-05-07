#import "Math"

Entity :: struct {
  transform : Matrix4  
}

set_position :: (x : 0, y : 0, z : 0, entity : *Entity) -> *Entity {
  entity.transform._14 = x;
  entity.transform._24 = y;
  entity.transform._34 = z; 
}

translate :: (x : 0, y : 0, z : 0, entity : *Entity) -> *Entity {

}

get_position :: (entity : Entity) -> float, float, float {
  return 
    entity.transform._14,
    entity.transform._24,
    entity.transform._34; 
}

rotate :: (x : 0, y : 0, z : 0, entity : *Entity) -> *Entity {
  
}

