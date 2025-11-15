import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:share_plus/share_plus.dart';

Future<void> generateContent(
  GenerativeProvider generativeProvider,
  GenerativeService generativeService,
  Prompt prompt,
  BuildContext context, {
  InstrumentPositionStore? stockPositionStore,
  OptionPositionStore? optionPositionStore,
  ForexHoldingStore? forexHoldingStore,
  bool localInference = true,
  dynamic user,
}) async {
  String? response;
  if (generativeProvider.promptResponses[prompt.prompt] != null) {
    response = generativeProvider.promptResponses[prompt.prompt];
  } else {
    generativeProvider.startGenerating(prompt.key);
    if (prompt.prompt.isEmpty) {
      response = '';
      generativeProvider.generating = false;
    } else if (localInference) {
      var generateContentResponse =
          await generativeService.generatePortfolioContent(
              prompt,
              stockPositionStore,
              optionPositionStore,
              forexHoldingStore,
              generativeProvider,
              user: user);
      response = generateContentResponse.text;
    } else {
      response = await generativeService.generateContentFromServer(
          prompt, stockPositionStore, optionPositionStore, forexHoldingStore,
          user: user);
      generativeProvider.setGenerativeResponse(prompt.prompt, response);
    }
  }
  if (context.mounted) {
    showAIResponse(
        response,
        prompt,
        context,
        generativeProvider,
        generativeService,
        stockPositionStore,
        optionPositionStore,
        forexHoldingStore,
        user);
  }
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
    dynamic user) {
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
        return StatefulBuilder(
            builder: (BuildContext buildercontext, setState) {
          final theme = Theme.of(buildercontext);
          final colorScheme = theme.colorScheme;

          // Add the initial response if it exists and the prompt key is 'ask'
          if (prompt.key == 'ask' && response != null && response!.isNotEmpty) {
            messages.add(ChatMessage(sender: Sender.ai, content: response!));
            // Clear the initial response so it's not added again on rebuilds
            response =
                null; // Set to null after adding to prevent duplicates on rebuild
          }

          return DraggableScrollableSheet(
              expand: false,
              snap: true,
              initialChildSize: prompt.key == 'ask' ? 1 : 0.5,
              minChildSize: 0.5,
              builder: (context1, controller) {
                void handleSendMessage() async {
                  if (promptController.text.isNotEmpty) {
                    final userMessage = promptController.text;
                    setState(() {
                      messages.add(ChatMessage(
                          sender: Sender.user, content: userMessage));
                      promptController.clear();
                      generativeProvider.startGenerating(prompt.key);
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
                                key: prompt.key,
                                title: prompt.title,
                                prompt: userMessage),
                            stockPositionStore,
                            optionPositionStore,
                            forexHoldingStore,
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

                if (prompt.key == 'ask') {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: colorScheme.primary, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              prompt.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1),
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
                              color: colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
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
                                              subject: prompt.title,
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
                  return SingleChildScrollView(
                      controller: controller,
                      child: Column(
                        children: [
                          if (response != null && response!.isNotEmpty) ...[
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
                                          color: colorScheme.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          prompt.title,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
                                      child: SelectionArea(
                                        child: MarkdownBody(
                                          data: response!,
                                          styleSheet: MarkdownStyleSheet(
                                            p: theme.textTheme.bodyLarge,
                                            h1: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            h2: theme.textTheme.titleLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
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
                          if (prompt.key != 'ask') ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FilledButton.tonalIcon(
                                    key: shareButtonKey,
                                    icon: const Icon(Icons.share_outlined,
                                        size: 20),
                                    onPressed: () async {
                                      if (response != null &&
                                          response!.isNotEmpty) {
                                        final box = shareButtonKey
                                            .currentContext
                                            ?.findRenderObject() as RenderBox?;
                                        if (box != null) {
                                          await SharePlus.instance
                                              .share(ShareParams(
                                            subject: prompt.title,
                                            text:
                                                '${prompt.title}\n\n$response',
                                            sharePositionOrigin:
                                                box.localToGlobal(Offset.zero) &
                                                    box.size,
                                          ));
                                        }
                                      }
                                    },
                                    label: const Text('Share'),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.refresh, size: 20),
                                    onPressed: () async {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      generativeProvider
                                              .promptResponses[prompt.prompt] =
                                          null;
                                      await generateContent(
                                        generativeProvider,
                                        generativeService,
                                        prompt,
                                        context,
                                        stockPositionStore: stockPositionStore,
                                        optionPositionStore:
                                            optionPositionStore,
                                        forexHoldingStore: forexHoldingStore,
                                        user: user,
                                      );
                                    },
                                    label: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(
                            height: 25,
                          )
                        ],
                      ));
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
