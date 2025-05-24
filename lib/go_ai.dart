import 'dart:math';
import 'main.dart';
import 'go_utils.dart';

// Returns the total number of indestructible enemy stones.
// "Indestructible" means: part of a group with at least 2 real eyes.
int countEnemyIndestructibleStones(
  List<List<Stone?>> board,
  Stone enemy,
  List<List<int>> directions,
) {
  int enemyIndestructibleCount = 0;
  final visited = <Point<int>>{};

  for (int r = 0; r < board.length; r++) {
    for (int c = 0; c < board[r].length; c++) {
      final p = Point(r, c);
      if (board[r][c] == enemy && !visited.contains(p)) {
        final group = <Point<int>>{};
        final liberties = <Point<int>>{};
        getGroupAndLiberties(board, r, c, enemy, group, liberties, directions);
        visited.addAll(group);
        bool allEyes = liberties.isNotEmpty &&
            liberties.every((eye) {
              for (var d in directions) {
                final adj = Point(eye.x + d[0], eye.y + d[1]);
                if (adj.x < 0 ||
                    adj.y < 0 ||
                    adj.x >= board.length ||
                    adj.y >= board.length) continue;
                if (!group.contains(adj) && board[adj.x][adj.y] != enemy) {
                  return false;
                }
              }
              return true;
            });
        if (allEyes && liberties.length >= 2) {
          enemyIndestructibleCount += group.length;
        }
      }
    }
  }
  return enemyIndestructibleCount;
}

Set<Point<int>> findEyes(
  List<List<Stone?>> board,
  Set<Point<int>> group,
  List<List<int>> directions,
) {
  final eyes = <Point<int>>{};

  for (var p in group) {
    for (var d in directions) {
      final nr = p.x + d[0], nc = p.y + d[1];
      final np = Point(nr, nc);

      if (nr < 0 || nr >= board.length || nc < 0 || nc >= board.length) {
        continue;
      }
      if (board[nr][nc] != null) continue;
      if (group.contains(np)) continue;

      bool surroundedByGroup = true;
      for (var dd in directions) {
        int ar = nr + dd[0], ac = nc + dd[1];
        if (ar < 0 || ar >= board.length || ac < 0 || ac >= board.length) {
          continue;
        }
        final neighbor = board[ar][ac];
        if (neighbor == null || !group.contains(Point(ar, ac))) {
          surroundedByGroup = false;
          break;
        }
      }

      if (surroundedByGroup) {
        eyes.add(np);
      }
    }
  }

  return eyes;
}

// Populates group and its liberties starting at (r, c)
void getGroupAndLiberties(
  List<List<Stone?>> board,
  int r,
  int c,
  Stone color,
  Set<Point<int>> group,
  Set<Point<int>> liberties,
  List<List<int>> directions,
) {
  collectGroupStatic(board, r, c, color, group, directions);
  for (var g in group) {
    for (var d in directions) {
      final np = Point(g.x + d[0], g.y + d[1]);
      if (np.x >= 0 &&
          np.y >= 0 &&
          np.x < board.length &&
          np.y < board.length &&
          board[np.x][np.y] == null) {
        liberties.add(np);
      }
    }
  }
}

// Whether the AI should surrender, given enemy indestructible count
bool shouldSurrender(int enemyIndestructibleCount, int boardSize) {
  return enemyIndestructibleCount > (boardSize * boardSize) ~/ 2;
}

// Get all eyes to avoid (i.e. do not play inside your own real eyes)
Set<Point<int>> getEyesToAvoid(
  List<List<Stone?>> board,
  Stone color,
  List<List<int>> directions,
) {
  final eyesToAvoid = <Point<int>>{};
  final visited = <Point<int>>{};
  for (int r = 0; r < board.length; r++) {
    for (int c = 0; c < board[r].length; c++) {
      final p = Point(r, c);
      if (board[r][c] == color && !visited.contains(p)) {
        final group = <Point<int>>{};
        collectGroupStatic(board, r, c, color, group, directions);
        visited.addAll(group);
        final liberties = <Point<int>>{};
        for (var g in group) {
          for (var d in directions) {
            int nx = g.x + d[0], ny = g.y + d[1];
            if (nx >= 0 && ny >= 0 && nx < board.length && ny < board.length) {
              if (board[nx][ny] == null) {
                liberties.add(Point(nx, ny));
              }
            }
          }
        }
        if (liberties.length >= 2) {
          eyesToAvoid.addAll(findEyes(board, group, directions));
        }
      }
    }
  }
  return eyesToAvoid;
}

