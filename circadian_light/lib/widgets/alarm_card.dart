import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../core/theme_manager.dart';

class AlarmCard extends StatefulWidget {
  final Alarm alarm;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isDisabledBySunriseSync;

  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onChanged,
    this.onTap,
    this.onDelete,
    this.isDisabledBySunriseSync = false,
  });

  @override
  State<AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<AlarmCard>
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
      end: -0.33,
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

    // Handle both left and right swipes
    final newValue = (_slideController.value - dragAmount * 3).clamp(0.0, 1.0);
    _slideController.value = newValue;
    setState(() => _isSliding = _slideController.value > 0);
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

  @override
  Widget build(BuildContext context) {
    final bool isEffectivelyDisabled =
        widget.isDisabledBySunriseSync || !widget.alarm.enabled;
    final String wakeUpTime = widget.alarm.wakeUpTime.format(context);
    final String startTime = widget.alarm.startTime.format(context);
    final String duration = '${widget.alarm.durationMinutes}min';

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                  const Color(
                    0xFFFFB347,
                  ).withValues(alpha: isEffectivelyDisabled ? 0.3 : 0.9),
                  const Color(
                    0xFFFFB347,
                  ).withValues(alpha: isEffectivelyDisabled ? 0.1 : 0.25),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFFB347,
                  ).withValues(alpha: isEffectivelyDisabled ? 0.15 : 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.alarm,
              color: isEffectivelyDisabled
                  ? ThemeManager.I.tertiaryTextColor
                  : ThemeManager.I.primaryTextColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.alarm.name,
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
                  '$duration ramp-up to $wakeUpTime',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ThemeManager.I.secondaryTextColor.withValues(
                      alpha: isEffectivelyDisabled ? 0.4 : 1,
                    ),
                  ),
                ),
                Text(
                  'Starts at $startTime',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: ThemeManager.I.tertiaryTextColor.withValues(
                      alpha: isEffectivelyDisabled ? 0.4 : 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.isDisabledBySunriseSync)
            Switch(
              value: widget.alarm.enabled,
              onChanged: widget.onChanged,
              activeColor: ThemeManager.I.currentAccentColor,
            )
          else
            Icon(
              Icons.lock_outline,
              color: ThemeManager.I.tertiaryTextColor,
              size: 20,
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
            onTap: widget.onTap,
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
                    onTap: _onTap,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: null,
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
