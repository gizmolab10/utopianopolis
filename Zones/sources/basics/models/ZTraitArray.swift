//
//  ZTraitArray.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/22/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import CloudKit
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

extension ZTraitArray {

	init(set: Set<ZTrait>) {
		self.init()

		for trait in set {
			append(trait)
		}
	}

}
