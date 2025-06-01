import 'package:flutter/material.dart';
import 'dart:ui';

/// 애니메이션이 있는 팝업 위젯
///
/// 팝업의 크기, 위치, 내용을 커스터마이즈할 수 있습니다.
/// 애니메이션은 위에서 아래로 내려오는 효과를 가집니다.
class AnimatedPopup extends StatefulWidget {
  /// 팝업 내부에 표시될 위젯
  final Widget child;

  /// 팝업이 닫힐 때 호출될 콜백 함수
  final VoidCallback onClose;

  /// 팝업의 너비 (기본값: 화면 너비의 95%)
  final double popupWidth;

  /// 팝업의 높이 (기본값: 166.0)
  final double popupHeight;

  /// 팝업의 상단 위치 (기본값: 상단 safe area + 12)
  final double popupTop;

  /// 팝업의 좌측 위치 (기본값: 화면 중앙 정렬)
  final double popupLeft;

  const AnimatedPopup({
    Key? key,
    required this.child,
    required this.onClose,
    required this.popupWidth,
    required this.popupHeight,
    required this.popupTop,
    required this.popupLeft,
  }) : super(key: key);

  @override
  State<AnimatedPopup> createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 애니메이션 컨트롤러 설정
    // duration: 애니메이션 지속 시간 (300ms)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // 애니메이션 커브 설정
    // Curves.easeOut: 시작은 빠르게, 끝은 천천히
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    // 애니메이션 시작
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 전체 화면을 차지하는 반투명 배경
          // opacity: 0.16 - 배경의 투명도 조절 가능
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // 닫기 애니메이션 실행 후 콜백 호출
                _controller.reverse().then((_) => widget.onClose());
              },
              child: Container(color: Colors.black.withOpacity(0.00)),
            ),
          ),
          // 팝업
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                top: widget.popupTop,
                left: widget.popupLeft,
                width: widget.popupWidth,
                height: widget.popupHeight,
                child: Opacity(opacity: _animation.value, child: child),
              );
            },
            child: ClipRRect(
              // 팝업의 모서리 둥글기 (26.0)
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                // 블러 효과 설정
                // sigmaX, sigmaY: 블러 강도 (16.0)
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    // 팝업 배경색 설정
                    // opacity: 0.04 - 배경의 투명도 조절 가능
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
