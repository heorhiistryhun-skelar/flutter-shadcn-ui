import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The position of the [ShadPortal] in the global coordinate system.
sealed class ShadAnchorBase {
  const ShadAnchorBase();
}

/// Automatically infers the position of the [ShadPortal] in the global
/// coordinate system adjusting according to the [offset],
/// [followerAnchor] and [targetAnchor] properties.
@immutable
class ShadAnchorAuto extends ShadAnchorBase {
  const ShadAnchorAuto({
    this.offset = Offset.zero,
    @Deprecated(
      'No longer needed. Position tracking is now handled automatically '
      'by CompositedTransformFollower at the compositing layer level.',
    )
    this.followTargetOnResize = true,
    this.followerAnchor = Alignment.topCenter,
    this.targetAnchor = Alignment.bottomCenter,
  });

  /// The offset of the overlay from the target widget.
  final Offset offset;

  /// Whether the overlay is automatically adjusted to follow the target
  /// widget when the target widget moves dues to a window resize.
  @Deprecated(
    'No longer needed. Position tracking is now handled automatically '
    'by CompositedTransformFollower at the compositing layer level.',
  )
  final bool followTargetOnResize;

  /// The coordinates of the overlay from which the overlay starts, which
  /// is calculated from the initial [targetAnchor].
  final Alignment followerAnchor;

  /// The coordinates of the target from which the overlay starts.
  final Alignment targetAnchor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShadAnchorAuto &&
        other.offset == offset &&
        other.followerAnchor == followerAnchor &&
        other.targetAnchor == targetAnchor;
  }

  @override
  int get hashCode =>
      offset.hashCode ^ followerAnchor.hashCode ^ targetAnchor.hashCode;
}

/// Manually specifies the position of the [ShadPortal] in the global
/// coordinate system.
@immutable
class ShadAnchor extends ShadAnchorBase {
  const ShadAnchor({
    this.childAlignment = Alignment.topLeft,
    this.overlayAlignment = Alignment.bottomLeft,
    this.offset = Offset.zero,
  });

  final Alignment childAlignment;
  final Alignment overlayAlignment;
  final Offset offset;

  static const center = ShadAnchor(
    childAlignment: Alignment.topCenter,
    overlayAlignment: Alignment.bottomCenter,
  );

  ShadAnchor copyWith({
    Alignment? childAlignment,
    Alignment? overlayAlignment,
    Offset? offset,
  }) {
    return ShadAnchor(
      childAlignment: childAlignment ?? this.childAlignment,
      overlayAlignment: overlayAlignment ?? this.overlayAlignment,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShadAnchor &&
        other.childAlignment == childAlignment &&
        other.overlayAlignment == overlayAlignment &&
        other.offset == offset;
  }

  @override
  int get hashCode {
    return childAlignment.hashCode ^
        overlayAlignment.hashCode ^
        offset.hashCode;
  }
}

@immutable
class ShadGlobalAnchor extends ShadAnchorBase {
  const ShadGlobalAnchor(this.offset);

  /// The global offset where the overlay is positioned.
  final Offset offset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShadGlobalAnchor && other.offset == offset;
  }

  @override
  int get hashCode => offset.hashCode;
}

class ShadPortal extends StatefulWidget {
  const ShadPortal({
    super.key,
    required this.child,
    required this.portalBuilder,
    required this.visible,
    required this.anchor,
  });

  final Widget child;
  final WidgetBuilder portalBuilder;
  final bool visible;
  final ShadAnchorBase anchor;

  @override
  State<ShadPortal> createState() => _ShadPortalState();
}

