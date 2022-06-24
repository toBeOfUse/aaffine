import 'dart:ui';

enum LineSide { left, right, onTopOf }

/// A radiant vector is like a line segment but it might have infinite length in
/// exactly one direction. It's an optionally infinite ray. I have decided this
class RadiantVector implements Comparable {
  late final Offset from;
  late final Offset towards;
  late final bool infiniteLength;

  RadiantVector(this.from, this.towards, this.infiniteLength);
  RadiantVector.pointSlope(this.from, double slope, [double length = 1]) {
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
    return "RadiantVector{"
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

  RadiantVector normalized() {
    return RadiantVector(from, positionVector / length + towards, false);
  }

  RadiantVector translate(Offset direction) {
    return RadiantVector(from + direction, towards + direction, infiniteLength);
  }

  /// Based on vector length. Implementation note: uses [Offset.distanceSquared]
  /// for performance
  @override
  int compareTo(covariant RadiantVector p2) {
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

  /// Assumes we're standing at [from] and look at [towards]. WARNING: this
  /// method cheats and assumes this vector extends in both directions
  /// infinitely because the use case is specific enough to allow that for now.
  /// Fixing that would just require checking if a perpendicular vector
  /// extending from point would intersect this vector (presumably via a call to
  /// [intersectWith] like at the beginning of [closestPointOn]) and returning a
  /// new value if not (i.e. if [intersectWith] returns null.)
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

  /// Finds the intersection point between two [RadiantVector]s. Returns null
  /// if no intersection can be found or if the vectors are colinear. Heavily
  /// adapted from https://stackoverflow.com/a/565282/3962267 .
  Offset? intersectWith(covariant RadiantVector other) {
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
    // Theory: to find the closest point on a RadiantVector to an incoming
    // point, project along the (different) line that passes through the
    // incoming point and is perpendicular to this RadiantVector.
    final rotatedPV = Offset(positionVector.dy, -positionVector.dx);
    // The perpendicular line is here represented by a RadiantVector. Because
    // we only need to go in one direction
    final projVector = RadiantVector.pointSlope(
        point, rotatedPV.dy / rotatedPV.dx, double.infinity);
    final projected = intersectWith(projVector);
    if (projected == null) {
      // If there is no intersection between the perpendicular line through
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
