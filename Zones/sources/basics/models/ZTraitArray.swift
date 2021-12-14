//
//  ZTraitArray.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/22/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import Cocoa

extension ZTraitArray {

	init(set: Set<ZTrait>) {
		self.init()

		for trait in set {
			append(trait)
		}
	}

}
