#import "Math";
#import "Basic";

FUNDAMENTAL_FORWARD_VECTOR   : Vector3 : .{0, 0, 1}; // - Z
FUNDAMENTAL_TANGENT_VECTOR   : Vector3 : .{0, 1, 0}; // + Y
FUNDAMENTAL_BITANGENT_VECTOR : Vector3 : .{1, 0, 0}; // + X
FUNDAMENTAL_VECTORS :: (Vector3).[FUNDAMENTAL_FORWARD_VECTOR, FUNDAMENTAL_TANGENT_VECTOR, FUNDAMENTAL_BITANGENT_VECTOR];

active_camera : Camera;

set_active_camera :: (camera : Camera) {
  active_camera = camera;
}

Camera :: struct {

  // Forward vector
  forward_direction   : Vector3 = FUNDAMENTAL_FORWARD_VECTOR; // Local Z
  tangent_direction   : Vector3 = FUNDAMENTAL_TANGENT_VECTOR; // Local X
  bitangnet_direction : Vector3 = FUNDAMENTAL_BITANGENT_VECTOR; // Local Y

  // Hold our rotation angles.
  angle_deltas : Vector3 = .{0.0, 0.0, 0.0};

  // These are the matrices we use to determine the view and projection of this camera.
  view : Matrix4 = Matrix4_Identity;
  rotation : Matrix4 = Matrix4_Identity;
  proj : Matrix4 = Matrix4_Identity;

  // Struct specific Procedures
  translate :: (x : float, y : float, z : float) {
    active_camera.view._41 += x;
    active_camera.view._42 += y;
    active_camera.view._43 += z;
  }

  translate :: (xyz : Vector3) {
    translate(xyz.x, xyz.y, xyz.z);
  }

  set_position :: (x : float, y : float, z : float) {
    active_camera.view._41 = x;
    active_camera.view._42 = y;
    active_camera.view._43 = z;
  }

  set_position :: (xyz : Vector3) {
    set_position(xyz.x, xyz.y, xyz.z);
  }

  // FPS rotation
  rotate :: (x : float, y : float, z : float) {
    // Rotation deltas?
    active_camera.angle_deltas.x += x;
    active_camera.angle_deltas.y += y;
    active_camera.angle_deltas.z += z;

    // Cumulative Rotation
    rotation : Quaternion = .{};
  
    // Rotate about the Forward Axis
    world_y_rotation := Quaternion.{};
    set_from_axis_and_angle(*world_y_rotation, FUNDAMENTAL_TANGENT_VECTOR, active_camera.angle_deltas.y);
    rotation = world_y_rotation * rotation;

    relative_x_rotation := Quaternion.{};
    set_from_axis_and_angle(*relative_x_rotation, FUNDAMENTAL_BITANGENT_VECTOR, active_camera.angle_deltas.x);
    rotation = relative_x_rotation * rotation;

    relative_z_rotation := Quaternion.{};
    set_from_axis_and_angle(*relative_z_rotation, FUNDAMENTAL_FORWARD_VECTOR, active_camera.angle_deltas.z);
    rotation = relative_z_rotation * rotation;

    // Set the rotation matrix
    active_camera.rotation = rotate(Matrix4_Identity, rotation);
    active_camera.forward_direction = rotate(FUNDAMENTAL_FORWARD_VECTOR, rotation);
  }

  index_vector_component :: (vector : *Vector3, index : u8) -> float {
    if index == {
      case 0;
        return vector.x;
      case 1;
        return vector.y;
      case 2;
        return vector.z;
      case; // Unhandled error.
        return vector.x;
    }
  }
  
  // Compute the rotaiton matrix based on the current forward quaternion?
  getRotation :: () -> Matrix4 {
    return active_camera.rotation;
  }

  // Get the view matrix of this camera.
  getView :: () -> Matrix4{
    return inverse(active_camera.view) * inverse(getRotation());
  }

  // Bake the aspect ratio into the projection matrix for this camera.
  getProjection :: (aspect_ratio : float) -> Matrix4{
    return .{
      1.0, 0.0, 0.0, 0.0,
      0.0, aspect_ratio, 0.0, 0.0, 
      0.0, 0.0, 1.0, 0.0, 
      0.0, 0.0, 0.0, 1.0, 
    } * active_camera.proj;
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