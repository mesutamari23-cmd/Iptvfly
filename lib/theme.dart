import 'dart:ui';
import 'package:flutter/material.dart';

const kBg = Color(0xFF0A0E1F);
const kViolet = Color(0xFF7C5CFF);
const kGold = Color(0xFFD4AF37);

const kBgGradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF241459), Color(0xFF0A0E1F)],
  ),
);

class GlassBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets? padding;
  const GlassBox({super.key, required this.child, this.radius = 20, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// عنصر قابل للتنقل بالريموت: يكبر ويظهر له إطار ذهبي عند التركيز
class TvFocus extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double radius;
  const TvFocus({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.radius = 16,
  });

  @override
  State<TvFocus> createState() => _TvFocusState();
}

class _TvFocusState extends State<TvFocus> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return Focus(
      onFocusChange: (v) => setState(() => _f = v),
      child: AnimatedScale(
        scale: _f ? 1.06 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: _f ? kGold : Colors.transparent, width: 2.5),
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
