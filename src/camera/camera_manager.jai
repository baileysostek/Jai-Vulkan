#import "Math";

Camera :: struct {
  view : Matrix4 = Matrix4_Identity;
  proj : Matrix4 = Matrix4_Identity;
}

make_camera :: (aspect_ratio : float) -> Camera {
  out := Camera.{};

  // out.view = transpose(.{
  //   1, 0, 0, 0,
  //   0, 1, 0, 0,
  //   0, 0, 1, 1,
  //   0, 0, 0, 1
  // });
  
  // out.proj = perspective(to_radians(60.0), aspect_ratio, 0.1, 10.0);

  out.view = transpose(make_look_at_matrix(.{0.0, 3.0, 0.0}, .{0.0, 0.0, 0.0}, .{0.0, 0.0, 1.0}));
  out.proj = transpose(make_projection_matrix(45.0 * PI / 180.0, aspect_ratio, 0.1, 10.0));
  out.proj._22 = 1.0;
  return out;
}

perspective :: (vertical_fov : float , aspect_ratio : float, n : float, f : float) -> Matrix4 {
    fov_rad : float = vertical_fov * 2.0 * PI / 360.0;
    focal_length : float = 1.0 / tan(fov_rad / 2.0);

    x : float =  focal_length / aspect_ratio;
    y : float = -focal_length;
    A : float = n / (f - n);
    B : float = f * A;

    projection : Matrix4;

    if true {
      projection = Matrix4.{
        x,   0.0,  0.0, 0.0,
        0.0,   y,  0.0, 0.0,
        0.0, 0.0,    A,   B,
        0.0, 0.0, -1.0, 0.0,
      };
    } else {
      projection = Matrix4.{
        1/x, 0.0, 0.0,  0.0,
        0.0, 1/y, 0.0,  0.0,
        0.0, 0.0, 0.0, -1.0,
        0.0, 0.0, 1/B,  A/B,
      };
    }

    // if (inverse)
    // {
    //     *inverse = float4x4({
    //         1/x,  0.0f, 0.0f,  0.0f,
    //         0.0f,  1/y, 0.0f,  0.0f,
    //         0.0f, 0.0f, 0.0f, -1.0f,
    //         0.0f, 0.0f,  1/B,   A/B,
    //     });
    // }

    return projection;
}