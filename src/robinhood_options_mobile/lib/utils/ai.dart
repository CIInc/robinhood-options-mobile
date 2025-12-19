import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

Future<void> generateContent(
  GenerativeProvider generativeProvider,
  GenerativeService generativeService,
  Prompt prompt,
  BuildContext context, {
  InstrumentPositionStore? stockPositionStore,
  OptionPositionStore? optionPositionStore,
  ForexHoldingStore? forexHoldingStore,
  bool localInference = true,
  User? user,
  bool showModal = true,
}) async {
  // Open sheet immediately with current cached response (if any)
  if (showModal && context.mounted) {
    showAIResponse(
      generativeProvider.promptResponses[prompt.prompt],
      prompt,
      context,
      generativeProvider,
      generativeService,
      stockPositionStore,
      optionPositionStore,
      forexHoldingStore,
      user,
    );
  }

  // If already cached, no further work
  if (generativeProvider.promptResponses[prompt.prompt] != null) return;

  generativeProvider.startGenerating(prompt.key);

  if (prompt.prompt.isEmpty) {
    generativeProvider.generating = false;
    generativeProvider.setGenerativeResponse(prompt.prompt, '');
    return;
  }

  if (localInference) {
    // Stream local model output
    await for (final _ in generativeService.streamPortfolioContent(
      prompt,
      stockPositionStore,
      optionPositionStore,
      forexHoldingStore,
      generativeProvider,
      user: user,
    )) {
      // Provider already updated inside streamPortfolioContent; we just wait.
    }
  } else {
    // Non-stream server call (Cloud Function) - could be extended later
    final full = await generativeService.generateContentFromServer(
      prompt,
      stockPositionStore,
      optionPositionStore,
      forexHoldingStore,
      user: user,
    );
    generativeProvider.setGenerativeResponse(prompt.prompt, full);
  }
  generativeProvider.generating = false;
}

// Define a simple ChatMessage class or similar structure
enum Sender { user, ai }

class ChatMessage {
  ChatMessage({required this.sender, required this.content});

  final Sender sender;
  final String content;
}

// State for the chat messages
List<ChatMessage> messages = [];

