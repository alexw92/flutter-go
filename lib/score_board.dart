import 'package:go/main.dart';
import 'package:flutter/material.dart';

class ScoreDisplay extends StatelessWidget {
  final List<List<Stone?>> board;
  ScoreDisplay(this.board);

  Map<Stone, int> calculateScore() {
    int black = 0;
    int white = 0;
    for (var row in board) {
      for (var cell in row) {
        if (cell == Stone.black) black++;
        if (cell == Stone.white) white++;
      }
    }
    return {Stone.black: black, Stone.white: white};
  }

  @override
  Widget build(BuildContext context) {
    final score = calculateScore();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Black: ${score[Stone.black]}', style: TextStyle(fontSize: 16)),
        SizedBox(width: 20),
        Text('White: ${score[Stone.white]}', style: TextStyle(fontSize: 16)),
      ],
    );
  }
}
