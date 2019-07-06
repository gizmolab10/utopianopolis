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
	case eHelp       = "Help"
	case ePrefs      = "Preferences"

	case eEdit       = "Edit"
    case eNew        = "New"
	case eNext       = "Next"
	case eName       = "Name"
	case eDelete     = "Delete"

	case eFocus      = "Focus"
	case eNarrow     = "Narrow"
	case eTravel     = "Travel"

	case eMore		 = "More"
	case eHang       = "Reconnect"
	case eRefetch    = "Refetch"
	case eRefetchAll = "Refetch All"

	case eFavorites  = "Favorites"
	case ePublic     = "Public"
	case eMe         = "Me"
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
			let     zone = gSelecting.currentMoveable
			
			switch function {
			case .eFocus, .eTop, .eEdit,
				 .eMore:    gCurrentFunction = function; update()
			case .eRefetchAll,
				 .eRefetch: refetch(for: function == .eRefetchAll)
			case .ePrefs:   switchView(to: function)
			case .eDelete:  gGraphEditor.delete()
			case .eNew:     gGraphEditor.addIdea()
			case .eHang:    gBatches.unHang()
			case .eName:    gTextEditor.edit(zone)
			case .eHelp:    openBrowserForFocusWebsite()
			case .eNext:    gGraphEditor.addNext() { iChild in iChild.edit() }
			case .eNarrow:  gFocusing.focus(kind: .eSelected) { gGraphEditor.redrawSyncRedraw() }
			case .eTravel:  gFocusing.maybeTravelThrough(zone)
			case .eToTop:   showTop()
			default:        break
			}
		}
	}
	

	func update() {
		if  let actions = actionsSelector {
			let    font = UIFont.systemFont(ofSize: 17)
			
			actions.setTitleTextAttributes([NSAttributedString.Key.font : font], for: .normal)
			actions.apportionsSegmentWidthsByContent = true
			actions.removeAllSegments()
			
			var index  = -1
			let insert = { (iFunction: ZFunction) -> Void in
				index += 1
				
				actions.insertSegment(withTitle: self.title(for: iFunction), at:index, animated: false)
			}
			
			if !isTop {
				insert(.eToTop)
				(actions.subviews[0] as UIView).tintColor = UIColor.red
			}
			
			switch gCurrentFunction {
			case .eTop:
				insert(.eEdit)
				insert(.eFocus)
				insert(.eMore)
				insert(.eHelp)
				insert(.ePrefs)
			case .eEdit:
				insert(.eNew)
				insert(.eNext)
				insert(.eName)
				insert(.eDelete)
			case .eFocus:
				insert(.eNarrow)
				insert(.eTravel)
			case .eMore:
				insert(.eRefetch)
				insert(.eRefetchAll)
				if gIsLate { insert(.eHang) }
			default: break
			}
		}
	}
	
	
	// MARK:- functions
	// MARK:-
	
	
	func alignView() {
		switch gDatabaseID {
		case .everyoneID: gCurrentGraph = .ePublic
		default:          gCurrentGraph = .eMe
		}
	}
	
	
	func switchView(to iFunction: ZFunction) {
		let priorShown = gShowFavorites
		let    priorID = gDatabaseID

		switch iFunction {
		case .eMe:        gShowFavorites = false; gDatabaseID = .mineID
		case .ePublic:    gShowFavorites = false; gDatabaseID = .everyoneID
		case .eFavorites: gShowFavorites = true
		default: break
		}
		
		if  gDatabaseID != priorID || gShowFavorites != priorShown {
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
		
		if  zone == gHereMaybe {
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
