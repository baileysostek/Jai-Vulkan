#import "Math";
#import "Basic";

Camera :: struct {
  view : Matrix4 = Matrix4_Identity;
  proj : Matrix4 = Matrix4_Identity;

  // Struct specific Procedures
  translate :: (camera : *Camera, x : float, y : float, z : float) {
    camera.view._41 += x;
    camera.view._42 += y;
    camera.view._43 += z;
  }

  getView :: (camera : *Camera) -> Matrix4{
    return inverse(camera.view);
  }

}

PerspectiveCamera :: struct {
  #as using base : Camera;

  proj = #run transpose(perspective(60.0 / 180.0 * PI, 1.0, 0.1, 1024.0));

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
}