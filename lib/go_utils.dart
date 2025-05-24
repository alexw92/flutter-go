import 'dart:math';
import 'main.dart'; // for Stone enum

bool isValidMoveWithKo(
  List<List<Stone?>> board,
  int row,
  int col,
  Stone player,
  List<List<int>> directions,
  Set<int> previousBoardHashes,
) {
  if (board[row][col] != null) return false;

  // Clone the board
  List<List<Stone?>> tempBoard =
      board.map((row) => row.map((stone) => stone).toList()).toList();

  tempBoard[row][col] = player;

  // Simulate captures
  final enemy = player == Stone.black ? Stone.white : Stone.black;
  for (var d in directions) {
    int r = row + d[0], c = col + d[1];
    if (r >= 0 && r < board.length && c >= 0 && c < board.length) {
      if (tempBoard[r][c] == enemy &&
          countLiberties(tempBoard, r, c, enemy, {}, directions) == 0) {
        removeGroup(tempBoard, r, c, enemy, directions);
      }
    }
  }

  // Suicide check
  if (countLiberties(tempBoard, row, col, player, {}, directions) == 0) {
    return false;
  }

  // Ko rule check
  int tempHash = hashBoard(tempBoard);
  return !previousBoardHashes.contains(tempHash);
}

int hashBoard(List<List<Stone?>> board) {
  final flat = <int>[];
  for (var row in board) {
    for (var cell in row) {
      flat.add(cell == null ? 0 : (cell == Stone.black ? 1 : 2));
    }
  }
  return Object.hashAll(flat);
}

void removeGroup(
  List<List<Stone?>> board,
  int row,
  int col,
  Stone? color,
  List<List<int>> directions,
) {
  final visited = <Point<int>>{};
  void dfs(int r, int c) {
    if (r < 0 || r >= board.length || c < 0 || c >= board.length) return;
    if (board[r][c] != color) return;
    final p = Point(r, c);
    if (visited.contains(p)) return;
    visited.add(p);
    board[r][c] = null;
    for (var d in directions) {
      dfs(r + d[0], c + d[1]);
    }
  }

  dfs(row, col);
}

int countLiberties(
  List<List<Stone?>> board,
  int row,
  int col,
  Stone? color,
  Set<Point<int>> visited,
  List<List<int>> directions,
) {
  if (visited.contains(Point(row, col))) return 0;
  visited.add(Point(row, col));

  int liberties = 0;

  for (var d in directions) {
    int r = row + d[0], c = col + d[1];
    if (r < 0 || r >= board.length || c < 0 || c >= board.length) continue;

    if (board[r][c] == null) {
      liberties++;
    } else if (board[r][c] == color) {
      liberties += countLiberties(board, r, c, color, visited, directions);
    }
  }

  return liberties;
}

bool isFortifiedGroup(
  List<List<Stone?>> board,
  Set<Point<int>> group,
  Stone color,
  List<List<int>> directions,
) {
  final liberties = <Point<int>>{};
  for (var p in group) {
    for (var d in directions) {
      int nr = p.x + d[0], nc = p.y + d[1];
      if (nr >= 0 && nr < board.length && nc >= 0 && nc < board.length) {
        if (board[nr][nc] == null) {
          liberties.add(Point(nr, nc));
        }
      }
    }
  }
  return liberties.length >= 2;
}

void collectGroupStatic(
  List<List<Stone?>> board,
  int row,
  int col,
  Stone? color,
  Set<Point<int>> out,
  List<List<int>> directions,
) {
  Set<Point<int>> visited = {};
  void dfs(int r, int c) {
    if (r < 0 || r >= board.length || c < 0 || c >= board.length) return;
    if (board[r][c] != color) return;
    final point = Point(r, c);
    if (visited.contains(point)) return;
    visited.add(point);
    out.add(point);
    for (var d in directions) {
      dfs(r + d[0], c + d[1]);
    }
  }

  dfs(row, col);
}

class GoDecision {
  final Point<int>? move;
  final bool isPass;
  final bool surrender;

  GoDecision._(this.move, this.isPass, this.surrender);

  factory GoDecision.move(Point<int> move) => GoDecision._(move, false, false);
  factory GoDecision.pass() => GoDecision._(null, true, false);
  factory GoDecision.surrender() => GoDecision._(null, false, true);
}
