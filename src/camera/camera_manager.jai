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
  P := perspective(width, height, 70.0, 0.1, 10.0);
  
  // Projection * Clip
  // out.proj = P;

  return out;
}

/**
  Perspective projection matrix, where a−1 is the framebuffer’s aspect ratio h/w, 
  ϕ is the field of view, 
  n is the distance of the near plane, 
  f is the distance of the far plane.
*/
perspective :: (width : int, height : int, fov : float, near_plane : float, far_plane : float) -> Matrix4 {

  a := (cast(float)width / cast(float)height);

  f := 1.0 - tan(((fov / 2.0) / 360.0) * 2.0 * PI);

  out : Matrix4 = transpose(.{
    f / a, 0, 0, 0,
    0, -f, 0, 0,
    0, 0, far_plane / (near_plane - far_plane), -1.0,
    0, 0, (near_plane * far_plane) / (near_plane - far_plane), 0
  });

  return out;
}