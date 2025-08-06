import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';

Future<void> generateContent(
  GenerativeProvider generativeProvider,
  GenerativeService generativeService,
  Prompt prompt,
  BuildContext context, {
  InstrumentPositionStore? stockPositionStore,
  OptionPositionStore? optionPositionStore,
  ForexHoldingStore? forexHoldingStore,
}) async {
  String? response;
  if (generativeProvider.promptResponses[prompt.prompt] != null) {
    response = generativeProvider.promptResponses[prompt.prompt];
  } else {
    generativeProvider.startGenerating(prompt.key);
    if (prompt.key == "market-summary" || prompt.key == "market-predictions") {
      response = await generativeService.generateContentFromServer(
          prompt, stockPositionStore, optionPositionStore, forexHoldingStore);
      generativeProvider.setGenerativeResponse(prompt.prompt, response);
    } else if (prompt.prompt.isEmpty) {
      response = '';
      generativeProvider.generating = false;
    } else {
      var generateContentResponse =
          await generativeService.generatePortfolioContent(
              prompt,
              stockPositionStore,
              optionPositionStore,
              forexHoldingStore,
              generativeProvider);
      response = generateContentResponse.text;
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
        forexHoldingStore);
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
    ForexHoldingStore? forexHoldingStore) {
  final TextEditingController promptController = TextEditingController();

  showModalBottomSheet(
      context: context,
      enableDrag: true,
      // backgroundColor: Colors.grey.shade100,
      // shape: const BeveledRectangleBorder(),
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      // constraints: BoxConstraints.loose(const Size.fromHeight(340)),
      builder: (BuildContext newContext) {
        return StatefulBuilder(
            builder: (BuildContext buildercontext, setState) {
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
                            forexHoldingStore);

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
                    // mainAxisSize: MainAxisSize.min, // Set mainAxisSize to min
                    // Use Column instead of SingleChildScrollView
                    children: [
                      Flexible(
                        // Use Flexible instead of Expanded
                        fit: FlexFit.loose, // Set fit to loose
                        // Use Expanded for the chat history
                        child: ListView.builder(
                          controller: controller,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return Align(
                              alignment: message.sender == Sender.user
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10.0, vertical: 4.0),
                                color: message.sender == Sender.user
                                    ? Colors.blue[100]
                                    : Colors.grey[200],
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: MarkdownBody(
                                    data: message.content,
                                    selectable: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        // Input row at the bottom
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(buildercontext)
                                    .viewInsets
                                    .bottom +
                                16.0,
                            left: 16.0,
                            right: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: promptController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Ask a question...',
                                ),
                                onFieldSubmitted: (_) => handleSendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: generativeProvider.generating
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.send),
                              onPressed: handleSendMessage,
                            )
                          ],
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
                          // This handles cases where prompt.key is not 'ask'
                          if (response != null && response!.isNotEmpty) ...[
                            // Add null check for response
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              // padding: const EdgeInsets.symmetric(vertical: 16.0),
                              // padding: const EdgeInsets.all(8.0),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: SelectionArea(
                                      // SelectionTransformer.separated allows for new lines to be copied and
                                      // pasted.
                                      child: MarkdownBody(
                                        // selectable: true,
                                        data: "# ${prompt.title}  \n$response",
                                        // styleSheet: MarkdownStyleSheet(
                                        //   h1Align: WrapAlignment.center,
                                        //   tableHeadAlign: TextAlign.left,
                                        //   textAlign: WrapAlignment.spaceEvenly,
                                        // ),
                                      ),
                                    )),
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
                            // Only show refresh button for non-chat prompts
                            TextButton.icon(
                              icon: const Icon(Icons.refresh),
                              onPressed: () async {
                                // if (widget.video != null &&
                                //     widget.video!.responses != null) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                //   state(() {
                                //     currentPrompt = promptKey;
                                //   });
                                generativeProvider
                                    .promptResponses[prompt.prompt] = null;
                                // generativeProvider.promptResponses.removeWhere((key, value) => key == 'portfolio-summary');
                                await generateContent(
                                  generativeProvider,
                                  generativeService,
                                  prompt,
                                  context,
                                  stockPositionStore: stockPositionStore,
                                  optionPositionStore: optionPositionStore,
                                  forexHoldingStore: forexHoldingStore,
                                );

                                //   widget.video!.responses!.remove(promptKey);
                                //   await onAIChipPressed(promptKey!, context, state);
                                //   state(() {
                                //     currentPrompt = null;
                                //   });
                                // }
                              },
                              label: const Text('Generate new answer'),
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
