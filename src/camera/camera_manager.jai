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
    0, 1, 0, 0.5,
    0, 0, 1, 0,
    0, 0, 0, 1
  }));

  // Clip
  X := transpose(inverse(.{
    1, 0, 0, 0,
    0, -1, 0, 0,
    0, 0, -1, 0,
    0, 0, 0, 1
  }));

  // Perspective
  P := transpose(perspective(60.0 / 180.0 * PI, 1.0, 0.1, -10.0));
  
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
perspective :: (fov : float, aspect : float, near_plane : float, far_plane : float) -> Matrix4 {

    tan_half_fov := tan(fov / 2.0);

    projection_matrix := Matrix4_Identity;
    projection_matrix._11 = 1.0 / (aspect * tan_half_fov);
    projection_matrix._22 = 1.0 / (tan_half_fov);
    projection_matrix._33 = far_plane / (far_plane - near_plane);
    projection_matrix._43 = 1.0;
    projection_matrix._34 = -(far_plane * near_plane) / (far_plane - near_plane);

  return projection_matrix;
}