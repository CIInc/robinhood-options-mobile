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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Assistant',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          'Portfolio & Market Insights',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Consumer5<PortfolioStore, InstrumentPositionStore,
                OptionPositionStore, ForexHoldingStore, GenerativeProvider>(
              builder: (context,
                  portfolioStore,
                  stockPositionStore,
                  optionPositionStore,
                  forexHoldingStore,
                  generativeProvider,
                  child) {
                return SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      _buildActionCard(
                        context,
                        generativeProvider,
                        'portfolio-summary',
                        Icons.summarize_outlined,
                        'Portfolio Summary',
                        () async {
                          await generateContent(
                            generativeProvider,
                            generativeService,
                            generativeService.prompts.firstWhere(
                                (p) => p.key == 'portfolio-summary'),
                            context,
                            stockPositionStore: stockPositionStore,
                            optionPositionStore: optionPositionStore,
                            forexHoldingStore: forexHoldingStore,
                            user: user,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildActionCard(
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
                      const SizedBox(width: 12),
                      _buildActionCard(
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
                      const SizedBox(width: 12),
                      _buildActionCard(
                        context,
                        generativeProvider,
                        'market-predictions',
                        Icons.batch_prediction_outlined,
                        'Market Predictions',
                        () async {
                          await generateContent(
                            generativeProvider,
                            generativeService,
                            generativeService.prompts.firstWhere(
                                (p) => p.key == 'market-predictions'),
                            context,
                            stockPositionStore: stockPositionStore,
                            optionPositionStore: optionPositionStore,
                            forexHoldingStore: forexHoldingStore,
                            localInference: false,
                            user: user,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildActionCard(
                        context,
                        generativeProvider,
                        'ask',
                        Icons.question_answer,
                        'Ask a question',
                        () async {
                          await generateContent(
                            generativeProvider,
                            generativeService,
                            generativeService.prompts
                                .firstWhere((p) => p.key == 'ask'),
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
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    GenerativeProvider generativeProvider,
    String promptKey,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    final isGenerating = generativeProvider.generating &&
        generativeProvider.generatingPrompt == promptKey;

    final prompt = generativeService.prompts.firstWhere(
        (p) => p.key == promptKey,
        orElse: () => Prompt(key: '', title: '', prompt: ''));
    final promptText = prompt.prompt;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isGenerating)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  promptText.isEmpty
                      ? "Ask anything about your portfolio or the market."
                      : promptText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
