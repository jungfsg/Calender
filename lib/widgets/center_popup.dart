import 'package:flutter/material.dart';
import 'animated_popup.dart';

class CenterPopup extends StatelessWidget {
  final VoidCallback onClose;

  const CenterPopup({Key? key, required this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final popupWidth = screenSize.width * 0.95;
    final popupHeight = 166.0;
    final popupTop = MediaQuery.of(context).padding.top + 12;
    final popupLeft = (screenSize.width - popupWidth) / 2;

    return AnimatedPopup(
      popupWidth: popupWidth,
      popupHeight: popupHeight,
      popupTop: popupTop,
      popupLeft: popupLeft,
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: const Text(
              'AMATTA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
