import 'dart:ui';

/// Assumes we're facing the direction the line goes in
enum LineSide { left, right, onTopOf }

/// A positioned vector is different from a line segment because it might have
/// infinite length. I have decided this
class PositionedVector implements Comparable {
  late final Offset from;
  late final Offset towards;
  late final bool infiniteLength;

  PositionedVector(this.from, this.towards, this.infiniteLength);
  PositionedVector.pointSlope(this.from, double slope, [double length = 1]) {
    towards = from + Offset(1 / slope, slope);
    if (length == double.infinity) {
      infiniteLength = true;
    } else {
      infiniteLength = false;
      towards = (positionVector / this.length + towards) * length;
    }
  }

  @override
  String toString() {
    return "PositionedVector{"
        "from $from, towards $towards, ${infiniteLength ? '' : 'not '}infinite}";
  }

  double _computeLength() {
    return infiniteLength ? double.infinity : (towards - from).distance;
  }

  double? _length;
  double get length => _length ??= _computeLength();

  Offset _computePositionVector() {
    return towards - from;
  }

  Offset? _positionVector;
  Offset get positionVector => _positionVector ??= _computePositionVector();

  PositionedVector normalized() {
    return PositionedVector(from, positionVector / length + towards, false);
  }

  PositionedVector translate(Offset direction) {
    return PositionedVector(
        from + direction, towards + direction, infiniteLength);
  }

  /// Based on vector length. Implementation note: uses [Offset.distanceSquared]
  /// for performance
  @override
  int compareTo(covariant PositionedVector p2) {
    final thisDS =
        infiniteLength ? double.infinity : (towards - from).distanceSquared;
    final otherDS = p2.infiniteLength
        ? double.infinity
        : (p2.towards - p2.from).distanceSquared;
    if (thisDS == otherDS) {
      return 0;
    } else if (thisDS < otherDS) {
      return -1;
    } else {
      return 1;
    }
  }

  /// Assumes we're standing at [from] and look at [towards]. Warning: this
  /// method cheats and assumes this vector extends in both directions infinitely
  /// to avoid writing a whole new Line class.
  LineSide onSideOf(Offset point) {
    final det = (towards.dx - from.dx) * (point.dy - from.dy) -
        (towards.dy - from.dy) * (point.dx - from.dx);
    if (det.abs() < 0.0001) {
      return LineSide.onTopOf;
    } else if (det < 0) {
      return LineSide.left;
    } else {
      return LineSide.right;
    }
  }

  /// Finds the intersection point between two PositionedVectors. Returns null
  /// if no intersection can be found or if the vectors are colinear. Heavily
  /// adapted from https://stackoverflow.com/a/565282/3962267 .
  Offset? intersectWith(covariant PositionedVector other) {
    double crossProduct(Offset a, Offset b) {
      return a.dx * b.dy - a.dy * b.dx;
    }

    if (crossProduct(positionVector, other.positionVector) == 0) {
      // vectors are parallel
      return null;
    }
    final thisT = crossProduct(
        (other.from - from),
        other.positionVector /
            (crossProduct(positionVector, other.positionVector)));
    final otherT = crossProduct(from - other.from,
        positionVector / crossProduct(other.positionVector, positionVector));
    if (thisT < 0 || otherT < 0) {
      // would need to go "backward" along the vector to find an intersection
      return null;
    } else if (thisT > 1 && !infiniteLength) {
      return null;
    } else if (otherT > 1 && !other.infiniteLength) {
      return null;
    } else {
      final scaledPosition = positionVector * thisT;
      return from + scaledPosition;
    }
  }

  Offset closestPointOn(Offset point) {
    // Theory: to find the closest point on a line to an incoming point, project
    // along the vector that passes through the incoming point and is
    // perpendicular to this one.
    final rotatedPV = Offset(positionVector.dy, -positionVector.dx);
    final projVector = PositionedVector.pointSlope(
        point, rotatedPV.dy / rotatedPV.dx, double.infinity);
    final projected = intersectWith(projVector);
    if (projected == null) {
      // If there is no intersection between the perpendicular vector through
      // the point and this one, one of the endpoints is closest
      if ((point - from).distanceSquared < (point - towards).distanceSquared) {
        return from;
      } else {
        return towards;
      }
    } else {
      return projected;
    }
  }
}
