import AppModels
import SwiftUI
import UIKit

/// Uses the reader's actual window screen and restores system settings when its view leaves the foreground.
struct SXJReaderScreenControl: UIViewRepresentable {
    let options: SXJReaderOptions
    let active: Bool

    func makeUIView(context: Context) -> ScreenView {
        ScreenView()
    }

    func updateUIView(_ view: ScreenView, context: Context) {
        view.options = options
        view.active = active
        view.apply()
    }

    static func dismantleUIView(_ view: ScreenView, coordinator: ()) {
        view.restore()
    }

    @MainActor
    final class ScreenView: UIView {
        var options = SXJReaderOptions()
        var active = false
        private weak var controlledScreen: UIScreen?
        private var previousBrightness: CGFloat?
        private var previousIdleState: Bool?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        func apply() {
            guard active, let screen = window?.windowScene?.screen else {
                restore()
                return
            }
            if controlledScreen !== screen {
                restore()
                controlledScreen = screen
            }
            if options.keepsScreenAwake {
                if previousIdleState == nil { previousIdleState = UIApplication.shared.isIdleTimerDisabled }
                UIApplication.shared.isIdleTimerDisabled = true
            } else if let previousIdleState {
                UIApplication.shared.isIdleTimerDisabled = previousIdleState
                self.previousIdleState = nil
            }
            if options.usesCustomBrightness {
                if previousBrightness == nil { previousBrightness = screen.brightness }
                screen.brightness = options.normalizedBrightness
            } else if let previousBrightness {
                screen.brightness = previousBrightness
                self.previousBrightness = nil
            }
        }

        func restore() {
            if let previousBrightness { controlledScreen?.brightness = previousBrightness }
            if let previousIdleState { UIApplication.shared.isIdleTimerDisabled = previousIdleState }
            previousBrightness = nil
            previousIdleState = nil
            controlledScreen = nil
        }
    }
}
