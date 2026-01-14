import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class ChartGenerationService {
  LineChartData? generateLineChartFromExpression(String expressionText) {
    try {
      final cleanExpression = expressionText.replaceAll('y =', '').trim();
      Parser p = Parser();
      Expression exp = p.parse(cleanExpression);
      ContextModel cm = ContextModel();

      final List<FlSpot> spots = [];
      for (double x = -10; x <= 10; x += 0.5) {
        cm.bindVariableName('x', Number(x));
        final double y = exp.evaluate(EvaluationType.REAL, cm);
        if (y.isFinite) {
          spots.add(FlSpot(x, y));
        }
      }

      if (spots.isEmpty) return null;

      return LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      );
    } catch (e) {
      print('Error generating chart: $e');
      return null;
    }
  }
}
