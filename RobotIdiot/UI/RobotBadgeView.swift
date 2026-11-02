import UIKit

/// Mascotte dessinée de dessus, dans le même langage que le plateau.
final class RobotBadgeView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = "Robot Idiot, vu du dessus"
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = side * 0.36

        context.setFillColor(AppTheme.robotShadow.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius * 0.92, width: radius * 2, height: radius * 1.84))

        let body = CGRect(x: center.x - radius * 0.86, y: center.y - radius * 0.86, width: radius * 1.72, height: radius * 1.72)
        context.setFillColor(AppTheme.robotBody.cgColor)
        context.setStrokeColor(AppTheme.line.cgColor)
        context.setLineWidth(side * 0.035)
        context.fillEllipse(in: body)
        context.strokeEllipse(in: body)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: -.pi / 2)

        let visor = UIBezierPath()
        visor.move(to: CGPoint(x: -radius * 0.38, y: radius * 0.02))
        visor.addLine(to: CGPoint(x: 0, y: radius * 0.92))
        visor.addLine(to: CGPoint(x: radius * 0.38, y: radius * 0.02))
        visor.close()
        AppTheme.teal.setFill()
        AppTheme.line.setStroke()
        visor.lineWidth = side * 0.028
        visor.fill()
        visor.stroke()

        AppTheme.line.setFill()
        for x in [-radius * 0.2, radius * 0.2] {
            context.fillEllipse(in: CGRect(x: x - radius * 0.08, y: radius * 0.08, width: radius * 0.16, height: radius * 0.16))
        }
        context.restoreGState()

        let antenna = CGRect(x: center.x - radius * 0.12, y: center.y - radius * 0.12, width: radius * 0.24, height: radius * 0.24)
        context.setFillColor(AppTheme.coral.cgColor)
        context.fillEllipse(in: antenna)
        context.strokeEllipse(in: antenna)
    }
}
