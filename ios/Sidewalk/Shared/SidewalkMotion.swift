import Pow
import SwiftUI

/// Shared restrained motion: responsive to touch, with a softly damped finish.
enum SidewalkMotion {
  static func spring(_ reduced: Bool) -> Animation {
    reduced
      ? .easeOut(duration: 0.15)
      : .spring(response: 0.48, dampingFraction: 0.88, blendDuration: 0.12)
  }

  static func transition(edge: Edge, reduced: Bool) -> AnyTransition {
    reduced ? .opacity : .movingParts.move(edge: edge).combined(with: .opacity)
  }

  static func welcome(reduced: Bool) -> AnyTransition {
    reduced
      ? .opacity
      : .movingParts.blur(radius: 3).combined(with: .scale(scale: 1.025)).combined(with: .opacity)
  }
}
