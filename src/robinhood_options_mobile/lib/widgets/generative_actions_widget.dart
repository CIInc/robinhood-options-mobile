import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/utils/ai.dart';

class GenerativeActionsWidget extends StatelessWidget {
  final GenerativeService generativeService;
  final User? user;

  const GenerativeActionsWidget({
    super.key,
    required this.generativeService,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer5<PortfolioStore, InstrumentPositionStore,
        OptionPositionStore, ForexHoldingStore, GenerativeProvider>(
      builder: (context, portfolioStore, stockPositionStore,
          optionPositionStore, forexHoldingStore, generativeProvider, child) {
        return SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              _buildActionChip(
                context,
                generativeProvider,
                'portfolio-summary',
                Icons.summarize_outlined,
                'Portfolio Summary',
                () async {
                  await generateContent(
                    generativeProvider,
                    generativeService,
                    generativeService.prompts
                        .firstWhere((p) => p.key == 'portfolio-summary'),
                    context,
                    stockPositionStore: stockPositionStore,
                    optionPositionStore: optionPositionStore,
                    forexHoldingStore: forexHoldingStore,
                    user: user,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildActionChip(
                context,
                generativeProvider,
                'portfolio-recommendations',
                Icons.recommend_outlined,
                'Recommendations',
                () async {
                  await generateContent(
                    generativeProvider,
                    generativeService,
                    generativeService.prompts.firstWhere(
                        (p) => p.key == 'portfolio-recommendations'),
                    context,
                    stockPositionStore: stockPositionStore,
                    optionPositionStore: optionPositionStore,
                    forexHoldingStore: forexHoldingStore,
                    user: user,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildActionChip(
                context,
                generativeProvider,
                'market-summary',
                Icons.public,
                'Market Summary',
                () async {
                  await generateContent(
                    generativeProvider,
                    generativeService,
                    generativeService.prompts
                        .firstWhere((p) => p.key == 'market-summary'),
                    context,
                    stockPositionStore: stockPositionStore,
                    optionPositionStore: optionPositionStore,
                    forexHoldingStore: forexHoldingStore,
                    localInference: false,
                    user: user,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildActionChip(
                context,
                generativeProvider,
                'market-predictions',
                Icons.batch_prediction_outlined,
                'Market Predictions',
                () async {
                  await generateContent(
                    generativeProvider,
                    generativeService,
                    generativeService.prompts
                        .firstWhere((p) => p.key == 'market-predictions'),
                    context,
                    stockPositionStore: stockPositionStore,
                    optionPositionStore: optionPositionStore,
                    forexHoldingStore: forexHoldingStore,
                    localInference: false,
                    user: user,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildActionChip(
                context,
                generativeProvider,
                'ask',
                Icons.question_answer,
                'Ask a question',
                () async {
                  await generateContent(
                    generativeProvider,
                    generativeService,
                    generativeService.prompts.firstWhere((p) => p.key == 'ask'),
                    context,
                    stockPositionStore: stockPositionStore,
                    optionPositionStore: optionPositionStore,
                    forexHoldingStore: forexHoldingStore,
                    user: user,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    GenerativeProvider generativeProvider,
    String promptKey,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    final isGenerating = generativeProvider.generating &&
        generativeProvider.generatingPrompt == promptKey;

    return ActionChip(
      avatar: isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      side: BorderSide.none,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
