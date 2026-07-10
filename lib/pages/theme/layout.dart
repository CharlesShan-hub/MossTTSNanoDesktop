import 'package:flutter/material.dart';
import 'theme.dart';

// ─── MossSidebar ──────────────────────────────────────────────────────────
class MossSidebar extends StatelessWidget {
  final List<Widget> children;

  const MossSidebar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: kSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class MossSidebarSection extends StatelessWidget {
  final String title;
  final Widget child;

  const MossSidebarSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontSize: kTextBase, fontWeight: FontWeight.w600,
            color: kTextSecondary, letterSpacing: 0.5,
          )),
          const SizedBox(height: kS8),
          child,
        ],
      ),
    );
  }
}

// ─── MossStatusDot ────────────────────────────────────────────────────────
class MossStatusDot extends StatelessWidget {
  final bool active;
  final double size;

  const MossStatusDot({super.key, this.active = true, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: active ? kSuccess : kWarning,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── MossStatusBar ────────────────────────────────────────────────────────
class MossStatusBar extends StatefulWidget {
  final String status;
  const MossStatusBar({super.key, required this.status});

  @override
  State<MossStatusBar> createState() => _MossStatusBarState();
}

class _MossStatusBarState extends State<MossStatusBar> {
  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) { setState(() {}); _tick(); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS12, vertical: kS6),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          MossStatusDot(active: widget.status.contains('就绪')),
          const SizedBox(width: kS6),
          Expanded(
            child: Text(widget.status, style: const TextStyle(fontSize: kTextSm, color: kTextSecondary),
              overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: kS8),
          Text(time, style: const TextStyle(fontSize: kTextSm, color: kTextSecondary)),
        ],
      ),
    );
  }
}

// ─── MossBadge ────────────────────────────────────────────────────────────
class MossBadge extends StatelessWidget {
  final String text;
  final Color? color;

  const MossBadge({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Text(text, style: TextStyle(fontSize: kTextXs, color: c)),
    );
  }
}
