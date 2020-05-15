//
//  ZRingControl.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/27/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZRingControl: ZView, ZToolable {

	enum ZControlType {
		case eInsertion
		case eConfined
		case eToolTips
	}

	var type: ZControlType = .eToolTips
	static let    controls = [insertion, confined]
	func toolColor() -> ZColor? { return gIsDark ? kLightestGrayColor : gAccentColor.accountingForDarkMode.darker(by: 4.0) }
	func toolName()  -> String? { return labelText }

	var labelText: String {
		switch type {
			case .eInsertion: return gListsGrowDown           ? "down" : "up"
			case .eConfined:  return gBrowsingIsConfined      ? "list" : "all"
			case .eToolTips:  return gToolTipsLength != .none ? "hide" : "show" + "tool tips"
		}
	}

	override var description: String {
		switch type {
			case .eInsertion: return "toggle insertion direction"
			case .eConfined:  return "toggle browsing confinement (between list and all)"
			case .eToolTips:  return "toggle tool tips visibility"
		}
	}

	func shape(in rect: CGRect, contains point: CGPoint) -> Bool {
		let width = rect.width
		let inset = width /  5.0
		let  more = width /  2.5
		let  tiny = rect.insetEquallyBy(more)
		let large = rect.insetEquallyBy(inset)

		switch type           {
			case .eInsertion  :
				return point.intersectsTriangle  (orientedUp: gListsGrowDown, in: large)		// insertion direction
			case .eConfined   :
				if  gBrowsingIsConfined {
					return point.intersectsCircle(                            in: large) ||	// inactive confinement dot
					point.intersectsCircle(		                              in:  tiny)		// tiny dot
				} else        {
					return point.intersectsCircle(orientedUp: false,          in:  tiny) ||
					point.intersectsCircle(	 	  orientedUp: true,           in:  tiny)
				}
			default: return false
		}

	}

	override func draw(_ rect: CGRect) {
		super.draw(rect)

		let width = rect.width
		let thick = width / 20.0
		let inset = width /  5.0
		let  more = width /  2.5
		let  tiny = rect.insetEquallyBy(more)
		let large = rect.insetEquallyBy(inset)
		let color = gNecklaceDotColor

		color.setStroke()

		switch type           {
			case .eInsertion  :
				drawTriangle  (orientedUp: gListsGrowDown, in: large, thickness: thick)		// insertion direction
			case .eConfined   :
				if  gBrowsingIsConfined {
					drawCircle(                            in: large, thickness: thick)		// inactive confinement dot
					drawCircle(                            in:  tiny, thickness: thick)		// tiny dot
				} else        {
					drawCircle(orientedUp: false,          in:  tiny, thickness: thick)
					drawCircle(orientedUp: true,           in:  tiny, thickness: thick)
				}
			default: break
		}
	}

	func respond() -> Bool {
		switch type {
			case .eToolTips: gToolTipsLength = gToolTipsLength.rotated
			default:         return !gFullRingIsVisible ? false : toggleRingControlModes(isDirection: type == .eInsertion)
		}

		return true
	}

	// MARK:- private
	// MARK:-

	static         let  tooltips = create(.eToolTips)
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
