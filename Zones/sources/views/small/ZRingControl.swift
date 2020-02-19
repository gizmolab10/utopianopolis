//
//  ZRingControl.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/27/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZRingControl: ZView {

	enum ZControlType {
		case eInsertion
		case eVisible
		case eConfined
		case eToolTip
	}

	var type: ZControlType = .eVisible
	static let    controls = [insertion, visible, confined]

	override var description: String {
		switch type {
			case .eInsertion: return "insert at \(gInsertionsFollow ? "bottom"          : "top")"
			case .eConfined:  return "browse \(gBrowsingIsConfined  ? "within one idea" : "to all visible")"
			case .eVisible:   return "\(gFullRingIsVisible          ? "hide these"      : "show") controls"
			case .eToolTip:   return "\(gToolTipsAlwaysVisible      ? "hide"            : "show") tool tips"
		}
	}

	override func draw(_ rect: CGRect) {
		super.draw(rect)

		let width = rect.width
		let thick = width / 20.0
		let inset = width /  5.0
		let  more = width /  2.5
		let  tiny = rect.insetBy(dx: more,  dy: more)
		let large = rect.insetBy(dx: inset, dy: inset)
		let color = gNecklaceDotColor

		color.setStroke()

		switch type           {
			case .eInsertion  :
				drawTriangle  (orientedUp: gInsertionsFollow, in: large, thickness: thick)		// insertion direction
			case .eConfined   :
				if  gBrowsingIsConfined {
					drawCircle(                               in: large, thickness: thick)		// inactive confinement dot
					drawCircle(                               in:  tiny, thickness: thick)		// tiny dot
				} else        {
					drawCircle(orientedUp: false,             in:  tiny, thickness: thick)
					drawCircle(orientedUp: true,              in:  tiny, thickness: thick)
				}
			case .eVisible    :
				drawCircle    (                               in:  tiny, thickness: thick)		// active is-visible dot
				if !gFullRingIsVisible {
					drawCircle(                               in: large, thickness: thick)		// tiny dot
				}
			default: break
		}
	}

	func response() -> Bool {
		switch type {
			case .eVisible: gFullRingIsVisible     = !gFullRingIsVisible
			case .eToolTip: gToolTipsAlwaysVisible = !gToolTipsAlwaysVisible
			default: return toggleModes(isDirection: type == .eInsertion)
		}

		return true
	}

	// MARK:- private
	// MARK:-

	static let tooltip = create(.eToolTip)
	private static let   visible = create(.eVisible)
	private static let  confined = create(.eConfined)
	private static let insertion = create(.eInsertion)

	private static func create(_ type: ZControlType) -> ZRingControl {
		let  control = ZRingControl()
		control.type = type

		return control
	}

	private func drawTriangle(orientedUp: Bool, in rect: CGRect, thickness: CGFloat) {
		ZBezierPath.drawTriangle(orientedUp: orientedUp, in: rect, thickness: thickness )
	}

	private func drawCircle(in rect: CGRect, thickness: CGFloat) {
		ZBezierPath.drawCircle(in: rect, thickness: thickness)
	}

	private func drawCircle(orientedUp: Bool, in iRect: CGRect, thickness: CGFloat) {
		let rect = self.rect(orientedUp: orientedUp, in: iRect)
		ZBezierPath.drawCircle(in: rect, thickness: thickness)
	}

	private func rect(orientedUp: Bool, in iRect: CGRect) -> CGRect {
		let offset = iRect.height * 1.0 * (orientedUp ? -1.0 : 1.0)
		let   rect = iRect.offsetBy(dx: 0.0, dy: offset)

		return rect
	}

}