void showAIResponse(
    String? response,
    Prompt prompt,
    BuildContext context,
    GenerativeProvider generativeProvider,
    GenerativeService generativeService,
    InstrumentPositionStore? stockPositionStore,
    OptionPositionStore? optionPositionStore,
    ForexHoldingStore? forexHoldingStore,
    User? user) {
  final TextEditingController promptController = TextEditingController();
  final GlobalKey shareButtonKey = GlobalKey();
  final GlobalKey chatShareButtonKey = GlobalKey();

  showModalBottomSheet(
      context: context,
      enableDrag: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext newContext) {
        bool includeContext = prompt.appendPortfolioToPrompt;
        Prompt currentPrompt = prompt;
        bool isEditing = false;
        TextEditingController? editController;
        return StatefulBuilder(
            builder: (BuildContext buildercontext, setState) {
          final theme = Theme.of(buildercontext);
          final colorScheme = theme.colorScheme;

          // Add the initial response if it exists and the prompt key is 'ask'
          if (currentPrompt.key == 'ask' &&
              response != null &&
              response!.isNotEmpty) {
            messages.add(ChatMessage(sender: Sender.ai, content: response!));
            // Clear the initial response so it's not added again on rebuilds
            response =
                null; // Set to null after adding to prevent duplicates on rebuild
          }

          return DraggableScrollableSheet(
              expand: false,
              snap: true,
              initialChildSize: currentPrompt.key == 'ask' ? 1 : 0.5,
              minChildSize: 0.5,
              builder: (context1, controller) {
                void handleSendMessage() async {
                  if (promptController.text.isNotEmpty) {
                    final userMessage = promptController.text;
                    setState(() {
                      messages.add(ChatMessage(
                          sender: Sender.user, content: userMessage));
                      promptController.clear();
                      generativeProvider.startGenerating(currentPrompt.key);
                    });

                    // Auto-scroll to bottom after user message
                    await Future.delayed(Duration(milliseconds: 100));
                    if (controller.hasClients) {
                      controller.animateTo(
                        controller.position.maxScrollExtent,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }

                    // Call the generative service with the user's message
                    final aiResponse =
                        await generativeService.generateContentFromServer(
                            Prompt(
                                key: currentPrompt.key,
                                title: currentPrompt.title,
                                prompt: userMessage,
                                appendPortfolioToPrompt: includeContext),
                            includeContext ? stockPositionStore : null,
                            includeContext ? optionPositionStore : null,
                            includeContext ? forexHoldingStore : null,
                            user: user);

                    setState(() {
                      messages.add(
                          ChatMessage(sender: Sender.ai, content: aiResponse));
                      generativeProvider.generating = false; // Stop loading
                    });

                    // Auto-scroll to bottom after AI response
                    await Future.delayed(Duration(milliseconds: 100));
                    if (controller.hasClients) {
                      controller.animateTo(
                        controller.position.maxScrollExtent,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  }
                }

                if (currentPrompt.key == 'ask') {
                  return Column(
                    children: [
                      // Padding(
                      //   padding: const EdgeInsets.all(16.0),
                      //   child: Row(
                      //     children: [
                      //       Container(
                      //         padding: const EdgeInsets.all(8.0),
                      //         decoration: BoxDecoration(
                      //           color: colorScheme.primaryContainer,
                      //           borderRadius: BorderRadius.circular(12),
                      //         ),
                      //         child: Icon(
                      //           Icons.chat_bubble_outline,
                      //           color: colorScheme.onPrimaryContainer,
                      //           size: 24,
                      //         ),
                      //       ),
                      //       const SizedBox(width: 12),
                      //       Text(
                      //         prompt.title,
                      //         style: theme.textTheme.titleLarge?.copyWith(
                      //           fontWeight: FontWeight.bold,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // Divider(height: 1, thickness: 1),
                      Flexible(
                        fit: FlexFit.loose,
                        child: ListView.builder(
                          controller: controller,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isUser = message.sender == Sender.user;
                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 6.0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? colorScheme.primaryContainer
                                      : colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: MarkdownBody(
                                  data: message.content,
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    p: theme.textTheme.bodyMedium?.copyWith(
                                      color: isUser
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSecondaryContainer,
                                    ),
                                    h1: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isUser
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSecondaryContainer,
                                    ),
                                    h2: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isUser
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSecondaryContainer,
                                    ),
                                    code: theme.textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      backgroundColor: isUser
                                          ? colorScheme.primary
                                              .withValues(alpha: 0.1)
                                          : colorScheme.surface,
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                      color: isUser
                                          ? colorScheme.primary
                                              .withValues(alpha: 0.1)
                                          : colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(buildercontext)
                                    .viewInsets
                                    .bottom +
                                8.0,
                            left: 8.0,
                            right: 8.0,
                            top: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  includeContext
                                      ? Icons.pie_chart
                                      : Icons.pie_chart_outline,
                                  color: includeContext
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                tooltip: includeContext
                                    ? 'Portfolio context included'
                                    : 'Portfolio context excluded',
                                onPressed: () {
                                  setState(() {
                                    includeContext = !includeContext;
                                  });
                                },
                              ),
                              if (messages.isNotEmpty) ...[
                                IconButton(
                                  key: chatShareButtonKey,
                                  icon: const Icon(Icons.share_outlined),
                                  tooltip: 'Share conversation',
                                  onPressed: () async {
                                    final conversationText = messages
                                        .map((msg) =>
                                            '${msg.sender == Sender.user ? "You" : "AI"}: ${msg.content}')
                                        .join('\n\n');
                                    final box = chatShareButtonKey
                                        .currentContext
                                        ?.findRenderObject() as RenderBox?;
                                    if (box != null) {
                                      await SharePlus.instance.share(
                                          ShareParams(
                                              subject: currentPrompt.title,
                                              text: conversationText,
                                              sharePositionOrigin:
                                                  box.localToGlobal(
                                                          Offset.zero) &
                                                      box.size));
                                    }
                                  },
                                ),
                              ],
                              Expanded(
                                child: TextField(
                                  controller: promptController,
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    hintText: 'Ask a question...',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 12.0,
                                    ),
                                  ),
                                  onSubmitted: (_) => handleSendMessage(),
                                ),
                              ),
                              IconButton(
                                icon: generativeProvider.generating
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Icon(Icons.send,
                                        color: colorScheme.primary),
                                onPressed: generativeProvider.generating
                                    ? null
                                    : handleSendMessage,
                              )
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 25,
                      )
                    ],
                  );
                } else {
                  return Consumer<GenerativeProvider>(builder: (ctx, gp, _) {
                    final current = gp.promptResponses[currentPrompt.prompt];
                    return SingleChildScrollView(
                        controller: controller,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: colorScheme.onPrimaryContainer,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          currentPrompt.title,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!isEditing)
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Edit Prompt',
                                          onPressed: () {
                                            String initialText =
                                                currentPrompt.prompt;
                                            if (currentPrompt
                                                    .appendPortfolioToPrompt &&
                                                stockPositionStore != null &&
                                                optionPositionStore != null &&
                                                forexHoldingStore != null) {
                                              initialText +=
                                                  '\n${generativeService.portfolioPrompt(stockPositionStore, optionPositionStore, forexHoldingStore, user: user)}';
                                            }
                                            editController =
                                                TextEditingController(
                                                    text: initialText);
                                            setState(() {
                                              isEditing = true;
                                            });
                                          },
                                        ),
                                      if (current != null && current.isNotEmpty)
                                        IconButton(
                                          key: shareButtonKey,
                                          icon:
                                              const Icon(Icons.share_outlined),
                                          tooltip: 'Share',
                                          onPressed: () async {
                                            final box = shareButtonKey
                                                    .currentContext
                                                    ?.findRenderObject()
                                                as RenderBox?;
                                            if (box != null) {
                                              await SharePlus.instance
                                                  .share(ShareParams(
                                                subject: currentPrompt.title,
                                                text:
                                                    '${currentPrompt.title}\n\n$current',
                                                sharePositionOrigin:
                                                    box.localToGlobal(
                                                            Offset.zero) &
                                                        box.size,
                                              ));
                                            }
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.refresh),
                                        tooltip: 'Refresh',
                                        onPressed: () async {
                                          generativeProvider.promptResponses[
                                              currentPrompt.prompt] = null;
                                          await generateContent(
                                            generativeProvider,
                                            generativeService,
                                            currentPrompt,
                                            context,
                                            stockPositionStore:
                                                stockPositionStore,
                                            optionPositionStore:
                                                optionPositionStore,
                                            forexHoldingStore:
                                                forexHoldingStore,
                                            user: user,
                                            showModal: false,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Card(
                                    elevation: 0,
                                    color: colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: isEditing
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                      color: colorScheme.outline
                                                          .withValues(
                                                              alpha: 0.1),
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                  child: TextField(
                                                    controller: editController,
                                                    maxLines: null,
                                                    style: theme
                                                        .textTheme.bodySmall,
                                                    decoration:
                                                        const InputDecoration(
                                                      hintText:
                                                          'Enter custom instructions...',
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          isEditing = false;
                                                        });
                                                      },
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    FilledButton(
                                                      onPressed: () async {
                                                        if (editController!
                                                            .text.isNotEmpty) {
                                                          setState(() {
                                                            isEditing = false;
                                                            currentPrompt =
                                                                Prompt(
                                                              key: currentPrompt
                                                                  .key,
                                                              title:
                                                                  currentPrompt
                                                                      .title,
                                                              prompt:
                                                                  editController!
                                                                      .text,
                                                              appendPortfolioToPrompt:
                                                                  false,
                                                            );
                                                          });
                                                          await generateContent(
                                                            generativeProvider,
                                                            generativeService,
                                                            currentPrompt,
                                                            context,
                                                            stockPositionStore:
                                                                stockPositionStore,
                                                            optionPositionStore:
                                                                optionPositionStore,
                                                            forexHoldingStore:
                                                                forexHoldingStore,
                                                            user: user,
                                                            showModal: false,
                                                          );
                                                        }
                                                      },
                                                      child:
                                                          const Text('Update'),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : current == null
                                              ? Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          const CircularProgressIndicator(
                                                              strokeWidth: 2),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text('Generating...',
                                                        style: theme.textTheme
                                                            .bodyMedium),
                                                  ],
                                                )
                                              : SelectionArea(
                                                  child: MarkdownBody(
                                                    data: current,
                                                    styleSheet:
                                                        MarkdownStyleSheet(
                                                      p: theme
                                                          .textTheme.bodyMedium,
                                                      h1: theme.textTheme
                                                          .headlineSmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                      h2: theme
                                                          .textTheme.titleLarge
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                      h3: theme
                                                          .textTheme.titleMedium
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      code: theme
                                                          .textTheme.bodyMedium
                                                          ?.copyWith(
                                                        fontFamily: 'monospace',
                                                        backgroundColor: colorScheme
                                                            .surfaceContainerHighest,
                                                      ),
                                                      codeblockDecoration:
                                                          BoxDecoration(
                                                        color: colorScheme
                                                            .surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      blockquote: theme
                                                          .textTheme.bodyMedium
                                                          ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                      blockquoteDecoration:
                                                          BoxDecoration(
                                                        border: Border(
                                                            left: BorderSide(
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                                width: 4)),
                                                        color: colorScheme
                                                            .surfaceContainerHighest
                                                            .withValues(
                                                                alpha: 0.5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // if (promptKey == 'summarize-video') ...[
                            //   TextButton.icon(
                            //     icon: const Icon(Icons.copy_all_outlined),
                            //     onPressed: () async {
                            //       if (widget.video != null) {
                            //         if (context.mounted) {
                            //           Navigator.pop(context);
                            //         }
                            //         state(() {
                            //           currentPrompt = promptKey;
                            //         });
                            //         widget.video!.note = response;
                            //         if (widget.onChange != null) {
                            //           widget.onChange!();
                            //         }
                            //         state(() {
                            //           currentPrompt = null;
                            //         });
                            //       }
                            //     },
                            //     label: const Text('Copy to Pro Notes'),
                            //   ),
                            // ],
                            SizedBox(
                              height: 25,
                            )
                          ],
                        ));
                  });
                }
              });
        });
      });
  // ScaffoldMessenger.of(context)
  //     .showSnackBar(SnackBar(
  //   content:
  //       Text('$response'),
  //   duration:
  //       const Duration(days: 1),
  //   action:
  //       SnackBarAction(
  //     label: 'Ok',
  //     onPressed: () {},
  //   ),
  //   behavior:
  //       SnackBarBehavior.floating,
  // ));
}
