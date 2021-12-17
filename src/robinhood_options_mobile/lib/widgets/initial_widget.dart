import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';

class InitialWidget extends StatelessWidget {
  const InitialWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverAppBar(
        floating: false,
        pinned: true,
        snap: false,
        title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            //runAlignment: WrapAlignment.end,
            //alignment: WrapAlignment.end,
            spacing: 20,
            //runSpacing: 5,
            children: const [
              Text('Robinhood Options Mobile',
                  style: TextStyle(fontSize: 20.0)),
              Text(
                "",
                style: TextStyle(fontSize: 16.0, color: Colors.white70),
              )
            ]),
        actions: const [],
      ),
      const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )),
      const SliverToBoxAdapter(child: DisclaimerWidget())
    ]);
  }
}
