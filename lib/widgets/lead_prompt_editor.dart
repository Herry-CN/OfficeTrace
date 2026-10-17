import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/lead/lead_prompt_pack.dart';

/// 分类说明、分类提示词、提取提示词。设置页与群监控共用。
class LeadPromptEditor extends StatefulWidget {
  const LeadPromptEditor({
    super.key,
    required this.pack,
    required this.onSave,
    this.onChanged,
  });

  final LeadPromptPack pack;
  final Future<void> Function(LeadPromptPack pack) onSave;
  final ValueChanged<LeadPromptPack>? onChanged;

  @override
  State<LeadPromptEditor> createState() => _LeadPromptEditorState();
}

class _LeadPromptEditorState extends State<LeadPromptEditor> {
  late final TextEditingController _categories;
  late final TextEditingController _classification;
  late final TextEditingController _extraction;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categories = TextEditingController(text: widget.pack.categories);
    _classification =
        TextEditingController(text: widget.pack.classificationPrompt);
    _extraction = TextEditingController(text: widget.pack.extractionPrompt);
    for (final controller in [_categories, _classification, _extraction]) {
      controller.addListener(_notifyChanged);
    }
  }

  @override
  void didUpdateWidget(LeadPromptEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pack == oldWidget.pack) return;
    _setIfDifferent(_categories, widget.pack.categories);
    _setIfDifferent(_classification, widget.pack.classificationPrompt);
    _setIfDifferent(_extraction, widget.pack.extractionPrompt);
  }

  @override
  void dispose() {
    for (final controller in [_categories, _classification, _extraction]) {
      controller.removeListener(_notifyChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _setIfDifferent(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.text = text;
  }

  LeadPromptPack _currentPack() {
    return LeadPromptPack(
      categories: _categories.text,
      classificationPrompt: _classification.text,
      extractionPrompt: _extraction.text,
    );
  }

  void _notifyChanged() {
    widget.onChanged?.call(_currentPack());
  }

  Future<void> _save(LeadPromptPack pack) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(pack);
      if (!mounted) return;
      _message('提示词已保存');
    } catch (e) {
      if (!mounted) return;
      _message('保存提示词失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出商机提示词',
        fileName: 'leadtrace-prompts.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (path == null || !mounted) return;
      final file = File(path.endsWith('.json') ? path : '$path.json');
      await file.writeAsString(
        _currentPack().encodeExport(),
        encoding: utf8,
      );
      if (!mounted) return;
      _message('提示词已导出');
    } catch (e) {
      if (!mounted) return;
      _message('导出提示词失败: $e');
    }
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入商机提示词',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      final String raw;
      if (file.bytes != null) {
        raw = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        raw = await File(file.path!).readAsString(encoding: utf8);
      } else {
        return;
      }
      final imported = LeadPromptPack.parseImport(raw);
      _categories.text = imported.categories;
      _classification.text = imported.classificationPrompt;
      _extraction.text = imported.extractionPrompt;
      await _save(imported);
    } on FormatException catch (e) {
      if (!mounted) return;
      _message(e.message);
    } catch (e) {
      if (!mounted) return;
      _message('导入提示词失败: $e');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('分类与提示词在「设置 → 商机 AI 配置」和「群监控」之间同步。留空保存会恢复内置默认。', style: hint),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('lead-prompt-categories'),
          controller: _categories,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '分类说明',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('lead-prompt-classification'),
          controller: _classification,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '分类提示词',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('lead-prompt-extraction'),
          controller: _extraction,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '提取提示词',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _saving ? null : () => _save(_currentPack()),
              child: const Text('保存提示词'),
            ),
            OutlinedButton(
              onPressed: _saving ? null : _import,
              child: const Text('导入'),
            ),
            OutlinedButton(
              onPressed: _saving ? null : _export,
              child: const Text('导出'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      _categories.text = LeadPromptPack.defaultCategories;
                      _classification.text =
                          LeadPromptPack.defaultClassificationPrompt;
                      _extraction.text = LeadPromptPack.defaultExtractionPrompt;
                      _save(LeadPromptPack.defaults);
                    },
              child: const Text('恢复默认'),
            ),
          ],
        ),
      ],
    );
  }
}
