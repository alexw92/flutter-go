import 'package:flutter/material.dart';
import 'package:go/score_board.dart';
import 'dart:math';
import 'go_ai.dart';
import 'go_utils.dart';

void main() => runApp(GoApp());

class GoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Game 9x9',
      home: Scaffold(
        appBar: AppBar(title: Text('Go Game (9x9)')),
        body: GoBoardPage(),
      ),
    );
  }
}

enum Stone { black, white }

class CapturedStone {
  final int row;
  final int col;
  final Stone color;
  CapturedStone(this.row, this.col, this.color);
}

class GoBoardPage extends StatefulWidget {
  @override
  _GoBoardPageState createState() => _GoBoardPageState();
}

class _GoBoardPageState extends State<GoBoardPage>
    with TickerProviderStateMixin {
  static const int boardSize = 9;
  List<List<Stone?>> board = List.generate(
      boardSize, (_) => List.filled(boardSize, null, growable: false),
      growable: false);
  Stone currentTurn = Stone.black;
  final List<List<int>> directions = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  List<CapturedStone> captured = [];
  Set<int> previousBoardHashes = {};
  GoAI selectedAI = AIBrutus();
  String selectedAIName = 'AIBrutus';
  bool showHelper = false;

  void handleTap(int row, int col) {
    if (!isValidMoveWithKo(
        board, row, col, currentTurn, directions, previousBoardHashes)) return;

    setState(() {
      board[row][col] = currentTurn;
      removeCapturedStones(row, col, currentTurn);
      previousBoardHashes.add(hashBoard(board));
      currentTurn = Stone.white;
    });

    if (currentTurn == Stone.white) {
      Future.delayed(Duration(milliseconds: 500), () async {
        final aiMove = await selectedAI.getMove(
            board, Stone.white, directions, previousBoardHashes);
        if (!aiMove.isPass &&
            isValidMoveWithKo(board, aiMove.move!.x, aiMove.move!.y,
                Stone.white, directions, previousBoardHashes)) {
          setState(() {
            board[aiMove.move!.x][aiMove.move!.y] = Stone.white;
            removeCapturedStones(aiMove.move!.x, aiMove.move!.y, Stone.white);
            previousBoardHashes.add(hashBoard(board));
            currentTurn = Stone.black;
          });
        } else {
          setState(() {
            currentTurn = Stone.black; // pass turn if no move
          });
          if (aiMove.surrender) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('${selectedAI.runtimeType} has surrendered! 🎉')),
            );
            // surrendered
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${selectedAI.runtimeType} has passed! ')),
            );
            // pass but not surrendered
            return;
          }
        }
      });
    }
  }

  void removeCapturedStones(int row, int col, Stone player) {
    final enemy = player == Stone.black ? Stone.white : Stone.black;
    Set<Point<int>> toRemove = {};

    for (var d in directions) {
      int r = row + d[0], c = col + d[1];
      if (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
        if (board[r][c] == enemy &&
            countLiberties(board, r, c, enemy, {}, directions) == 0) {
          collectGroup(r, c, enemy, toRemove);
        }
      }
    }

    for (var p in toRemove) {
      captured.add(CapturedStone(p.x, p.y, board[p.x][p.y]!));
    }

    Future.delayed(Duration(milliseconds: 300), () {
      setState(() {
        for (var p in toRemove) {
          board[p.x][p.y] = null;
        }
        captured.clear();
      });
    });
  }

  void collectGroup(int row, int col, Stone? color, Set<Point<int>> out) {
    Set<Point<int>> visited = {};
    void dfs(int r, int c) {
      if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) return;
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

  void resetGame(GoAI newAI, String aiName) {
    setState(() {
      board = List.generate(boardSize, (_) => List.filled(boardSize, null));
      currentTurn = Stone.black;
      previousBoardHashes.clear();
      selectedAI = newAI;
      selectedAIName = aiName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("AI: $selectedAIName", style: TextStyle(fontSize: 16)),
              SizedBox(width: 20),
              DropdownButton<String>(
                value: selectedAIName,
                onChanged: (value) {
                  if (value == 'AIPotato') {
                    resetGame(AIPotato(), 'AIPotato');
                  } else if (value == 'AIYamcha') {
                    resetGame(AIYamcha(), 'AIYamcha');
                  } else if (value == 'AIFortress') {
                    resetGame(AIFortress(), 'AIFortress');
                  } else if (value == 'AIBrutus') {
                    resetGame(AIBrutus(), 'AIBrutus');
                  }
                },
                items: ['AIPotato', 'AIYamcha', 'AIFortress', 'AIBrutus']
                    .map((name) => DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        ))
                    .toList(),
              ),
              SizedBox(width: 20),
              Row(
                children: [
                  Text("Helper"),
                  Switch(
                    value: showHelper,
                    onChanged: (value) {
                      setState(() {
                        showHelper = value;
                      });
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        ScoreDisplay(board),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                double cellSize = constraints.maxWidth / boardSize;
                return GestureDetector(
                  onTapUp: (details) {
                    final RenderBox box =
                        context.findRenderObject() as RenderBox;
                    final Offset local =
                        box.globalToLocal(details.globalPosition);
                    int row = (local.dy / cellSize).floor();
                    int col = (local.dx / cellSize).floor();
                    if (row >= 0 &&
                        row < boardSize &&
                        col >= 0 &&
                        col < boardSize) {
                      handleTap(row, col);
                    }
                  },
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxWidth),
                        painter: GoBoardPainter(board, showHelper),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class GoBoardPainter extends CustomPainter {
  final List<List<Stone?>> board;
  final bool showHelper;
  GoBoardPainter(this.board, this.showHelper);

  @override
  void paint(Canvas canvas, Size size) {
    double cellSize = size.width / board.length;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < board.length; i++) {
      double offset = i * cellSize + cellSize / 2;
      canvas.drawLine(Offset(cellSize / 2, offset),
          Offset(size.width - cellSize / 2, offset), paint);
      canvas.drawLine(Offset(offset, cellSize / 2),
          Offset(offset, size.height - cellSize / 2), paint);
    }

    final Map<Stone, Set<Point<int>>> indestructibleClusters = {
      Stone.black: {},
      Stone.white: {},
    };

    if (showHelper) {
      final visited = <Point<int>>{};
      for (int r = 0; r < board.length; r++) {
        for (int c = 0; c < board.length; c++) {
          final p = Point(r, c);
          final color = board[r][c];
          if (color != null && !visited.contains(p)) {
            final group = <Point<int>>{};
            collectGroupStatic(board, r, c, color, group, [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1]
            ]);
            visited.addAll(group);

            final liberties = <Point<int>>{};
            for (var g in group) {
              for (var d in [
                [-1, 0],
                [1, 0],
                [0, -1],
                [0, 1]
              ]) {
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

            // Indestructible if ALL liberties are surrounded only by the same group
            bool allEyes = liberties.every((eye) {
              for (var d in [
                [-1, 0],
                [1, 0],
                [0, -1],
                [0, 1]
              ]) {
                final adj = Point(eye.x + d[0], eye.y + d[1]);
                if (adj.x < 0 ||
                    adj.y < 0 ||
                    adj.x >= board.length ||
                    adj.y >= board.length) continue;
                if (!group.contains(adj) && board[adj.x][adj.y] != color) {
                  return false;
                }
              }
              return true;
            });

            if (allEyes && liberties.length >= 2) {
              indestructibleClusters[color]!.addAll(group);
            }
          }
        }
      }
    }

    for (int row = 0; row < board.length; row++) {
      for (int col = 0; col < board.length; col++) {
        if (board[row][col] != null) {
          final stonePaint = Paint()
            ..color =
                board[row][col] == Stone.black ? Colors.black : Colors.white;
          Offset center = Offset(
            col * cellSize + cellSize / 2,
            row * cellSize + cellSize / 2,
          );
          canvas.drawCircle(center, cellSize * 0.4, stonePaint);
          if (board[row][col] == Stone.white) {
            final borderPaint = Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5;
            canvas.drawCircle(center, cellSize * 0.4, borderPaint);
          }
          if (showHelper &&
              indestructibleClusters[board[row][col]]!
                  .contains(Point(row, col))) {
            final dotPaint = Paint()
              ..color =
                  board[row][col] == Stone.black ? Colors.green : Colors.red
              ..style = PaintingStyle.fill;
            canvas.drawCircle(center, cellSize * 0.1, dotPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
