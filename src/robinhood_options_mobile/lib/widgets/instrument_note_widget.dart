import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_note.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class InstrumentNoteWidget extends StatefulWidget {
  final Instrument instrument;
  final String? userId;
  final FirestoreService firestoreService;
  final GenerativeService generativeService;

  const InstrumentNoteWidget({
    super.key,
    required this.instrument,
    required this.userId,
    required this.firestoreService,
    required this.generativeService,
  });

  @override
  State<InstrumentNoteWidget> createState() => _InstrumentNoteWidgetState();
}

class _InstrumentNoteWidgetState extends State<InstrumentNoteWidget> {
  final TextEditingController _noteController = TextEditingController();
  bool _isExpanded = false;

  Future<void> _editNote(InstrumentNote? existingNote) async {
    _noteController.text = existingNote?.note ?? '';
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Note for ${widget.instrument.symbol}')),
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  color: Colors.purple,
                  tooltip: "Draft with AI",
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            final prompt = Prompt(
                              key: 'draft-note',
                              title: 'Draft Note',
                              prompt:
                                  'Draft a short, insightful trading note for ${widget.instrument.symbol}. Focus on recent price action, key levels, and potential catalysts (bullish/bearish). Use markdown formatting (bold keys, bullet points) and keep it concise.',
                            );
                            final result = await widget.generativeService
                                .generateContentFromServer(
                                    prompt, null, null, null);
                            if (result.isNotEmpty) {
                              if (_noteController.text.isEmpty) {
                                _noteController.text = result;
                              } else {
                                _noteController.text =
                                    "${_noteController.text}\n\n---\n\n$result";
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('AI Generation failed: $e')),
                            );
                          } finally {
                            setDialogState(() => isSaving = false);
                          }
                        },
                ),
              ],
            ),
            content: TextField(
              controller: _noteController,
              maxLines: null,
              minLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter your trading notes... (Markdown supported)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            actions: [
              if (existingNote != null)
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                    title: const Text('Delete Note?'),
                                    content: const Text(
                                        'This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style: TextStyle(
                                                  color: Colors.red))),
                                    ],
                                  ));

                          if (confirm == true) {
                            setDialogState(() => isSaving = true);
                            try {
                              await widget.firestoreService
                                  .deleteInstrumentNote(
                                widget.userId!,
                                widget.instrument.symbol,
                              );
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              if (isSaving)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    setDialogState(() => isSaving = true);
                    try {
                      final noteText = _noteController.text.trim();
                      if (noteText.isEmpty) {
                        if (existingNote != null) {
                          await widget.firestoreService.deleteInstrumentNote(
                            widget.userId!,
                            widget.instrument.symbol,
                          );
                        }
                      } else {
                        final note = InstrumentNote(
                          symbol: widget.instrument.symbol,
                          note: noteText,
                          createdAt: existingNote?.createdAt ?? DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await widget.firestoreService.saveInstrumentNote(
                          widget.userId!,
                          note,
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving note: $e')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ]
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const SizedBox.shrink(); // Need user to save notes
    }

    return StreamBuilder<DocumentSnapshot<InstrumentNote>>(
      stream: widget.firestoreService.getInstrumentNoteStream(
        widget.userId!,
        widget.instrument.symbol,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
              height: 100,
              child:
                  Center(child: Text('Error loading note: ${snapshot.error}')));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        }

        final existingNote = snapshot.data?.data();
        final hasNote = existingNote != null && existingNote.note.isNotEmpty;

        return Card(
          margin: const EdgeInsets.symmetric(
              vertical: 8.0, horizontal: 0.0), // Match other cards
          child: InkWell(
            onTap: () => _editNote(existingNote),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Notes on ${widget.instrument.symbol}',
                              style: const TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasNote)
                              Text(
                                'Updated ${DateFormat.yMMMd().add_jm().format(existingNote.updatedAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (hasNote)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy Note',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: existingNote.note));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Note copied to clipboard')));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  if (hasNote) ...[
                    if (_isExpanded || existingNote.note.length < 300)
                      MarkdownBody(
                        data: existingNote.note,
                        selectable: true,
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            launchUrl(Uri.parse(href),
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                          p: Theme.of(context).textTheme.bodyMedium,
                          h1: Theme.of(context).textTheme.titleLarge,
                          h2: Theme.of(context).textTheme.titleMedium,
                          h3: Theme.of(context).textTheme.titleSmall,
                          blockquote: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                          code: Theme.of(context).textTheme.bodySmall?.copyWith(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                fontFamily: 'monospace',
                              ),
                        ),
                      )
                    else
                      Column(children: [
                        SizedBox(
                            height: 150,
                            child: ShaderMask(
                                shaderCallback: (rect) {
                                  return const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black, Colors.transparent],
                                  ).createShader(Rect.fromLTRB(
                                      0, 0, rect.width, rect.height));
                                },
                                blendMode: BlendMode.dstIn,
                                child: SingleChildScrollView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: MarkdownBody(
                                      data: existingNote.note,
                                      styleSheet: MarkdownStyleSheet.fromTheme(
                                              Theme.of(context))
                                          .copyWith(
                                        p: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                        h1: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                        h2: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        h3: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                        blockquote: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey),
                                        code: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              fontFamily: 'monospace',
                                            ),
                                      ),
                                    )))),
                        TextButton(
                            onPressed: () => setState(() => _isExpanded = true),
                            child: const Text("Show All"))
                      ]),
                    if (_isExpanded && existingNote.note.length >= 300)
                      Align(
                          alignment: Alignment.center,
                          child: TextButton(
                              onPressed: () =>
                                  setState(() => _isExpanded = false),
                              child: const Text("Show Less")))
                  ] else
                    Row(
                      children: [
                        Icon(Icons.edit_note,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to create a personal note...',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
