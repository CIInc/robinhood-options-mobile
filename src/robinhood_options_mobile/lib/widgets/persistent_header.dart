import 'package:flutter/material.dart';

class PersistentHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final Widget? widget;
  final double size;
  PersistentHeader(this.title, {this.widget, this.size = 34.0});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    if (widget != null) {
      return widget!;
    }
    return Material(
        elevation: 1,
        child: Container(
            color: Colors.white,
            child: /*Card(
            color: Colors.white,
            elevation: 3.0,
            child: */
                SizedBox(
              height: size,
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18.0),
                ),
              ),
            )));
  }

  @override
  double get maxExtent => size;

  @override
  double get minExtent => size;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true; // was set to false initially, but it wasn't updating the header names once data loaded with this method set to true
  }
}
