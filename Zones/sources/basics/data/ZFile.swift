//
//  ZFile.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/24/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

@objc(ZFile)
class ZFile : ZRecord {

	@NSManaged var data : Data?
	@NSManaged var name : String?
	@NSManaged var type : String?
	
}