// ========== AI CLASSES ==========

abstract class GoAI {
  Future<GoDecision> getMove(
    List<List<Stone?>> board,
    Stone aiColor,
    List<List<int>> directions,
    Set<int> prevHashes,
  );
}

class AIPotato implements GoAI {
  final Random _random = Random();

  @override
  Future<GoDecision> getMove(
    List<List<Stone?>> board,
    Stone aiColor,
    List<List<int>> directions,
    Set<int> prevHashes,
  ) async {
    final enemy = aiColor == Stone.black ? Stone.white : Stone.black;
    final validMoves = <Point<int>>[];

    int enemyIndestructibleCount =
        countEnemyIndestructibleStones(board, enemy, directions);

    if (shouldSurrender(enemyIndestructibleCount, board.length)) {
      return GoDecision.surrender();
    }

    for (int r = 0; r < board.length; r++) {
      for (int c = 0; c < board[r].length; c++) {
        if (isValidMoveWithKo(board, r, c, aiColor, directions, prevHashes)) {
          validMoves.add(Point(r, c));
        }
      }
    }

    if (validMoves.isEmpty) return GoDecision.pass();

    return GoDecision.move(validMoves[_random.nextInt(validMoves.length)]);
  }
}

class AIYamcha implements GoAI {
  final Random _random = Random();

  @override
  Future<GoDecision> getMove(
    List<List<Stone?>> board,
    Stone aiColor,
    List<List<int>> directions,
    Set<int> prevHashes,
  ) async {
    final enemy = aiColor == Stone.black ? Stone.white : Stone.black;
    final captureMoves = <Point<int>>[];
    final legalMoves = <Point<int>>[];

    int enemyIndestructibleCount =
        countEnemyIndestructibleStones(board, enemy, directions);

    if (shouldSurrender(enemyIndestructibleCount, board.length)) {
      return GoDecision.surrender();
    }

    for (int r = 0; r < board.length; r++) {
      for (int c = 0; c < board[r].length; c++) {
        if (!isValidMoveWithKo(board, r, c, aiColor, directions, prevHashes)) {
          continue;
        }

        final p = Point(r, c);
        legalMoves.add(p);

        for (var d in directions) {
          int nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= board.length || nc < 0 || nc >= board.length) {
            continue;
          }
          if (board[nr][nc] == enemy &&
              countLiberties(board, nr, nc, enemy, {}, directions) == 1) {
            captureMoves.add(p);
            break;
          }
        }
      }
    }

    if (captureMoves.isNotEmpty) {
      return GoDecision.move(
          captureMoves[_random.nextInt(captureMoves.length)]);
    }
    if (legalMoves.isNotEmpty) {
      return GoDecision.move(legalMoves[_random.nextInt(legalMoves.length)]);
    }
    return GoDecision.pass();
  }
}

class AIFortress implements GoAI {
  final Random _random = Random();

