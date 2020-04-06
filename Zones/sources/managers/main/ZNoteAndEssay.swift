//
//  ZNoteAndEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 2/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let gNoteAndEssay = ZNoteAndEssay()

class ZNoteAndEssay: NSObject {

	var   essayID : CKRecord.ID?
	var essayZone : Zone? { return gCurrentEssay?.zone }
	func export() { gFiles.exportToFile(.eEssay, for: essayZone) }

	var shouldOverwrite: Bool {
		if  let current = gCurrentEssay,
			current.noteTraitMaybe?.needsSave ?? false,
			current.essayLength != 0,
			let i = gNoteAndEssay.essayID,
			i == essayZone?.record?.recordID {	// been here before

			return false						// has not yet been saved. don't overwrite
		}

		return true
	}

}
