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
	case eGraph  	 = "Graph"
	case ePrefs      = "Preferences"
	case eHelp       = "Help"
	case eMain       = "Main"

	case eIdeas      = "Ideas"
    case eDelete     = "Delete"
    case eNew        = "New"
    case eNext       = "Next"
	case eFocus      = "Focus"
    case eTravel     = "Travel"

	case eHang       = "Reconnect"
	case eStorage    = "Storage"
	case eRefresh    = "Refresh"
	case eRefreshAll = "Refresh All"
}


var gActionsController: ZActionsController { return gControllers.controllerForID(.idActions) as! ZActionsController }


class ZActionsController : ZGenericController {

	@IBOutlet var   			 actionsButton : UIButton?
    @IBOutlet var  			   actionsSelector : ZoneSegmentedControl?
	@IBOutlet var actionsButtonWidthConstraint : NSLayoutConstraint?
	override  var                 controllerID : ZControllerID { return .idActions }
	var 						isMainFunction : Bool { return currentFunction == .eMain }
	var 					   currentFunction = ZFunction.eMain


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        let ignoreThese: [ZSignalKind] = [.eSearch, .eFound]

        if !ignoreThese.contains(iKind) {
			update()
        }
    }
	
	
	@IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
		showMain()
	}
	

	@IBAction func selectorAction(iControl: UISegmentedControl) {
		if  let    title = iControl.titleForSegment(at: iControl.selectedSegment),
			let function = function(for: title) {
			
			switch function {
			case .eStorage,
				 .eIdeas,
				 .eMain:	currentFunction = function; update()
			case .eRefreshAll,
				 .eRefresh: refresh(for: function == .eRefreshAll)
			case .eGraph:   gShowMainGraph = !gShowMainGraph; gControllers.signalFor(nil, multiple: [.eRelayout])
			case .eDelete:  gGraphEditor.delete()
			case .eNew:     gGraphEditor.addIdea()
			case .eHang:    gBatches.unHang()
			case .eHelp:    openBrowserForFocusWebsite()
			case .eNext:    gGraphEditor.addNext() { iChild in iChild.edit() }
			case .eFocus:   gFocusing.focus(kind: .eSelected) { gGraphEditor.redrawSyncRedraw() }
			case .eTravel:  gFocusing.maybeTravelThrough(gSelecting.currentMoveable)
			default:        break
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

			if  let                 button = actionsButton {
				let 				 title = " <- "
				actionsButtonWidthConstraint?.constant = isMainFunction ? 0.0 : title.widthForFont(gWidgetFont) + 15.0
				
				if !isMainFunction {
					let    emphasizedColor = ZColor.blue.lighter(by: 5.0)
					let          textColor = ZColor.blue
					button          .title = title
					button.backgroundColor = emphasizedColor
					
					button.setTitleColor(kWhiteColor, for: .normal)
					button.addBorder(thickness: 1.0, radius: 5.0, color: textColor.cgColor)
				}
			}

			switch currentFunction {
			case .eMain:
				insert(.ePrefs)
				insert(.eIdeas)
				insert(.eGraph)
				insert(.eHelp)

				if  gIsLate {
					insert(.eHang)
				} else {
					insert(.eStorage)
				}
			case .eIdeas:
				insert(.eDelete)
				insert(.eNew)
				insert(.eNext)
				insert(.eFocus)
				insert(.eTravel)
			case .eStorage:
				insert(.eRefresh)
				insert(.eRefreshAll)
			default: break
			}
		}
	}
	
	
	// MARK:- functions
	// MARK:-
	

	func title(for iFunction: ZFunction) -> String {
		switch iFunction {
		case .eFocus: return gFavorites.function
		case .eGraph: return gShowMainGraph ? "Favorites" : "Graph"
		default:      return iFunction.rawValue
		}
	}
	

    func function(for iTitle: String) -> ZFunction? {
		switch iTitle {
		case "Favorites": return .eGraph
		default: if let function = ZFunction(rawValue: iTitle) {
				return  function
			}
		}
		
		return nil
    }

	
	func showMain() {
		currentFunction = .eMain
		
		update()
	}
	
	
	func refresh(for iAll: Bool) {
		gBatches		 .unHang()
		gWidgets         .clearRegistry()
		gGraphController?.clear()
		gControllers     .startupCloudAndUI()
	}
	
}
