import SpriteKit
import SwiftUI

/// キャラクターを歩かせて本をさがす図書館画面
struct LibraryGameView: View {
    let onInteract: (LibraryInteractable) -> Void

    @State private var scene = LibraryScene()
    @State private var focus: LibraryInteractable?
    @State private var joystick: JoystickState?
    @State private var pressedKeys: Set<KeyEquivalent> = []
    @FocusState private var hasKeyboardFocus: Bool

    private struct JoystickState {
        var origin: CGPoint
        var knob: CGPoint
    }

    private static let joystickRadius: CGFloat = 48

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()

            joystickLayer

            VStack {
                MessageWindow(text: focus?.prompt ?? "画面をドラッグして歩こう。本棚や司書さんの前で「しらべる」")
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                Spacer()
                HStack {
                    Spacer()
                    ActionButton(title: focus == .librarian ? "はなす" : "しらべる", isEnabled: focus != nil) {
                        if let focus { interact(with: focus) }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .focusable()
        .focused($hasKeyboardFocus)
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .up]) { press in
            handleKey(press)
        }
        .onAppear {
            scene.onFocusChange = { focus = $0 }
            scene.isPaused = false
        }
        .task {
            // 表示直後だとフォーカスが当たらないことがあるので少し待ってからキーボード入力を受け付ける
            try? await Task.sleep(for: .milliseconds(300))
            hasKeyboardFocus = true
        }
        .onDisappear {
            // 別画面に移ったときに歩き続けないよう入力をリセットする
            joystick = nil
            pressedKeys = []
            scene.moveInput = .zero
            scene.isPaused = true
        }
    }

    private var joystickLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let origin = joystick?.origin ?? value.startLocation
                        var offset = CGVector(dx: value.location.x - origin.x, dy: value.location.y - origin.y)
                        let length = hypot(offset.dx, offset.dy)
                        if length > Self.joystickRadius {
                            offset = CGVector(dx: offset.dx / length * Self.joystickRadius, dy: offset.dy / length * Self.joystickRadius)
                        }
                        joystick = JoystickState(origin: origin, knob: CGPoint(x: origin.x + offset.dx, y: origin.y + offset.dy))
                        // SwiftUI は下向きが正、SpriteKit は上向きが正
                        scene.moveInput = CGVector(dx: offset.dx / Self.joystickRadius, dy: -offset.dy / Self.joystickRadius)
                    }
                    .onEnded { _ in
                        joystick = nil
                        scene.moveInput = .zero
                    }
            )
            .overlay {
                if let joystick {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.18))
                            .stroke(.white.opacity(0.6), lineWidth: 2)
                            .frame(width: Self.joystickRadius * 2, height: Self.joystickRadius * 2)
                            .position(joystick.origin)
                        Circle()
                            .fill(.white.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .position(joystick.knob)
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private func interact(with interactable: LibraryInteractable) {
        joystick = nil
        scene.moveInput = .zero
        onInteract(interactable)
    }

    /// ハードウェアキーボード（iPad・Mac・シミュレータ）でも操作できるようにする
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let arrows: [KeyEquivalent] = [.upArrow, .downArrow, .leftArrow, .rightArrow]
        if arrows.contains(press.key) {
            if press.phase == .up {
                pressedKeys.remove(press.key)
            } else {
                pressedKeys.insert(press.key)
            }
            var vector = CGVector.zero
            if pressedKeys.contains(.upArrow) { vector.dy += 1 }
            if pressedKeys.contains(.downArrow) { vector.dy -= 1 }
            if pressedKeys.contains(.leftArrow) { vector.dx -= 1 }
            if pressedKeys.contains(.rightArrow) { vector.dx += 1 }
            scene.moveInput = vector
            return .handled
        }
        if press.phase == .down, press.key == .space || press.key == .return, let focus {
            interact(with: focus)
            return .handled
        }
        return .ignored
    }
}

/// RPG 風のメッセージウインドウ
private struct MessageWindow: View {
    let text: String

    var body: some View {
        Text(text)
            .gameWindowStyle()
            .animation(.easeOut(duration: 0.15), value: text)
    }
}

extension View {
    /// 紺地に白枠の RPG 風ウインドウの見た目にする
    func gameWindowStyle() -> some View {
        font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.12, green: 0.14, blue: 0.28).opacity(0.92), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).inset(by: 2).stroke(.white, lineWidth: 2))
    }
}

/// 調べる・話すボタン
private struct ActionButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color(red: 0.24, green: 0.15, blue: 0.10))
                .frame(width: 96, height: 96)
                .background(Circle().fill(Color(red: 0.96, green: 0.92, blue: 0.81)))
                .overlay(Circle().inset(by: 2).stroke(Color(red: 0.35, green: 0.23, blue: 0.15), lineWidth: 4))
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .scaleEffect(isEnabled ? 1 : 0.9)
        .animation(.spring(duration: 0.2), value: isEnabled)
        .accessibilityHint(isEnabled ? "" : "本棚か司書さんの前に立つと押せます")
    }
}
