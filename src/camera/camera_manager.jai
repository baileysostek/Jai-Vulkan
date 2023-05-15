#import "Math";
#import "Basic";

Camera :: struct {
  view : Matrix4 = Matrix4_Identity;
  proj : Matrix4 = Matrix4_Identity;
}

make_camera :: (width : int, height : int) -> Camera {
  out := Camera.{};

  // TODO: Camera position and rotation
  out.view = transpose(inverse(.{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  }));

  // Clip
  X := transpose(inverse(.{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  }));

  // Perspective
  P := transpose(perspective(60.0 / 180.0 * PI, 1.0, 0.2, 10.0));
  
  // Projection * Clip
  out.proj = P * X;

  return out;
}

/**
  Perspective projection matrix, where a−1 is the framebuffer’s aspect ratio h/w, 
  ϕ is the field of view, 
  n is the distance of the near plane, 
  f is the distance of the far plane.
*/
perspective :: (fov : float, aspect : float, n : float, f : float) -> Matrix4 {

    t := tan(fov / 2.0);

    projection_matrix := Matrix4_Identity;

    projection_matrix._11 = aspect / (t);
    projection_matrix._22 = 1.0 / (t);
    projection_matrix._33 = f / (f - n);
    projection_matrix._43 = 1.0;
    projection_matrix._34 = -(n * f) / (f - n);
    projection_matrix._44 = 0.0;

  return projection_matrix;
}