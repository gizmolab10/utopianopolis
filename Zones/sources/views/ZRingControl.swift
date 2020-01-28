//
//  ZRingControl.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/27/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZControlType {
	case eVisible
	case eInsertion
	case eConfined
}

class ZRingControl: ZView {
	var       type: ZControlType = .eVisible
	private static let insertion = create(.eInsertion)
	private static let  confined = create(.eConfined)
	private static let   visible = create(.eVisible)
	static let          controls = [visible, insertion, confined]

	func response() -> Bool {
		if gFullRingIsVisible { print(type) }

		switch type {
			case .eVisible: gFullRingIsVisible = !gFullRingIsVisible
			default: return gFullRingIsVisible
		}

		return true
	}

	private static func create(_ type: ZControlType) -> ZRingControl {
		let  control = ZRingControl()
		control.type = type

		return control
	}

}
