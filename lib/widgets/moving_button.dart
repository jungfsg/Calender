import 'package:flutter/material.dart';

class MovingButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const MovingButton({Key? key, required this.size, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/original (2).gif',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
