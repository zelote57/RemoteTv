// UIView+Layout.swift — Declarative AutoLayout convenience helpers for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+

import UIKit

extension UIView {
    
    /// Pins the receiver to the edges of another view with optional insets.
    /// - Parameters:
    ///   - view: The target view to anchor against.
    ///   - insets: Edge padding offsets (defaults to .zero).
    @discardableResult
    func pinToEdges(of view: UIView, insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
    
    /// Centers the receiver within another view with optional coordinate offsets.
    /// - Parameters:
    ///   - view: The target view to center within.
    ///   - offset: Horizontal and vertical offset points (defaults to .zero).
    @discardableResult
    func center(in view: UIView, offset: CGPoint = .zero) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: offset.x),
            centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: offset.y)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
    
    /// Fixes the receiver's width and height dimensions.
    /// - Parameters:
    ///   - width: Desired width in points (optional).
    ///   - height: Desired height in points (optional).
    @discardableResult
    func setDimensions(width: CGFloat? = nil, height: CGFloat? = nil) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = []
        if let width = width {
            constraints.append(widthAnchor.constraint(equalToConstant: width))
        }
        if let height = height {
            constraints.append(heightAnchor.constraint(equalToConstant: height))
        }
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
}
