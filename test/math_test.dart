import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

import 'package:aaffine/models.dart';
import 'package:test/test.dart';

final rng = Random();

void main() {
  test("Matrix3 to Matrix4 conversion is invertible", () {
    final mat3 =
        Matrix3.fromList([for (var i = 0; i < 9; i++) rng.nextDouble()]);
    final mat4 = mat3.toMatrix4();
    expect(mat3, equals(mat4.toMatrix3()));
  });
  test("Matrix4 to Matrix3 conversion makes sense", () {
    final mat4 = Matrix4.columns(Vector4(1, 2, 3, 4), Vector4(5, 6, 7, 8),
        Vector4(9, 10, 11, 12), Vector4(13, 14, 15, 16));
    final mat3 = mat4.toMatrix3();
    expect(mat3.getColumn(0), equals(Vector3(1, 2, 4)));
    expect(mat3.getColumn(1), equals(Vector3(5, 6, 8)));
    expect(mat3.getColumn(2), equals(Vector3(13, 14, 16)));
  });
  test("Matrix3 toLists makes sense", () {
    final mat3 =
        Matrix3.columns(Vector3(0, 3, 6), Vector3(1, 4, 7), Vector3(2, 5, 8));
    expect(
        mat3.toLists(),
        equals([
          [0, 1, 2],
          [3, 4, 5],
          [6, 7, 8]
        ]));
  });
  test("Matrix4 toLists makes sense", () {
    final mat4 = Matrix4.columns(Vector4(0, 4, 8, 12), Vector4(1, 5, 9, 13),
        Vector4(2, 6, 10, 14), Vector4(3, 7, 11, 15));
    expect(
        mat4.toLists(),
        equals([
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
          [12, 13, 14, 15],
        ]));
  });
}
