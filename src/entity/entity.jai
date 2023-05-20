#import "Math";

#load "mesh.jai";

Entity :: struct {
  transform : Matrix4;
  mesh : *Mesh = null;
}

set_position :: (x : float = 0.0, y : float = 0.0, z : float = 0.0, entity : *Entity) -> *Entity {
  entity.transform._14 = x;
  entity.transform._24 = y;
  entity.transform._34 = z; 

  return entity;
}

translate :: (x : float = 0, y : float = 0, z : float = 0, entity : *Entity) -> *Entity {
  return entity;
}

get_position :: (entity : Entity) -> float, float, float {
  return 
    entity.transform._14,
    entity.transform._24,
    entity.transform._34; 
}

rotate :: (x : float = 0, y : float = 0, z : float = 0, entity : *Entity) -> *Entity {
  return entity;
}

