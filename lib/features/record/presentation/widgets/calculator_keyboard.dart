import 'package:flutter/material.dart';

/// Calculator keyboard widget for amount input.
class CalculatorKeyboard extends StatefulWidget {
  final ValueChanged<double> onValueChanged;
  final VoidCallback onDone;

  const CalculatorKeyboard({
    super.key,
    required this.onValueChanged,
    required this.onDone,
  });

  @override
  State<CalculatorKeyboard> createState() => _CalculatorKeyboardState();
}

class _CalculatorKeyboardState extends State<CalculatorKeyboard> {
  String _expression = '';
  String _display = '0';

  void _onKey(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _expression = '';
          _display = '0';
          widget.onValueChanged(0);
        case '⌫':
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
            _display = _expression.isEmpty ? '0' : _expression;
            final result = _evaluate(_expression);
            widget.onValueChanged(result ?? 0);
          }
        case '=':
          final result = _evaluate(_expression);
          if (result != null) {
            _display = _formatResult(result);
            _expression = _display;
            widget.onValueChanged(result);
          }
        case '.':
          // Prevent multiple decimal points in current number
          final lastNumber = _getLastNumber();
          if (!lastNumber.contains('.')) {
            if (_expression.isEmpty ||
                _isOperator(_expression[_expression.length - 1])) {
              _expression += '0.';
            } else {
              _expression += '.';
            }
            _display = _expression;
          }
        case '+':
        case '-':
        case '×':
        case '÷':
          if (_expression.isNotEmpty &&
              !_isOperator(_expression[_expression.length - 1])) {
            // Evaluate current expression first, then append operator
            final result = _evaluate(_expression);
            if (result != null) {
              widget.onValueChanged(result);
            }
            _expression += key;
            _display = _expression;
          }
        case '完成':
          final result = _evaluate(_expression);
          if (result != null && result > 0) {
            widget.onValueChanged(result);
            widget.onDone();
          }
        default:
          // Digit
          if (_expression == '0' && key == '0') return;
          if (_expression == '0' && key != '0') {
            _expression = key;
          } else {
            _expression += key;
          }
          _display = _expression;
          // Try to evaluate as we type
          final result = _evaluate(_expression);
          if (result != null) {
            widget.onValueChanged(result);
          }
      }
    });
  }

  String _getLastNumber() {
    final pattern = RegExp(r'[\+\-×÷]');
    final parts = _expression.split(pattern);
    return parts.isEmpty ? '' : parts.last;
  }

  bool _isOperator(String ch) {
    return ch == '+' || ch == '-' || ch == '×' || ch == '÷';
  }

  double? _evaluate(String expr) {
    if (expr.isEmpty) return null;
    // Remove trailing operator
    var e = expr;
    while (e.isNotEmpty && _isOperator(e[e.length - 1])) {
      e = e.substring(0, e.length - 1);
    }
    if (e.isEmpty) return null;

    try {
      // Tokenize
      final tokens = <String>[];
      var current = '';
      for (int i = 0; i < e.length; i++) {
        final ch = e[i];
        if (_isOperator(ch)) {
          if (current.isNotEmpty) tokens.add(current);
          tokens.add(ch);
          current = '';
        } else {
          current += ch;
        }
      }
      if (current.isNotEmpty) tokens.add(current);

      // Evaluate left-to-right (simple chain, no precedence)
      if (tokens.isEmpty) return null;
      double result = double.tryParse(tokens[0]) ?? 0;
      for (int i = 1; i < tokens.length - 1; i += 2) {
        final op = tokens[i];
        final val = double.tryParse(tokens[i + 1]) ?? 0;
        switch (op) {
          case '+':
            result += val;
          case '-':
            result -= val;
          case '×':
            result *= val;
          case '÷':
            if (val != 0) result /= val;
        }
      }
      // Round to 2 decimal places
      return double.parse(result.toStringAsFixed(2));
    } catch (_) {
      return null;
    }
  }

  String _formatResult(double value) {
    if (value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _display,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium,
            ),
          ),
          // Keyboard grid
          _buildRow(['7', '8', '9', '+'], theme),
          _buildRow(['4', '5', '6', '-'], theme),
          _buildRow(['1', '2', '3', '×'], theme),
          _buildRow(['.', '0', '⌫', '÷'], theme),
          _buildRow(['C', '=', '完成', ''], theme, isLast: true),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys, ThemeData theme, {bool isLast = false}) {
    return Row(
      children: keys.map((key) {
        if (key.isEmpty) return const Expanded(child: SizedBox());

        final isOperator = _isOperator(key);
        final isDone = key == '完成';
        final isEquals = key == '=';
        final isClear = key == 'C';

        Color? bgColor;
        Color? fgColor;
        if (isDone) {
          bgColor = theme.colorScheme.primary;
          fgColor = theme.colorScheme.onPrimary;
        } else if (isOperator || isEquals) {
          bgColor = theme.colorScheme.primaryContainer;
          fgColor = theme.colorScheme.onPrimaryContainer;
        } else if (isClear) {
          bgColor = theme.colorScheme.errorContainer;
          fgColor = theme.colorScheme.onErrorContainer;
        }

        return Expanded(
          flex: isDone ? 2 : 1,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: bgColor ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: key.isEmpty ? null : () => _onKey(key),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: key == '⌫'
                      ? Icon(Icons.backspace_outlined, size: 20, color: fgColor)
                      : Text(
                          key,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
