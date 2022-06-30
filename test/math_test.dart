import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

import 'package:aaffine/models.dart';
import 'package:test/test.dart';

final rng = Random();

void main() {
  test("Matrix4 to Matrix3 conversion is invertible", () {
    final mat3 =
        Matrix3.fromList([for (var i = 0; i < 9; i++) rng.nextDouble()]);
    final mat4 = mat3.toMatrix4();
    expect(mat3, equals(mat4.toMatrix3()));
  });
}
