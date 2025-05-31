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
      response = await generativeService.generateContent(
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

  // // score-swing uses a JSON response, so don't show the details of the document unless it's already cached.
  // double scoreFontSize = 28;
  // double scoreLabelFontSize = 12;
  // // int totalScore = 0;
  // int formScore = 0;
  // int clubSpeedScore = 0;
  // int powerScore = 0;
  // int controlScore = 0;
  // if (promptKey == 'score-swing') {
  //   try {
  //     var scores = jsonDecode(
  //         response!.replaceAll('```json\n', '').replaceAll('```', ''));
  //     formScore = scores["form"];
  //     clubSpeedScore = scores["club-speed"];
  //     powerScore = scores["power"];
  //     controlScore = scores["control"];
  //     // totalScore =
  //     //     ((formScore + clubSpeedScore + powerScore + controlScore) / 4)
  //     //         .round();
  //   } catch (e) {
  //     // on Exception
  //     debugPrint(e.toString());
  //   }
  //   // TODO: Add animation of score.
  // }
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
          return DraggableScrollableSheet(
              expand: false,
              snap: true,
              minChildSize: 0.5,
              builder: (context1, controller) {
                return SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      // if (promptKey == 'score-swing') ...[
                      //   Padding(
                      //     padding: const EdgeInsets.symmetric(vertical: 16.0),
                      //     child: Card(
                      //       margin: const EdgeInsets.symmetric(horizontal: 10.0),
                      //       child: Padding(
                      //         padding: const EdgeInsets.all(16.0),
                      //         child: Column(
                      //           children: [
                      //             // const SizedBox(
                      //             //   height: 16,
                      //             // ),
                      //             const ListTile(
                      //               leading: Icon(Icons.sports_score),
                      //               title: Text(
                      //                 'Swing Score AI',
                      //                 style: TextStyle(fontSize: 20.0),
                      //               ),
                      //             ),
                      //             const SizedBox(
                      //               height: 16,
                      //             ),
                      //             Row(
                      //               mainAxisAlignment: MainAxisAlignment.spaceAround,
                      //               children: [
                      //                 Column(
                      //                   children: [
                      //                     CircleAvatar(
                      //                         radius: 30,
                      //                         child: Wrap(children: [
                      //                           // const Icon(Icons.sports_score),
                      //                           Text(
                      //                             formScore.toString(),
                      //                             style: TextStyle(
                      //                                 fontSize: scoreFontSize),
                      //                           )
                      //                         ])),
                      //                     Text(
                      //                       'form',
                      //                       style: TextStyle(
                      //                           fontSize: scoreLabelFontSize),
                      //                     ),
                      //                   ],
                      //                 ),
                      //                 Column(
                      //                   children: [
                      //                     CircleAvatar(
                      //                         radius: 30,
                      //                         child: Wrap(children: [
                      //                           // const Icon(Icons.sports_score),
                      //                           Text(
                      //                             clubSpeedScore.toString(),
                      //                             style: TextStyle(
                      //                                 fontSize: scoreFontSize),
                      //                           )
                      //                         ])),
                      //                     Text(
                      //                       'club speed',
                      //                       style: TextStyle(
                      //                           fontSize: scoreLabelFontSize),
                      //                     ),
                      //                   ],
                      //                 ),
                      //                 Column(
                      //                   children: [
                      //                     CircleAvatar(
                      //                         radius: 30,
                      //                         child: Wrap(children: [
                      //                           // const Icon(Icons.sports_score),
                      //                           Text(
                      //                             powerScore.toString(),
                      //                             style: TextStyle(
                      //                                 fontSize: scoreFontSize),
                      //                           )
                      //                         ])),
                      //                     Text(
                      //                       'power',
                      //                       style: TextStyle(
                      //                           fontSize: scoreLabelFontSize),
                      //                     ),
                      //                   ],
                      //                 ),
                      //                 Column(
                      //                   children: [
                      //                     CircleAvatar(
                      //                         radius: 30,
                      //                         child: Wrap(children: [
                      //                           // const Icon(Icons.sports_score),
                      //                           Text(
                      //                             controlScore.toString(),
                      //                             style: TextStyle(
                      //                                 fontSize: scoreFontSize),
                      //                           )
                      //                         ])),
                      //                     Text(
                      //                       'control',
                      //                       style: TextStyle(
                      //                           fontSize: scoreLabelFontSize),
                      //                     ),
                      //                   ],
                      //                 ),
                      //               ],
                      //             ),
                      //             const SizedBox(
                      //               height: 16,
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                      // ] else ...[
                      if (prompt.key == 'ask') ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          // padding: const EdgeInsets.symmetric(vertical: 16.0),
                          // padding: const EdgeInsets.all(8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: promptController,
                                    // maxLines: null,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'Ask a question.',
                                      // labelText: 'Text Message',
                                      // border: OutlineInputBorder(
                                      //     borderRadius: BorderRadius.circular(15)),
                                    ),
                                    // validator: (String? value) {
                                    //   if (value == null || value.isEmpty) {
                                    //     return 'Ask a question.';
                                    //   }
                                    //   return null;
                                    // },
                                  ),
                                ),
                                IconButton(
                                  icon: generativeProvider.generating
                                      ? const CircularProgressIndicator()
                                      : const Icon(Icons.send),
                                  onPressed: () async {
                                    if (promptController.text.isNotEmpty) {
                                      generativeProvider
                                          .startGenerating(prompt.key);
                                      generativeProvider
                                          .promptResponses[prompt.key] = null;
                                      setState(() {});

                                      response = await generativeService
                                          .generateContent(
                                              Prompt(
                                                  key: prompt.key,
                                                  title: prompt.title,
                                                  prompt:
                                                      promptController.text),
                                              stockPositionStore,
                                              optionPositionStore,
                                              forexHoldingStore);
                                      generativeProvider.setGenerativeResponse(
                                          prompt.key, response!);
                                      setState(() {});
                                    }
                                  },
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (response!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          // padding: const EdgeInsets.symmetric(vertical: 16.0),
                          // padding: const EdgeInsets.all(8.0),
                          child: Card(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
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
                                ),
                              )),
                        ),
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
                            generativeProvider.promptResponses[prompt.prompt] =
                                null;
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
                  ),
                );
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