class _ShadPortalState extends State<ShadPortal> {
  final layerLink = LayerLink();
  final overlayPortalController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    updateVisibility();
  }

  @override
  void didUpdateWidget(covariant ShadPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateVisibility();
  }

  @override
  void dispose() {
    hide();
    super.dispose();
  }

  void updateVisibility() {
    final shouldShow = widget.visible;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldShow) {
        show();
      } else {
        hide();
      }
    });
  }

  void hide() {
    if (overlayPortalController.isShowing) {
      overlayPortalController.hide();
    }
  }

  void show() {
    if (!overlayPortalController.isShowing) {
      overlayPortalController.show();
    }
  }

  Widget buildAutoPosition(
    BuildContext context,
    ShadAnchorAuto anchor,
  ) {
    return _ShadAutoPositionFollower(
      link: layerLink,
      offset: anchor.offset,
      targetAnchor: anchor.targetAnchor,
      followerAnchor: anchor.followerAnchor,
      child: widget.portalBuilder(context),
    );
  }

  Widget buildManualPosition(
    BuildContext context,
    ShadAnchor anchor,
  ) {
    return CompositedTransformFollower(
      link: layerLink,
      offset: anchor.offset,
      followerAnchor: anchor.childAlignment,
      targetAnchor: anchor.overlayAlignment,
      child: widget.portalBuilder(context),
    );
  }

  Widget buildGlobalPosition(
    BuildContext context,
    ShadGlobalAnchor anchor,
  ) {
    return CustomSingleChildLayout(
      delegate: ShadPositionDelegate(
        target: anchor.offset,
        verticalOffset: 0,
        preferBelow: true,
      ),
      child: widget.portalBuilder(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: OverlayPortal(
        controller: overlayPortalController,
        overlayChildBuilder: (context) {
          return Center(
            widthFactor: 1,
            heightFactor: 1,
            child: switch (widget.anchor) {
              final ShadAnchorAuto anchor => buildAutoPosition(context, anchor),
              final ShadAnchor anchor => buildManualPosition(context, anchor),
              final ShadGlobalAnchor anchor => buildGlobalPosition(
                context,
                anchor,
              ),
            },
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A delegate for computing the layout of an overlay to be displayed above or
/// below a target specified in the global coordinate system.
class ShadPositionDelegate extends SingleChildLayoutDelegate {
  /// Creates a delegate for computing the layout of an overlay.
  ShadPositionDelegate({
    required this.target,
    required this.verticalOffset,
    required this.preferBelow,
  });

  /// The offset of the target the overlay is positioned near in the global
  /// coordinate system.
  final Offset target;

  /// The amount of vertical distance between the target and the displayed
  /// overlay.
  final double verticalOffset;

  /// Whether the overlay is displayed below its widget by default.
  ///
  /// If there is insufficient space to display the tooltip in the preferred
  /// direction, the tooltip will be displayed in the opposite direction.
  final bool preferBelow;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return positionDependentBox(
      size: size,
      childSize: childSize,
      target: target,
      verticalOffset: verticalOffset,
      preferBelow: preferBelow,
      margin: 0,
    );
  }

  @override
  bool shouldRelayout(ShadPositionDelegate oldDelegate) {
    return target != oldDelegate.target ||
        verticalOffset != oldDelegate.verticalOffset ||
        preferBelow != oldDelegate.preferBelow;
  }
}

/// A follower widget that automatically adjusts its position when it doesn't
/// fit on screen.
class _ShadAutoPositionFollower extends StatefulWidget {
  const _ShadAutoPositionFollower({
    required this.link,
    required this.offset,
    required this.targetAnchor,
    required this.followerAnchor,
    required this.child,
  });

  final LayerLink link;
  final Offset offset;
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Widget child;

  @override
  State<_ShadAutoPositionFollower> createState() =>
      _ShadAutoPositionFollowerState();
}

class _ShadAutoPositionFollowerState extends State<_ShadAutoPositionFollower> {
  final _followerKey = GlobalKey();

  Alignment? _adjustedTargetAnchor;
  Alignment? _adjustedFollowerAnchor;
  Offset? _adjustedOffset;

  Alignment get _effectiveTargetAnchor =>
      _adjustedTargetAnchor ?? widget.targetAnchor;
  Alignment get _effectiveFollowerAnchor =>
      _adjustedFollowerAnchor ?? widget.followerAnchor;
  Offset get _effectiveOffset => _adjustedOffset ?? widget.offset;

  @override
  void initState() {
    super.initState();
    _schedulePositionCheck();
  }

  @override
  void didUpdateWidget(covariant _ShadAutoPositionFollower oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetAnchor != widget.targetAnchor ||
        oldWidget.followerAnchor != widget.followerAnchor ||
        oldWidget.offset != widget.offset) {
      // Reset adjustments when anchor configuration changes
      _adjustedTargetAnchor = null;
      _adjustedFollowerAnchor = null;
      _adjustedOffset = null;
      _schedulePositionCheck();
    }
  }

  void _schedulePositionCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAndAdjustPosition();
    });
  }

  void _checkAndAdjustPosition() {
    final leaderSize = widget.link.leaderSize;
    if (leaderSize == null || leaderSize == Size.zero) {
      _schedulePositionCheck();
      return;
    }

    final followerContext = _followerKey.currentContext;
    if (followerContext == null) {
      _schedulePositionCheck();
      return;
    }

    final followerBox = followerContext.findRenderObject() as RenderBox?;
    if (followerBox == null || !followerBox.hasSize) {
      _schedulePositionCheck();
      return;
    }

    final followerSize = followerBox.size;

    // Get the leader layer from the link
    final leaderLayer = widget.link.leader;
    if (leaderLayer == null) {
      _schedulePositionCheck();
      return;
    }

    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    // Get leader's global position from the layer's offset
    // The leader layer's offset is relative to its parent, so we need to
    // compute the full transform
    final leaderOffset = leaderLayer.offset;
    final leaderTopLeft = _getLeaderGlobalPosition(leaderLayer, leaderOffset);
    if (leaderTopLeft == null) {
      _schedulePositionCheck();
      return;
    }

    // Calculate with current (or default) anchors
    final targetAnchor = widget.targetAnchor;
    final followerAnchor = widget.followerAnchor;
    final offset = widget.offset;

    final leaderAnchorPoint = _getAnchorPoint(
      leaderTopLeft,
      leaderSize,
      targetAnchor,
    );
    final followerAnchorOffset = _getAnchorOffset(followerSize, followerAnchor);
    final preferredPosition = leaderAnchorPoint + offset - followerAnchorOffset;
    final preferredRect = preferredPosition & followerSize;

    var needsUpdate = false;
    var newTargetAnchor = targetAnchor;
    var newFollowerAnchor = followerAnchor;
    var newOffset = offset;

    // Check horizontal fit
    final overflowLeft = preferredRect.left < 0;
    final overflowRight = preferredRect.right > screenSize.width;

    if (overflowLeft || overflowRight) {
      final flippedTargetAnchor = _flipHorizontal(targetAnchor);
      final flippedFollowerAnchor = _flipHorizontal(followerAnchor);
      final flippedOffset = Offset(-offset.dx, offset.dy);

      final flippedLeaderAnchorPoint = _getAnchorPoint(
        leaderTopLeft,
        leaderSize,
        flippedTargetAnchor,
      );
      final flippedFollowerAnchorOffset = _getAnchorOffset(
        followerSize,
        flippedFollowerAnchor,
      );
      final flippedPosition =
          flippedLeaderAnchorPoint +
          flippedOffset -
          flippedFollowerAnchorOffset;
      final flippedRect = flippedPosition & followerSize;

      // Check if flipped position is better
      final flippedFits =
          flippedRect.left >= 0 && flippedRect.right <= screenSize.width;

      if (flippedFits) {
        newTargetAnchor = flippedTargetAnchor;
        newFollowerAnchor = flippedFollowerAnchor;
        newOffset = flippedOffset;
        needsUpdate = true;
      }
    }

    // Recalculate with any horizontal adjustments
    final adjustedLeaderAnchorPoint = _getAnchorPoint(
      leaderTopLeft,
      leaderSize,
      newTargetAnchor,
    );
    final adjustedFollowerAnchorOffset = _getAnchorOffset(
      followerSize,
      newFollowerAnchor,
    );
    final adjustedPosition =
        adjustedLeaderAnchorPoint + newOffset - adjustedFollowerAnchorOffset;
    final adjustedRect = adjustedPosition & followerSize;

    // Check vertical fit
    final overflowTop = adjustedRect.top < 0;
    final overflowBottom = adjustedRect.bottom > screenSize.height;

    if (overflowTop || overflowBottom) {
      final flippedTargetAnchor = _flipVertical(newTargetAnchor);
      final flippedFollowerAnchor = _flipVertical(newFollowerAnchor);
      final flippedOffset = Offset(newOffset.dx, -newOffset.dy);

      final flippedLeaderAnchorPoint = _getAnchorPoint(
        leaderTopLeft,
        leaderSize,
        flippedTargetAnchor,
      );
      final flippedFollowerAnchorOffset = _getAnchorOffset(
        followerSize,
        flippedFollowerAnchor,
      );
      final flippedPosition =
          flippedLeaderAnchorPoint +
          flippedOffset -
          flippedFollowerAnchorOffset;
      final flippedRect = flippedPosition & followerSize;

      // Check if flipped position is better
      final flippedFits =
          flippedRect.top >= 0 && flippedRect.bottom <= screenSize.height;

      if (flippedFits) {
        newTargetAnchor = flippedTargetAnchor;
        newFollowerAnchor = flippedFollowerAnchor;
        newOffset = flippedOffset;
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      setState(() {
        _adjustedTargetAnchor = newTargetAnchor;
        _adjustedFollowerAnchor = newFollowerAnchor;
        _adjustedOffset = newOffset;
      });
    }
  }

  Offset? _getLeaderGlobalPosition(LeaderLayer leader, Offset localOffset) {
    // Walk up the layer tree to accumulate the transform
    var currentOffset = localOffset;
    var current = leader.parent;

    while (current != null) {
      if (current is OffsetLayer) {
        currentOffset += current.offset;
      } else if (current is TransformLayer) {
        // Apply the transform to the offset
        final transform = current.transform;
        if (transform != null) {
          currentOffset = MatrixUtils.transformPoint(transform, currentOffset);
        }
      }
      current = current.parent;
    }

    return currentOffset;
  }

  Offset _getAnchorPoint(Offset topLeft, Size size, Alignment anchor) {
    return topLeft +
        Offset(
          size.width * ((anchor.x + 1) / 2),
          size.height * ((anchor.y + 1) / 2),
        );
  }

  Offset _getAnchorOffset(Size size, Alignment anchor) {
    return Offset(
      size.width * ((anchor.x + 1) / 2),
      size.height * ((anchor.y + 1) / 2),
    );
  }

  Alignment _flipHorizontal(Alignment alignment) {
    return Alignment(-alignment.x, alignment.y);
  }

  Alignment _flipVertical(Alignment alignment) {
    return Alignment(alignment.x, -alignment.y);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      key: _followerKey,
      link: widget.link,
      offset: _effectiveOffset,
      targetAnchor: _effectiveTargetAnchor,
      followerAnchor: _effectiveFollowerAnchor,
      child: widget.child,
    );
  }
}
