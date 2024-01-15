import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';

class InitialWidget extends StatelessWidget {
  final Widget? child;
  const InitialWidget({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      const SliverAppBar(
        floating: false,
        pinned: true,
        snap: false,
        title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            //runAlignment: WrapAlignment.end,
            //alignment: WrapAlignment.end,
            spacing: 20,
            //runSpacing: 5,
            children: [
              Text('Investing Mobile', style: TextStyle(fontSize: 20.0)),
              Text(
                "",
                style: TextStyle(fontSize: 16.0, color: Colors.white70),
              )
            ]),
        actions: [],
      ),
      const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )),
      if (child != null) ...[
        SliverToBoxAdapter(
            child: Container(
                //height: 420.0,
                padding: const EdgeInsets.all(12.0),
                child: Align(alignment: Alignment.center, child: child)))
      ],
      const SliverToBoxAdapter(child: DisclaimerWidget())
    ]);
  }
}
