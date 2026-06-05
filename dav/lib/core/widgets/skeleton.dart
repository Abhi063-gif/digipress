import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Shimmer Skeleton System
//  Usage: wrap any _SkeletonBox inside a _Shimmer to get animated shimmer.
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps children with a shimmer gradient animation.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFEBEBEB),
              Color(0xFFF5F5F5),
              Color(0xFFFFFFFF),
              Color(0xFFF5F5F5),
              Color(0xFFEBEBEB),
            ],
            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single skeleton placeholder box.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pre-built skeleton layouts for each screen
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton for a publication card in the home grid.
class SkeletonPubCard extends StatelessWidget {
  const SkeletonPubCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // thumbnail area
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: const SkeletonBox(height: double.infinity, radius: 0),
            ),
          ),
          // info area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 60, height: 10, radius: 4),
                SizedBox(height: 6),
                SkeletonBox(height: 11, radius: 4),
                SizedBox(height: 4),
                SkeletonBox(width: 80, height: 9, radius: 4),
                SizedBox(height: 4),
                SkeletonBox(width: 50, height: 9, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for the featured banner in home screen.
class SkeletonBanner extends StatelessWidget {
  const SkeletonBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonBox(height: 170, radius: 18);
  }
}

/// Skeleton for a single notification card.
class SkeletonNotificationCard extends StatelessWidget {
  const SkeletonNotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SkeletonBox(width: 70, height: 20, radius: 6),
              Spacer(),
              SkeletonBox(width: 50, height: 10, radius: 4),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 13, radius: 4),
          const SizedBox(height: 6),
          const SkeletonBox(width: 200, height: 11, radius: 4),
          const SizedBox(height: 6),
          const SkeletonBox(width: 160, height: 11, radius: 4),
          const SizedBox(height: 14),
          Row(
            children: const [
              SkeletonBox(width: 110, height: 12, radius: 4),
              Spacer(),
              SkeletonBox(width: 28, height: 28, radius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a list tile row — used in Reading History and Downloads screens.
/// Matches the structure of _HistoryTile / _DownloadTile:
///   [leading circle icon] | [title bar]\n[badge + time/date bar]
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Leading icon placeholder
          const SkeletonBox(width: 48, height: 48, radius: 10),
          const SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const SkeletonBox(height: 14, radius: 6),
                const SizedBox(height: 8),
                // Badge + subtitle row
                Row(
                  children: const [
                    SkeletonBox(width: 56, height: 16, radius: 4),
                    SizedBox(width: 10),
                    SkeletonBox(width: 100, height: 11, radius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
