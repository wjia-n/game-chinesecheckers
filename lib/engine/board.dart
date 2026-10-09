import 'dart:math';

/// Board geometry for Chinese Checkers — the authoritative coordinate model
/// from RULES.md §2: 17 rows, widths 1,2,3,4,13,12,11,10,9,10,11,12,13,4,3,2,1.
class Board {
  static const List<int> rowWidths = [
    1, 2, 3, 4, 13, 12, 11, 10, 9, 10, 11, 12, 13, 4, 3, 2, 1
  ];

  /// Vertical spacing factor (sqrt(3)/2) so hex neighbors are equidistant.
  static const double dy = 0.8660254;

  final List<Hole> holes = [];
  final List<List<int>> neighbors = [];

  /// Arm index 0..5 for every hole. 0 = top tip, then clockwise:
  /// 1 upper-right, 2 lower-right, 3 bottom tip, 4 lower-left, 5 upper-left.
  /// Hexagon holes have arm -1.
  final List<int> armOf = [];

  Board() {
    _buildHoles();
    _buildArms();
    _buildNeighbors();
  }

  void _buildHoles() {
    var idx = 0;
    for (int r = 0; r < rowWidths.length; r++) {
      final w = rowWidths[r];
      for (int c = 0; c < w; c++) {
        holes.add(Hole(
          row: r,
          col: c,
          idx: idx++,
          x: c - (w - 1) / 2.0,
          y: (r - 8) * dy,
        ));
      }
    }
  }

  void _buildArms() {
    armOf.addAll(List.filled(holes.length, -1));
    for (final h in holes) {
      final r = h.row;
      if (r <= 3) {
        armOf[h.idx] = 0; // top arm
      } else if (r >= 13) {
        armOf[h.idx] = 3; // bottom arm
      } else {
        // Rows 4..12: side arms flank the central hexagon.
        // Hexagon row widths: 5,6,7,8,9,8,7,6,5 -> side-arm holes per row:
        const side = [4, 3, 2, 1, 0, 1, 2, 3, 4];
        final n = side[r - 4];
        if (h.col < n) {
          armOf[h.idx] = r <= 7 ? 5 : 4; // upper-left / lower-left
        } else if (h.col >= rowWidths[r] - n) {
          armOf[h.idx] = r <= 7 ? 1 : 2; // upper-right / lower-right
        }
      }
    }
  }

  void _buildNeighbors() {
    neighbors.addAll(List.generate(holes.length, (_) => <int>[]));
    for (int i = 0; i < holes.length; i++) {
      for (int j = i + 1; j < holes.length; j++) {
        final dx = holes[i].x - holes[j].x;
        final dyy = holes[i].y - holes[j].y;
        final d = sqrt(dx * dx + dyy * dyy);
        if (d > 0.9 && d < 1.12) {
          neighbors[i].add(j);
          neighbors[j].add(i);
        }
      }
    }
  }

  /// Holes of arm [arm] (10 holes).
  List<int> armHoles(int arm) =>
      [for (final h in holes) if (armOf[h.idx] == arm) h.idx];

  /// Landing hole when hopping from [from] over [over]: the hole mirrored
  /// across [over], or -1 if it is not a board hole.
  int hopLanding(int from, int over) {
    final f = holes[from], o = holes[over];
    final lx = 2 * o.x - f.x;
    final ly = 2 * o.y - f.y;
    for (final h in holes) {
      final dx = h.x - lx, dyy = h.y - ly;
      if (dx * dx + dyy * dyy < 0.04) return h.idx;
    }
    return -1;
  }

  /// Unit-ish direction from a seat's start arm toward its destination arm,
  /// used to measure forward progress.
  Offset2 destDir(int seatArm) {
    const deg = {
      0: -90.0, // top -> bottom
      1: 150.0, // upper-right -> lower-left
      2: 30.0, // lower-right -> upper-left  (dest arm 5)
      3: 90.0, // bottom -> top
      4: -30.0, // lower-left -> upper-right (dest arm 1)
      5: -150.0, // upper-left -> lower-right (dest arm 2)
    };
    final a = deg[seatArm]! * pi / 180.0;
    return Offset2(cos(a), sin(a));
  }

  /// Forward-progress coordinate of a hole for the seat starting at [seatArm].
  double progressOf(int holeIdx, int seatArm) {
    final h = holes[holeIdx];
    final d = destDir(seatArm);
    return h.x * d.dx + h.y * d.dy;
  }
}

class Hole {
  final int row, col, idx;
  final double x, y; // spacing units
  const Hole({required this.row, required this.col, required this.idx, required this.x, required this.y});
}

class Offset2 {
  final double dx, dy;
  const Offset2(this.dx, this.dy);
}
