//
//  ZSearchHelpDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/25/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

// the default behavior is cool enough, for now

let gHelpSearchDelegate = ZHelpSearchDelegate()

class ZHelpSearchDelegate: NSObject, NSUserInterfaceItemSearching {

	func localizedTitles(forItem item: Any) -> [String] { return [kEmpty] }

	func searchForItems(withSearch searchString: String, resultLimit: Int, matchedItemHandler handleMatchedItems: @escaping ([Any]) -> Void) {
		handleMatchedItems([])
	}

}