  @override
  Future<GoDecision> getMove(
    List<List<Stone?>> board,
    Stone aiColor,
    List<List<int>> directions,
    Set<int> prevHashes,
  ) async {
    final enemy = aiColor == Stone.black ? Stone.white : Stone.black;
    final legalMoves = <Point<int>>[];
    final prioritizedMoves = <Point<int>>[];
    final eyesToAvoid = getEyesToAvoid(board, aiColor, directions);

    int enemyIndestructibleCount =
        countEnemyIndestructibleStones(board, enemy, directions);

    if (shouldSurrender(enemyIndestructibleCount, board.length)) {
      return GoDecision.surrender();
    }

    for (int r = 0; r < board.length; r++) {
      for (int c = 0; c < board[r].length; c++) {
        final p = Point(r, c);
        if (eyesToAvoid.contains(p)) continue;
        if (!isValidMoveWithKo(board, r, c, aiColor, directions, prevHashes)) {
          continue;
        }

        bool canCapture = false;
        for (var d in directions) {
          int nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= board.length || nc < 0 || nc >= board.length) {
            continue;
          }
          if (board[nr][nc] == enemy &&
              countLiberties(board, nr, nc, enemy, {}, directions) == 1) {
            canCapture = true;
            break;
          }
        }

        if (canCapture) {
          prioritizedMoves.add(p);
        } else {
          legalMoves.add(p);
        }
      }
    }

    if (prioritizedMoves.isNotEmpty) {
      return GoDecision.move(
          prioritizedMoves[_random.nextInt(prioritizedMoves.length)]);
    }
    if (legalMoves.isNotEmpty) {
      return GoDecision.move(legalMoves[_random.nextInt(legalMoves.length)]);
    }
    return GoDecision.pass();
  }
}

class AIBrutus implements GoAI {
  final Random _random = Random();

  @override
  Future<GoDecision> getMove(
    List<List<Stone?>> board,
    Stone aiColor,
    List<List<int>> directions,
    Set<int> prevHashes,
  ) async {
    final enemy = aiColor == Stone.black ? Stone.white : Stone.black;
    final prioritizedMoves = <Point<int>>[];
    final legalMoves = <Point<int>>[];
    final fallbackMoves = <MapEntry<Point<int>, int>>[];
    final eyesToAvoid = getEyesToAvoid(board, aiColor, directions);

    // Surrender logic: count enemy indestructible stones
    int enemyIndestructibleCount =
        countEnemyIndestructibleStones(board, enemy, directions);
    if (shouldSurrender(enemyIndestructibleCount, board.length)) {
      return GoDecision.surrender();
    }

    for (int r = 0; r < board.length; r++) {
      for (int c = 0; c < board[r].length; c++) {
        final p = Point(r, c);
        if (eyesToAvoid.contains(p)) continue;
        if (!isValidMoveWithKo(board, r, c, aiColor, directions, prevHashes)) {
          continue;
        }

        // 1. Prioritize capture moves
        bool canCapture = false;
        for (var d in directions) {
          int nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= board.length || nc < 0 || nc >= board.length) {
            continue;
          }
          if (board[nr][nc] == enemy &&
              countLiberties(board, nr, nc, enemy, {}, directions) == 1) {
            canCapture = true;
            break;
          }
        }
        if (canCapture) {
          prioritizedMoves.add(p);
          continue;
        }

        // 2. Fallback: moves that reduce liberties of enemy groups
        int disruptionScore = 0;
        for (var d in directions) {
          int nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= board.length || nc < 0 || nc >= board.length) {
            continue;
          }
          if (board[nr][nc] == enemy) {
            final group = <Point<int>>{};
            final liberties = <Point<int>>{};
            getGroupAndLiberties(
                board, nr, nc, enemy, group, liberties, directions);
            if (liberties.length <= 3) {
              disruptionScore += (4 - liberties.length);
            }
          }
        }
        if (disruptionScore > 0) {
          fallbackMoves.add(MapEntry(p, disruptionScore));
        } else {
          legalMoves.add(p);
        }
      }
    }

    if (prioritizedMoves.isNotEmpty) {
      return GoDecision.move(
          prioritizedMoves[_random.nextInt(prioritizedMoves.length)]);
    }
    if (fallbackMoves.isNotEmpty) {
      fallbackMoves.sort((a, b) => b.value.compareTo(a.value));
      return GoDecision.move(fallbackMoves.first.key);
    }
    if (legalMoves.isNotEmpty) {
      return GoDecision.move(legalMoves[_random.nextInt(legalMoves.length)]);
    }
    return GoDecision.pass();
  }
}
