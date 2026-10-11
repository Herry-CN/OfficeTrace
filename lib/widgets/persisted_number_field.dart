import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 数字输入框：有效数字会立即提交，失焦时把非法输入收回已保存的值。
///
/// 编辑过程中不根据外部值重写文本，避免输入「72」时被刷新成「7」。
class PersistedNumberField extends StatefulWidget {
  const PersistedNumberField({
    super.key,
    required this.value,
    required this.onCommit,
    this.min = 1,
    this.max = 999999,
    this.decoration = const InputDecoration.collapsed(hintText: ''),
  });

  final int value;
  final ValueChanged<int> onCommit;
  final int min;
  final int max;
  final InputDecoration decoration;

  @override
  State<PersistedNumberField> createState() => _PersistedNumberFieldState();
}

class _PersistedNumberFieldState extends State<PersistedNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  int? _lastCommitted;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus = FocusNode();
    _lastCommitted = widget.value;
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PersistedNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focus.hasFocus) return;
    final text = '${widget.value}';
    if (_controller.text != text) {
      _controller.text = text;
      _lastCommitted = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) return;
    _commitCurrent();
  }

  void _commitCurrent() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = '${widget.value}';
      _lastCommitted = widget.value;
      return;
    }
    final clamped = parsed.clamp(widget.min, widget.max);
    if (_controller.text.trim() != '$clamped') {
      _controller.text = '$clamped';
    }
    _commit(clamped);
  }

  void _onChanged(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    if (parsed < widget.min || parsed > widget.max) return;
    _commit(parsed);
  }

  void _commit(int value) {
    if (_lastCommitted == value) return;
    _lastCommitted = value;
    widget.onCommit(value);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      decoration: widget.decoration,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: _onChanged,
      onFieldSubmitted: (_) => _commitCurrent(),
    );
  }
}
