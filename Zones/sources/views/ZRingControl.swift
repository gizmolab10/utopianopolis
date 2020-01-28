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
		case eConfined
		case eVisible
		case eInsertion
	}

	var type: ZControlType = .eVisible
	static let    controls = [confined, visible, insertion]

	override func draw(_ rect: CGRect) {
		super.draw(rect)

		let thick = rect.width / 18.0
		let inset = rect.width /  4.5
		let  more = rect.width /  2.5
		let  tiny = rect.insetBy(dx: more,  dy: more)
		let shape = rect.insetBy(dx: inset, dy: inset)

		switch type           {
			case .eInsertion  :
				drawTriangle  (orientedUp: gInsertionsFollow, in: shape, thickness: thick)		// insertion direction
			case .eConfined   :
				if  gBrowsingIsConfined {
					drawCircle(                               in: shape, thickness: thick)		// inactive confinement dot
					drawCircle(                               in:  tiny, thickness: thick)		// tiny dot
				} else        {
					drawCircle(orientedUp: false,             in: shape, thickness: thick)
					drawCircle(orientedUp: true,              in: shape, thickness: thick)
				}
			case .eVisible    :
				drawCircle    (                               in: shape, thickness: thick)		// active is-visible dot
				if !gFullRingIsVisible {
					drawCircle(                               in:  tiny, thickness: thick)		// tiny dot
				}
		}
	}

	func response() {
		if gFullRingIsVisible { printDebug(.ring, "\(type)") }

		switch type {
			case .eVisible: gFullRingIsVisible = !gFullRingIsVisible
			default:        toggleModes(isDirection: type == .eInsertion)
		}
	}

	// MARK:- private
	// MARK:-

	private static let   visible = create(.eVisible)
	private static let  confined = create(.eConfined)
	private static let insertion = create(.eInsertion)

	private static func create(_ type: ZControlType) -> ZRingControl {
		let  control = ZRingControl()
		control.type = type

		return control
	}

	private func drawTriangle(orientedUp: Bool, in iRect: CGRect, thickness: CGFloat) {
		let rect = self.rect(orientedUp: orientedUp, in: iRect)
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
		let offset = iRect.height * 0.20 * (orientedUp ? -1.0 : 1.0)
		let   rect = iRect.offsetBy(dx: 0.0, dy: offset)

		return rect
	}

}
