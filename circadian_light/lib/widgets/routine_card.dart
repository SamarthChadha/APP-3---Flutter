import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../core/theme_manager.dart';

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

class _RoutineCardState extends State<RoutineCard>
    with SingleTickerProviderStateMixin {
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
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
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
      final newValue = (_slideController.value - dragAmount * 3).clamp(
        0.0,
        1.0,
      );
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

  Widget _buildCustomSwitch() {
    final isOn = widget.routine.enabled && !widget.isDisabledBySunriseSync;
    final isEffectivelyDisabled =
        !widget.routine.enabled || widget.isDisabledBySunriseSync;

    return GestureDetector(
      onTap: widget.isDisabledBySunriseSync
          ? null
          : () => widget.onChanged(!widget.routine.enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isOn
              ? ThemeManager.I.currentAccentColor
              : (ThemeManager.I.isDarkMode
                    ? const Color(0xFF424242)
                    : const Color(0xFFE0E0E0)),
          border: isEffectivelyDisabled
              ? Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEffectivelyDisabled
                  ? Colors.grey
                  : (isOn
                        ? (ThemeManager.I.isDarkMode
                              ? Colors.black
                              : Colors.white)
                        : (ThemeManager.I.isDarkMode
                              ? const Color(0xFF9E9E9E)
                              : Colors.white)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeRange =
        '${_formatTime(context, widget.routine.startTime)} – ${_formatTime(context, widget.routine.endTime)}';
    final isEffectivelyDisabled =
        !widget.routine.enabled || widget.isDisabledBySunriseSync;

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
              ? [
                  ThemeManager.I.disabledColor,
                  ThemeManager.I.disabledColor.withValues(alpha: 0.8),
                ]
              : ThemeManager.I.neumorphicGradient,
        ),
        boxShadow: ThemeManager.I.neumorphicShadows,
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
                  widget.routine.color.withValues(
                    alpha: isEffectivelyDisabled ? 0.3 : 0.9,
                  ),
                  widget.routine.color.withValues(
                    alpha: isEffectivelyDisabled ? 0.1 : 0.25,
                  ),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.routine.color.withValues(
                    alpha: isEffectivelyDisabled ? 0.15 : 0.45,
                  ),
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
                    color: ThemeManager.I.primaryTextColor.withValues(
                      alpha: isEffectivelyDisabled ? 0.4 : 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: ThemeManager.I.secondaryTextColor.withValues(
                      alpha: isEffectivelyDisabled ? 0.4 : 1,
                    ),
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
            child: _buildCustomSwitch(),
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
            child: card,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                // Only show delete button when card is actually sliding
                if (_slideAnimation.value >= -0.01) {
                  return const SizedBox.shrink();
                }
                return Positioned.fill(
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
                );
              },
            ),
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _slideAnimation.value * MediaQuery.of(context).size.width,
                    0,
                  ),
                  child: GestureDetector(
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _onTap,
                        child: card,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
