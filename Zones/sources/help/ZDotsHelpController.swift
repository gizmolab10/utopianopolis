//
//  ZDotsHelpController.swift
//  iFocus
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZDotsHelpController : ZGraphController {

	override var hereZone : Zone? { return gIsRecentlyMode ?  gRecents.root :  gFavoritesHereMaybe }

}
