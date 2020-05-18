//
//  ZNoteAndEssay.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/16/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
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
	func export() { essayZone?.exportToFile(.eEssay) }

	var shouldOverwrite: Bool {
		if  let          current = gCurrentEssay,
			current.noteTraitMaybe?.needsSave ?? false,
			current.essayLength != 0,
			let               i  = essayZone?.record?.recordID,
			i                   == essayID {	// been here before

			return false						// has not yet been saved. don't overwrite
		}

		return true
	}

}
