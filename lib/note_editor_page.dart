import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'package:drivenotes/features/notes/presentation/providers/note_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class NoteEditorPage extends ConsumerStatefulWidget {
  final NoteModel? originalNote;
  final String? heroTag;

  const NoteEditorPage({super.key, this.originalNote, this.heroTag});

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _submitted = false;
  bool _isDirty = false;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();

  // Text selection controls
  TextSelection? _currentSelection;
  bool _showFormatBar = false;
  final LayerLink _formatBarLink = LayerLink();
  OverlayEntry? _formatBarEntry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    final o = widget.originalNote;
    // Remove .txt extension if present for display
    final title = o?.title.replaceAll(RegExp(r'\.txt$'), '') ?? '';
    _titleCtrl = TextEditingController(text: title);

    // Parse content for bold markers
    final content = o?.content ?? '';
    _contentCtrl = TextEditingController(text: _stripBoldMarkers(content));

    // Listen for changes to mark the note as dirty
    _titleCtrl.addListener(_markDirty);
    _contentCtrl.addListener(_markDirty);

    // Listen for selection changes
    _contentFocus.addListener(_onFocusChange);

    // Auto-focus title if new note
    if (o == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocus.requestFocus();
      });
    }

    _animationController.forward();
  }

  String _stripBoldMarkers(String text) {
    return text.replaceAll('**', '');
  }

  void _onFocusChange() {
    if (!_contentFocus.hasFocus) {
      _hideFormatBar();
    }
  }

  void _hideFormatBar() {
    _formatBarEntry?.remove();
    _formatBarEntry = null;
    setState(() => _showFormatBar = false);
  }

  void _showFormatBarOverlay() {
    _hideFormatBar();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _formatBarEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            left: offset.dx + 16,
            top:
                offset.dy + 120, // Adjust this value to position the format bar
            child: CompositedTransformFollower(
              link: _formatBarLink,
              showWhenUnlinked: false,
              offset: const Offset(0, -50),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.format_bold),
                        onPressed: _toggleBold,
                        tooltip: 'Bold (Ctrl+B)',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_formatBarEntry!);
    setState(() => _showFormatBar = true);
  }

  void _toggleBold() {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    if (selection.isValid && selection.start != selection.end) {
      final selectedText = text.substring(selection.start, selection.end);
      final isBold =
          selectedText.startsWith('**') && selectedText.endsWith('**');

      final newText =
          isBold
              ? text.replaceRange(
                selection.start,
                selection.end,
                selectedText.substring(2, selectedText.length - 2),
              )
              : text.replaceRange(
                selection.start,
                selection.end,
                '**$selectedText**',
              );

      _contentCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start,
          extentOffset: selection.end + (isBold ? -4 : 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    _hideFormatBar();
    super.dispose();
  }

  void _handleKeyCommand(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.isControlPressed &&
          event.logicalKey == LogicalKeyboardKey.keyB) {
        _toggleBold();
      }
    }
  }

  void _onSelectionChanged(TextSelection selection) {
    _currentSelection = selection;
    if (selection.isValid && selection.start != selection.end) {
      _showFormatBarOverlay();
    } else {
      _hideFormatBar();
    }
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text('Do you want to save your changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // don't save
                child: const Text('DISCARD'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true), // save
                child: const Text('SAVE'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _save();
      return false; // _save will handle navigation
    }
    return true; // allow pop if not saving
  }

  Future<void> _save() async {
    if (!mounted) return;

    setState(() => _submitted = true);
    if (_titleCtrl.text.trim().isEmpty) {
      _titleFocus.requestFocus();
      return;
    }

    // Start save operation
    final ctrl = ref.read(
      noteEditorControllerProvider(widget.originalNote).notifier,
    );

    try {
      await ctrl.save(_titleCtrl.text.trim(), _contentCtrl.text);

      // Animate out and navigate back
      if (mounted) {
        await _animationController.reverse();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(noteEditorControllerProvider(widget.originalNote));

    return WillPopScope(
      onWillPop: () async {
        if (await _onWillPop()) {
          await _animationController.reverse();
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Hero(
            tag: widget.heroTag ?? 'new_note',
            child: Material(
              color: Colors.transparent,
              child: Text(
                widget.originalNote == null ? 'New Note' : 'Edit Note',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          actions: [
            if (_isDirty)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilledButton.icon(
                    onPressed: async.isLoading ? null : _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  if (async.isLoading)
                    const LinearProgressIndicator()
                  else
                    const SizedBox(height: 2),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _titleCtrl,
                                  focusNode: _titleFocus,
                                  style: theme.textTheme.headlineSmall,
                                  decoration: InputDecoration(
                                    hintText: 'Note title',
                                    border: InputBorder.none,
                                    errorText:
                                        _submitted &&
                                                _titleCtrl.text.trim().isEmpty
                                            ? 'Title is required'
                                            : null,
                                    errorStyle: const TextStyle(fontSize: 12),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLines: 1,
                                  onSubmitted:
                                      (_) => _contentFocus.requestFocus(),
                                ),
                                const Divider(),
                              ],
                            ),
                          ),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: true,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: CompositedTransformTarget(
                              link: _formatBarLink,
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: _handleKeyCommand,
                                child: TextField(
                                  controller: _contentCtrl,
                                  focusNode: _contentFocus,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: theme.textTheme.bodyLarge,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Start typing your note...\nTip: Select text and tap the B icon to make it bold',
                                    border: InputBorder.none,
                                    hintStyle: theme.textTheme.bodyLarge
                                        ?.copyWith(color: theme.hintColor),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onChanged: (text) {
                                    setState(() {});
                                    if (_contentCtrl.selection.isValid &&
                                        _contentCtrl.selection.start !=
                                            _contentCtrl.selection.end) {
                                      _showFormatBarOverlay();
                                    } else {
                                      _hideFormatBar();
                                    }
                                  },
                                  onTap: () {
                                    if (_contentCtrl.selection.isValid &&
                                        _contentCtrl.selection.start !=
                                            _contentCtrl.selection.end) {
                                      _showFormatBarOverlay();
                                    }
                                  },
                                  onTapOutside: (_) => _hideFormatBar(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
