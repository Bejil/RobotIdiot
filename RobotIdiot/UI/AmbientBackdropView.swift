import UIKit

/// Fond dégradé animé partagé par les écrans de l'app.
final class AmbientBackdropView: UIView {
    private let gradient = CAGradientLayer()
    private let orbs: [CAShapeLayer] = (0..<5).map { _ in CAShapeLayer() }
    private var running = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        gradient.colors = [
            AppTheme.cream.cgColor,
            UIColor(hex: 0x1A1F6A).cgColor,
            UIColor(hex: 0x2A1460).cgColor
        ]
        gradient.locations = [0, 0.55, 1]
        gradient.startPoint = CGPoint(x: 0.1, y: 0)
        gradient.endPoint = CGPoint(x: 0.9, y: 1)
        layer.addSublayer(gradient)

        for (index, orb) in orbs.enumerated() {
            orb.fillColor = (index % 2 == 0 ? AppTheme.tealDark : AppTheme.gold)
                .withAlphaComponent(0.12).cgColor
            layer.addSublayer(orb)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Insère le fond derrière le contenu existant et le contraint aux bords.
    @discardableResult
    static func install(in host: UIView) -> AmbientBackdropView {
        let backdrop = AmbientBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        host.insertSubview(backdrop, at: 0)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: host.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        return backdrop
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        let sizes: [CGFloat] = [160, 110, 90, 70, 120]
        for (index, orb) in orbs.enumerated() {
            let side = sizes[index]
            let origin: CGPoint
            switch index {
            case 0: origin = CGPoint(x: -40, y: 80)
            case 1: origin = CGPoint(x: bounds.width - 90, y: 40)
            case 2: origin = CGPoint(x: bounds.width * 0.2, y: bounds.height * 0.55)
            case 3: origin = CGPoint(x: bounds.width * 0.7, y: bounds.height * 0.7)
            default: origin = CGPoint(x: bounds.width * 0.45, y: bounds.height * 0.28)
            }
            orb.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: side, height: side))).cgPath
            orb.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            if orb.animation(forKey: "drift") == nil {
                orb.position = origin
            }
        }
    }

    func start() {
        guard !running else { return }
        running = true
        layoutIfNeeded()
        guard !PlaySettings.prefersReducedMotion else { return }
        for (index, orb) in orbs.enumerated() {
            orb.removeAnimation(forKey: "drift")
            orb.removeAnimation(forKey: "pulse")
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = orb.position
            move.toValue = CGPoint(
                x: orb.position.x + (index.isMultiple(of: 2) ? 18 : -14),
                y: orb.position.y + (index.isMultiple(of: 2) ? -16 : 12)
            )
            move.duration = 4.5 + Double(index) * 0.4
            move.autoreverses = true
            move.repeatCount = .infinity
            move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            orb.add(move, forKey: "drift")

            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.45
            pulse.toValue = 1
            pulse.duration = 2.8 + Double(index) * 0.25
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            orb.add(pulse, forKey: "pulse")
        }
    }

    func stop() {
        running = false
        orbs.forEach {
            $0.removeAnimation(forKey: "drift")
            $0.removeAnimation(forKey: "pulse")
        }
    }
}
