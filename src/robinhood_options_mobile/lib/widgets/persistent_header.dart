import 'package:flutter/material.dart';

class PersistentHeader extends SliverPersistentHeaderDelegate {
  final String title;
  PersistentHeader(this.title);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
        color: Colors.white,
        child: Card(
            color: Colors.white,
            elevation: 3.0,
            child: SizedBox(
              height: 80.0,
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
            )));
  }

  @override
  double get maxExtent => 80.0;

  @override
  double get minExtent => 80.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true; // was set to false initially, but it wasn't updating the header names once data loaded with this method set to true
  }
}
