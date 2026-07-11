import 'package:flutter/material.dart';
import 'theme.dart';
import 'moss_theme.dart';

// ─── MossSidebar ──────────────────────────────────────────────────────────
class MossSidebar extends StatelessWidget {
  final List<Widget> children;

  const MossSidebar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Container(
      width: 200,
      color: theme.surface,
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
    final theme = MossTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
            fontSize: kTextBase, fontWeight: FontWeight.w600,
            color: theme.textSecondary, letterSpacing: 0.5,
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
  final bool ready;
  final VoidCallback? onThemeToggle;
  const MossStatusBar({super.key, required this.status, this.ready = true, this.onThemeToggle});

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
    final theme = MossTheme.of(context);
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS12, vertical: kS6),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          MossStatusDot(active: widget.ready),
          const SizedBox(width: kS6),
          Expanded(
            child: Text(widget.status, style: TextStyle(fontSize: kTextSm, color: theme.textSecondary),
              overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: kS8),
          IconButton(
            icon: Icon(
              MossTheme.maybeOf(context)?.isDark == true
                  ? Icons.dark_mode : Icons.light_mode,
              size: 14, color: theme.textSecondary),
            onPressed: widget.onThemeToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          const SizedBox(width: kS4),
          Text(time, style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
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
