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
	case eTopLevel   = "TopLevel"
	case ePrefs      = "Preferences"
	case eHelp       = "Help"
	case eMore		 = "More"
	case eMain		 = "Main"

	case eIdeas      = "Ideas"
    case eNew        = "New"
    case eNext       = "Next"
	case eDelete     = "Delete"

	case eSelection  = "Selection"
	case eExpand     = "Expand"
	case eCollapse   = "Collapse"
	case eFocus      = "Focus"

	case eGraph      = "Graph"
	case eFavorites  = "Favorites"
	case eEveryone   = "Everyone"
	case eMine       = "Mine"

	case eMove       = "Move"
	case eMoveUp     = "Move ⇧"
	case eMoveDown   = "Move ⇩"
	case eMoveLeft   = "Move ⇦"
	case eMoveRight  = "Move ⇨"

	case eBrowse     = "Browse"
	case eUp         = " ⇧ "
	case eDown       = " ⇩ "
	case eLeft       = " ⇦ "
	case eRight      = " ⇨ "
	case eTravel     = "Travel"

	case eHang       = "Reconnect"
	case eStorage    = "Storage"
	case eRefetch    = "Refetch"
	case eRefetchAll = "Refetch All"
}


var gActionsController: ZActionsController { return gControllers.controllerForID(.idActions) as! ZActionsController }


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector : ZoneSegmentedControl?
	override  var    controllerID : ZControllerID { return .idActions }
	var           isTopLevel : Bool { return currentFunction == .eTopLevel }
	var           currentFunction = ZFunction.eTopLevel


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        let ignoreThese: [ZSignalKind] = [.eSearch, .eFound]

        if !ignoreThese.contains(iKind) {
			update()
        }
    }
	
	
	@IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
		showTopLevel()
	}
	

	@IBAction func selectorAction(iControl: UISegmentedControl) {
		if  let    title = iControl.titleForSegment(at: iControl.selectedSegment),
			let function = function(for: title) {
			
			switch function {
			case .eSelection, .eTopLevel, .eStorage, .eBrowse, .eIdeas, .eMove, .eGraph,
				 .eMore:      currentFunction = function; update()
			case .eRefetchAll,
				 .eRefetch:   refetch(for: function == .eRefetchAll)
			case .eMine, .eEveryone,
				 .eFavorites: switchGraph(to: function)
			case .eDelete:    gGraphEditor.delete()
			case .eNew:       gGraphEditor.addIdea()
			case .eHang:      gBatches.unHang()
			case .eHelp:      openBrowserForFocusWebsite()
			case .eNext:      gGraphEditor.addNext() { iChild in iChild.edit() }
			case .eFocus:     gFocusing.focus(kind: .eSelected) { gGraphEditor.redrawSyncRedraw() }
			case .eTravel:    gFocusing.maybeTravelThrough(gSelecting.currentMoveable)
			case .eRight:     gGraphEditor.move(out: false, selectionOnly: true)  {}
			case .eLeft:      gGraphEditor.move(out: true,  selectionOnly: true)  {}
			case .eMoveRight: gGraphEditor.move(out: false, selectionOnly: false) {}
			case .eMoveLeft:  gGraphEditor.move(out: true,  selectionOnly: false) {}
			case .eUp:		  gGraphEditor.move(up:  true,  selectionOnly: true)
			case .eDown:      gGraphEditor.move(up:  false, selectionOnly: true)
			case .eMoveUp:    gGraphEditor.move(up:  true,  selectionOnly: false)
			case .eMoveDown:  gGraphEditor.move(up:  false, selectionOnly: false)
			case .eCollapse,
				 .eExpand:    expand(function == .eExpand)
			case .eMain:	  showTopLevel()
			default:          break
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

			if !isTopLevel {
				insert(.eMain)
				(selector.subviews[0] as UIView).tintColor = UIColor.red
			}
			

			switch currentFunction {
			case .eTopLevel:
				insert(.eIdeas)
				insert(.eSelection)
				insert(.eGraph)
				insert(.eBrowse)
				insert(.eMore)
			case .eIdeas:
				insert(.eNew)
				insert(.eNext)
				insert(.eDelete)
			case .eSelection:
				insert(.eExpand)
				insert(.eCollapse)
				insert(.eFocus)
				insert(.eMove)
			case .eMove:
				insert(.eMoveUp)
				insert(.eMoveDown)
				insert(.eMoveLeft)
				insert(.eMoveRight)
			case .eGraph:
				insert(.eMine)
				insert(.eEveryone)
				insert(.eFavorites)
			case .eBrowse:
				insert(.eUp)
				insert(.eDown)
				insert(.eLeft)
				insert(.eRight)
				insert(.eTravel)
			case .eStorage:
				insert(.eRefetch)
				insert(.eRefetchAll)
			case .eMore:
				insert( gIsLate ? .eHang : .eStorage )
				insert(.ePrefs)
				insert(.eHelp)
			default: break
			}
		}
	}
	
	
	// MARK:- functions
	// MARK:-
	
	
	func switchGraph(to iFunction: ZFunction) {
		let priorShown = showFavorites
		let    priorID = gDatabaseID

		switch iFunction {
		case .eMine:      showFavorites = false; gDatabaseID = .mineID
		case .eEveryone:  showFavorites = false; gDatabaseID = .everyoneID
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
		case .eFocus: return gFavorites.function
		default:      return iFunction.rawValue
		}
	}
	

    func function(for iTitle: String) -> ZFunction? {
		if let function = ZFunction(rawValue: iTitle) {
			return  function
		}
		
		return nil
    }

	
	func showTopLevel() {
		currentFunction = .eTopLevel
		
		update()
	}
	
	
	func expand(_ show: Bool) {
		gGraphEditor.generationalUpdate(show: show, zone: gSelecting.currentMoveable) {
			gGraphEditor.redrawSyncRedraw()
		}
	}
	

	func refetch(for iAll: Bool) {
		gBatches		 .unHang()
		gWidgets         .clearRegistry()
		gGraphController?.clear()
		gControllers     .startupCloudAndUI()
	}
	
}
