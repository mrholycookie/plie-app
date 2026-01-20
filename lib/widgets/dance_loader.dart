import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DanceLoader extends StatefulWidget {
  final Color color;
  const DanceLoader({super.key, this.color = const Color(0xFFD4AF37)});

  @override
  State<DanceLoader> createState() => _DanceLoaderState();
}

class _DanceLoaderState extends State<DanceLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Туда-сюда

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FaIcon(
              FontAwesomeIcons.masksTheater, // Две маски сразу
              color: widget.color,
              size: 40,
            ),
          );
        },
      ),
    );
  }
}
