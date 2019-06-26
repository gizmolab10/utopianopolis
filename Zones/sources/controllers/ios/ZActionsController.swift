//
//  ZActionsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 9/24/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import UIKit


enum ZFunction: String {
	case eTop        = "At 7Top"
	case eToTop 	 = "Top"

	case eEdit       = "Edit"
    case eNew        = "New"
	case eNext       = "Next"
	case eName       = "Name"
	case eDelete     = "Delete"

	case eFocus      = "Focus"
	case eNarrow     = "Narrow"
	case eTravel     = "Travel"

	case eView       = "View"
	case eFavorites  = "Favorites"
	case ePublic     = "Public"
	case eMe         = "Me"
	case ePrefs      = "Preferences"

	case eMore		 = "More"
	case eHelp       = "Help"

	case eHang       = "Reconnect"
	case eStorage    = "Storage"
	case eRefetch    = "Refetch"
	case eRefetchAll = "Refetch All"
}


var gActionsController: ZActionsController { return gControllers.controllerForID(.idActions) as! ZActionsController }


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector : ZoneSegmentedControl?
	override  var    controllerID : ZControllerID { return .idActions }
	var                     isTop : Bool { return gCurrentFunction == .eTop }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        let ignoreThese: [ZSignalKind] = [.eSearch, .eFound]

        if !ignoreThese.contains(iKind) {
			update()
        }
    }
	
	
	@IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
		showTop()
	}
	

	@IBAction func selectorAction(iControl: UISegmentedControl) {
		if  let    title = iControl.titleForSegment(at: iControl.selectedSegment),
			let function = function(for: title) {
			
			switch function {
			case .eFocus, .eTop, .eStorage, .eEdit, .eView,
				 .eMore:      gCurrentFunction = function; update()
			case .eRefetchAll,
				 .eRefetch:   refetch(for: function == .eRefetchAll)
			case .ePrefs, .eMe, .ePublic,
				 .eFavorites: switchView(to: function)
			case .eDelete:    gGraphEditor.delete()
			case .eNew:       gGraphEditor.addIdea()
			case .eHang:      gBatches.unHang()
			case .eHelp:      openBrowserForFocusWebsite()
			case .eNext:      gGraphEditor.addNext() { iChild in iChild.edit() }
			case .eNarrow:    gFocusing.focus(kind: .eSelected) { gGraphEditor.redrawSyncRedraw() }
			case .eTravel:    gFocusing.maybeTravelThrough(gSelecting.currentMoveable)
			case .eToTop:	  showTop()
			case .eName: break
			}
		}
	}
	

	func update() {
		if  let selector = actionsSelector {
			let     font = UIFont.systemFont(ofSize: 17)
			
			selector.setTitleTextAttributes([NSAttributedString.Key.font : font], for: .normal)
			selector.apportionsSegmentWidthsByContent = true
			selector.removeAllSegments()

			var index  = -1
			let insert = { (iFunction: ZFunction) -> Void in
				index += 1

				selector.insertSegment(withTitle: self.title(for: iFunction), at:index, animated: false)
			}

			if !isTop {
				insert(.eToTop)
				(selector.subviews[0] as UIView).tintColor = UIColor.red
			}

			switch gCurrentFunction {
			case .eTop:
				insert(.eEdit)
				insert(.eFocus)
				insert(.eView)
				insert(.eMore)
			case .eEdit:
				insert(.eNew)
				insert(.eNext)
				insert(.eName)
				insert(.eDelete)
			case .eFocus:
				insert(.eNarrow)
				insert(.eTravel)
			case .eView:
				insert(.eFavorites)
				insert(.ePublic)
				insert(.eMe)
				insert(.ePrefs)
			case .eStorage:
				insert(.eRefetch)
				insert(.eRefetchAll)
			case .eMore:
				insert( gIsLate ? .eHang : .eStorage )
				insert(.eHelp)
			default: break
			}
		}
	}
	
	
	// MARK:- functions
	// MARK:-
	
	
	func switchView(to iFunction: ZFunction) {
		let priorShown = showFavorites
		let    priorID = gDatabaseID

		switch iFunction {
		case .eMe:        showFavorites = false; gDatabaseID = .mineID
		case .ePublic:    showFavorites = false; gDatabaseID = .everyoneID
		case .eFavorites: showFavorites = true
		default: break
		}
		
		if  gDatabaseID != priorID || showFavorites != priorShown {
			gSelecting.updateAfterMove()
			gControllers.signalFor(nil, multiple: [.eRelayout])
		}
	}
	

	func title(for iFunction: ZFunction) -> String {
		switch iFunction {
		case .eFocus: return favoritesFunction
		default:      return iFunction.rawValue
		}
	}
	

	var favoritesFunction: String {
		let zone  = gSelecting.currentMoveable
		
		if  zone == gHere {
			return gFavorites.workingFavorites.contains(zone) ? "Unfavorite" : "Favorite"
		}
		
		return "Focus"
	}
	

    func function(for iTitle: String) -> ZFunction? {
		if let function = ZFunction(rawValue: iTitle) {
			return  function
		}
		
		return nil
    }

	
	func showTop() {
		gCurrentFunction = .eTop
		
		update()
	}
	

	func refetch(for iAll: Bool) {
		gBatches		 .unHang()
		gWidgets         .clearRegistry()
		gGraphController?.clear()
		gControllers     .startupCloudAndUI()
	}
	
}
