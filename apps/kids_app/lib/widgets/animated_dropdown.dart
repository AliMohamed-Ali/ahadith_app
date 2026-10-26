import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

/// قائمة منسدلة متحركة (نفس شكل النموذج): تفتح بنعومة والسهم يلف والاختيارات تنزل ورا بعض.
class AnimatedDropdown<T> extends StatefulWidget {
  const AnimatedDropdown({super.key, required this.items, required this.labelOf, required this.onChanged, this.value, this.placeholder = '', this.icon, this.maxListHeight = 260});
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final T? value;
  final String placeholder;
  final IconData? icon;
  final double maxListHeight;

  @override
  State<AnimatedDropdown<T>> createState() => _AnimatedDropdownState<T>();
}

class _AnimatedDropdownState<T> extends State<AnimatedDropdown<T>> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final has = widget.value != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _open ? AppColors.teal : AppColors.mintLine, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                if (widget.icon != null) ...[Icon(widget.icon, color: AppColors.teal), const SizedBox(width: 10)],
                Expanded(
                  child: Text(
                    has ? widget.labelOf(widget.value as T) : widget.placeholder,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: has ? AppColors.navy : const Color(0xFF6B7591)),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                ),
              ]),
            ),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: BoxConstraints(maxHeight: widget.maxListHeight),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.mintLine, width: 2)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(6),
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (context, i) {
                    final it = widget.items[i];
                    final sel = it == widget.value;
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('dd$i'),
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 250 + (i.clamp(0, 10)) * 35),
                      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * -8), child: child)),
                      child: Material(
                        color: sel ? const Color(0xFFD6F3EC) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            widget.onChanged(it);
                            setState(() => _open = false);
                          },
                          child: SizedBox(
                            height: 46,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(children: [
                                Expanded(child: Text(widget.labelOf(it), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                                if (sel) const Icon(Icons.check_rounded, color: AppColors.teal),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}
