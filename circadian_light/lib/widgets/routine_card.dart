import 'package:flutter/material.dart';
import '../models/routine.dart';

class RoutineCard extends StatefulWidget {
  final Routine routine;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isDisabledBySunriseSync;

  const RoutineCard({
    super.key,
    required this.routine,
    required this.onChanged,
    this.onTap,
    this.onDelete,
    this.isDisabledBySunriseSync = false,
  });

  @override
  State<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<RoutineCard> with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  bool _isSliding = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: -0.33, // Slide to 1/3 of width
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.isDisabledBySunriseSync || widget.onDelete == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dragAmount = details.delta.dx / screenWidth;

    if (details.delta.dx < 0) {
      final newValue = (_slideController.value - dragAmount * 3).clamp(0.0, 1.0);
      _slideController.value = newValue;
      setState(() {
        _isSliding = _slideController.value > 0;
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.isDisabledBySunriseSync || widget.onDelete == null) return;
    if (_slideController.value > 0.5) {
      _slideController.forward();
      setState(() => _isSliding = true);
    } else {
      _slideController.reverse();
      setState(() => _isSliding = false);
    }
  }

  void _onTap() {
    if (_isSliding) {
      _slideController.reverse();
      setState(() => _isSliding = false);
    } else if (!widget.isDisabledBySunriseSync && widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _onDelete() {
    _slideController.reverse();
    setState(() => _isSliding = false);
    widget.onDelete?.call();
  }

  String _formatTime(BuildContext context, TimeOfDay t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(t);

  @override
  Widget build(BuildContext context) {
    final timeRange = '${_formatTime(context, widget.routine.startTime)} – ${_formatTime(context, widget.routine.endTime)}';
    final isEffectivelyDisabled = !widget.routine.enabled || widget.isDisabledBySunriseSync;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEffectivelyDisabled
              ? [const Color(0xFFE5E5E5), const Color(0xFFD4D4D4)]
              : [const Color(0xFFFDFDFD), const Color(0xFFE3E3E3)],
        ),
        boxShadow: const [
          BoxShadow(offset: Offset(6, 6), blurRadius: 18, color: Color(0x1F000000)),
          BoxShadow(offset: Offset(-6, -6), blurRadius: 18, color: Color(0x88FFFFFF)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.routine.color.withValues(alpha: isEffectivelyDisabled ? 0.3 : 0.9),
                  widget.routine.color.withValues(alpha: isEffectivelyDisabled ? 0.1 : 0.25)
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.routine.color.withValues(alpha: isEffectivelyDisabled ? 0.15 : 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.routine.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2F2F2F).withValues(alpha: isEffectivelyDisabled ? 0.4 : 1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: const Color(0xFF3C3C3C).withValues(alpha: isEffectivelyDisabled ? 0.3 : 0.85),
                  ),
                ),
                if (widget.isDisabledBySunriseSync) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Disabled by Sunrise/Sunset Sync',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          IgnorePointer(
            ignoring: widget.isDisabledBySunriseSync,
            child: Switch(
              value: widget.routine.enabled && !widget.isDisabledBySunriseSync,
              onChanged: widget.isDisabledBySunriseSync ? null : widget.onChanged,
            ),
          ),
        ],
      ),
    );

    if (widget.isDisabledBySunriseSync || widget.onDelete == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _onTap,
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Routine'),
                  content: Text('Are you sure you want to delete "${widget.routine.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDelete?.call();
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
            child: card,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(28),
              ),
              child: GestureDetector(
                onTap: _onDelete,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_slideAnimation.value * MediaQuery.of(context).size.width, 0),
                child: GestureDetector(
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _onTap,
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Routine'),
                            content: Text('Are you sure you want to delete "${widget.routine.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onDelete?.call();
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: card,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
