//
//  ZHelpNotesData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpNotesData: ZHelpData {

	override func objectValueFor(_ row: Int) -> NSMutableAttributedString {
		return NSMutableAttributedString(string: "note this, hah!")
	}

}
