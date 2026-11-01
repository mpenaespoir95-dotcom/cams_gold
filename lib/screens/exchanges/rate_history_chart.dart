import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/exchange_rate_history.dart';

class RateHistoryChart extends StatelessWidget {
  const RateHistoryChart({
    super.key,
    required this.points,
    required this.fromCurrency,
    required this.toCurrency,
    required this.period,
  });

  final List<ExchangeRateHistoryPoint> points;
  final String fromCurrency;
  final String toCurrency;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = now.subtract(period);
    final values = points
        .where(
          (point) =>
              point.observedAt.isAfter(start) && !point.observedAt.isAfter(now),
        )
        .map((point) {
          final rate = point.rate(fromCurrency, toCurrency);
          return rate == null ? null : _ChartValue(point.observedAt, rate);
        })
        .whereType<_ChartValue>()
        .toList();

    if (values.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'Aucun relevé pour cette période. Revenez après une mise à jour.',
          ),
        ),
      );
    }

    return SizedBox(
      height: 280,
      width: double.infinity,
      child: CustomPaint(
        painter: _RateChartPainter(
          values: values,
          start: start,
          end: now,
          period: period,
          textDirection: Directionality.of(context),
          textStyle: Theme.of(context).textTheme.bodySmall!,
        ),
      ),
    );
  }
}

class _ChartValue {
  const _ChartValue(this.time, this.rate);

  final DateTime time;
  final double rate;
}

class _RateChartPainter extends CustomPainter {
  const _RateChartPainter({
    required this.values,
    required this.start,
    required this.end,
    required this.period,
    required this.textDirection,
    required this.textStyle,
  });

  final List<_ChartValue> values;
  final DateTime start;
  final DateTime end;
  final Duration period;
  final TextDirection textDirection;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 62.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 38.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final rates = values.map((value) => value.rate);
    var minRate = rates.reduce(math.min);
    var maxRate = rates.reduce(math.max);
    if (minRate == maxRate) {
      final padding = minRate.abs() * 0.02;
      minRate -= padding == 0 ? 1 : padding;
      maxRate += padding == 0 ? 1 : padding;
    } else {
      final padding = (maxRate - minRate) * 0.12;
      minRate -= padding;
      maxRate += padding;
    }

    final gridPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final fraction = i / 4;
      final y = plot.top + plot.height * fraction;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawText(
        canvas,
        (maxRate - (maxRate - minRate) * fraction).toStringAsFixed(2),
        Offset(0, y - 8),
        width: left - 8,
        align: TextAlign.right,
      );
    }

    final span = end.difference(start).inMilliseconds;
    final line = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final timeFraction = span == 0
          ? 1.0
          : value.time.difference(start).inMilliseconds / span;
      final rateFraction = (value.rate - minRate) / (maxRate - minRate);
      final point = Offset(
        plot.left + plot.width * timeFraction.clamp(0.0, 1.0),
        plot.bottom - plot.height * rateFraction,
      );
      points.add(point);
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    if (points.length == 1) {
      canvas.drawLine(
        Offset(plot.left, points.single.dy),
        Offset(plot.right, points.single.dy),
        Paint()
          ..color = AppTheme.gold.withValues(alpha: 0.45)
          ..strokeWidth = 2,
      );
    } else {
      canvas.drawPath(
        line,
        Paint()
          ..color = AppTheme.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = AppTheme.gold);
      canvas.drawCircle(point, 2, Paint()..color = AppTheme.forest);
    }

    _drawText(
      canvas,
      _timeLabel(values.first.time),
      Offset(plot.left, plot.bottom + 8),
      width: plot.width / 2,
    );
    _drawText(
      canvas,
      _timeLabel(values.last.time),
      Offset(plot.center.dx, plot.bottom + 8),
      width: plot.width / 2,
      align: TextAlign.right,
    );
  }

  String _timeLabel(DateTime time) {
    if (period <= const Duration(hours: 24)) {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')}';
  }

  void _drawText(
    Canvas canvas,
    String value,
    Offset offset, {
    required double width,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: textStyle.copyWith(color: AppTheme.muted, fontSize: 10),
      ),
      textDirection: textDirection,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RateChartPainter oldDelegate) =>
      values != oldDelegate.values ||
      start != oldDelegate.start ||
      end != oldDelegate.end ||
      period != oldDelegate.period;
}
