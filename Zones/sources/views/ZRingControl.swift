//
//  ZRingControl.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/27/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZControlType {
	case eConfined
	case eVisible
	case eInsertion
}

class ZRingControl: ZView {
	var       type: ZControlType = .eVisible
	private static let insertion = create(.eInsertion)
	private static let  confined = create(.eConfined)
	private static let   visible = create(.eVisible)
	static let          controls = [confined, visible, insertion]

	private static func create(_ type: ZControlType) -> ZRingControl {
		let  control = ZRingControl()
		control.type = type

		return control
	}

	func response() -> Bool {
		if gFullRingIsVisible { print(type) }

		switch type {
			case .eVisible: gFullRingIsVisible = !gFullRingIsVisible
			default:        toggleModes(isDirection: type == .eInsertion)
		}

		return true
	}

	// MARK:- draw
	// MARK:-

	override func draw(_ rect: CGRect) {
		super.draw(rect)

		let inset = rect.width / 2.5
//		let thick = inset / 2.5
		let  thin = CGFloat(4.0)
		let   dot = rect.insetBy(dx: inset, dy: inset)
		let small = dot .insetBy(dx:   4.0, dy:   4.0)
		let large = dot .insetBy(dx: -10.0, dy: -10.0)


		switch type {
			case .eVisible:
				drawCircle    (                               in: large, thickness: thin)		// active is-visible dot
			case .eInsertion:
				drawTriangle  (orientedUp: gInsertionsFollow, in: dot,   thickness: thin)
				drawCircle    (                               in: small, thickness: thin) 		// active insertion dot
			case .eConfined:
				if  gBrowsingIsConfined {
					drawCircle(                               in: large, thickness: thin)		// inactive confinement dot
				} else {
					drawCircle(orientedUp: false,             in: dot,   thickness: thin)
					drawCircle(orientedUp: true,              in: dot,   thickness: thin)
					drawCircle(                               in: dot,   thickness: thin) 		// active confinement dot
				}
		}
	}

	func drawTriangle(orientedUp: Bool, in iRect: CGRect, thickness: CGFloat) {
		let rect = self.rect(orientedUp: orientedUp, in: iRect)
		ZBezierPath.drawTriangle(orientedUp: orientedUp, in: rect, thickness: thickness )
	}

	func drawCircle(in rect: CGRect, thickness: CGFloat) {
		ZBezierPath.drawCircle(in: rect, thickness: thickness)
	}

	func drawCircle(orientedUp: Bool, in iRect: CGRect, thickness: CGFloat) {
		let rect = self.rect(orientedUp: orientedUp, in: iRect)
		ZBezierPath.drawCircle(in: rect, thickness: thickness)
	}

	func rect(orientedUp: Bool, in iRect: CGRect) -> CGRect {
		let offset = iRect.height * 1.75 * (orientedUp ? -1.0 : 1.0)
		let   rect = iRect.offsetBy(dx: 0.0, dy: offset)

		return rect
	}

}
