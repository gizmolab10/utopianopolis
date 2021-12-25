//
//  ZMapController.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

var gMapController: ZMapController? { return gControllers.controllerForID(.idBigMap) as? ZMapController }
var gMapView:       ZMapView?       { return gDragView?.mapView }

class ZMapController: ZGesturesController, ZScrollDelegate {

	var           priorScrollLocation = CGPoint.zero
	var                 mapLayoutMode : ZMapLayoutMode { return gMapLayoutMode }
	override  var        controllerID : ZControllerID  { return .idBigMap }
	var                    widgetType : ZWidgetType    { return .tBigMap }
	var                    isExemplar : Bool           { return false }
	var                      isBigMap : Bool           { return true }
	var                      hereZone : Zone?          { return gHereMaybe ?? gCloud?.rootZone }
	var                          mode : ZMapLayoutMode { return isBigMap ? gMapLayoutMode : .linearMode }
	var                 mapPseudoView : ZPseudoView?
	var                    rootWidget : ZoneWidget?
	var                      rootLine : ZoneLine?
	@IBOutlet var   mapContextualMenu : ZContextualMenu?
	@IBOutlet var  ideaContextualMenu : ZoneContextualMenu?

	override func setup() {
		if  let                          map = gMapView {
			gestureView                      = gDragView                    // do this before calling super setup, which uses gesture view
			rootWidget                       = ZoneWidget (view: map)
			mapPseudoView                    = ZPseudoView(view: map)
			view     .layer?.backgroundColor = kClearColor.cgColor
			gMapView?.layer?.backgroundColor = kClearColor.cgColor
			if  let                    frame = gMapView?.frame {
				mapPseudoView?        .frame = frame
			}

			super.setup()
			platformSetup()
			mapPseudoView?.addSubpseudoview(rootWidget!)
		}
	}

	func drawWidgets(for phase: ZDrawPhase) {
		if  isBigMap || gDetailsViewIsVisible(for: .vSmallMap) {
			rootLine?.draw(phase) // for here's drag dot
			rootWidget?.traverseAllWidgetProgeny() { widget in
				widget.draw(phase)
			}
			
			// now, draw children ring
			
			if  phase     == .pLines,
				let center = rootWidget?.absoluteFrame.center {
				var level  = 1
				while ZWidgets.hasVisibleChildren   (at: level) {
					let radius = ZWidgets.ringRadius(at: level)
					let   rect = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
					let  color = gAccentColor.lighter(by: 2.0)
					level     += 1

					rect.drawColoredCircle(color, thickness: 0.2)
				}
			}
		}
	}

    #if os(OSX)
    
	func platformSetup() {}
    
    #elseif os(iOS)
    
    @IBOutlet weak var mobileKeyInput: ZMobileKeyInput?
    
    func platformSetup() {
        mobileKeyInput?.becomeFirstResponder()
    }

    #if false

	private func updateMinZoomScaleForSize(_ size: CGSize) {
        let           w = rootWidget
        let heightScale = size.height / w.bounds.height
        let  widthScale = size.width  / w.bounds.width
        let    minScale = min(widthScale, heightScale)
        gScaling        = Double(minScale)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateMinZoomScaleForSize(view.bounds.size)
    }

	#endif

	#endif

	// MARK: - operations
	// MARK: -

	func toggleMaps() {
		gToggleDatabaseID()
		gHere.grab()
		gHere.expand()
		gFavorites.updateCurrentFavorite()
	}

	func recenter(_ SPECIAL: Bool = false) {
		gScaling      = 1.0
		gScrollOffset = !SPECIAL ? .zero : CGPoint(x: kHalfDetailsWidth, y: 0.0)
		
		layoutForCurrentScrollOffset()
	}

	func layoutForCurrentScrollOffset() {
		printDebug(.dSpeed, "\(zClassName) layoutForCurrentScrollOffset")

		var            offset = isExemplar ? .zero : isBigMap ? gScrollOffset.offsetBy(0.0, 20.0) : CGPoint(x: -12.0, y: -6.0)
		offset.y              = -offset.y               // why?
		if  let          size = rootWidget?.drawnSize {
			let      relocate = CGPoint((view.frame.size - size).multiplyBy(0.5))
			let        origin = (isBigMap ? relocate : .zero) + offset
			rootWidget?.frame = CGRect(origin: origin, size: size)

			rootWidget?.grandUpdate()
			detectHover(at: gMapView?.currentMouseLocationInWindow)
			gMapView?.setNeedsDisplay()
		}
	}

	var doNotLayout: Bool {
		return (kIsPhone && (isBigMap == gShowSmallMapForIOS)) || gIsEditIdeaMode
	}

    func layoutWidgets(for iZone: Any?, _ kind: ZSignalKind) {
		if  doNotLayout || kind == .sResize { return }

		printDebug(.dSpeed, "\(zClassName) layoutWidgets")

		var specificIndex:    Int?
		let specificView           = mapPseudoView
		var specificWidget         = rootWidget
        var              recursing = true
		let                   here = hereZone
        specificWidget?.widgetZone = here
		gTextCapturing             = false
        if  let               zone = iZone as? Zone,
            let             widget = zone.widget,
			widget.type           == zone.widgetType {
            specificWidget         = widget
            specificIndex          = zone.siblingIndex
            recursing              = [.sData, .spRelayout].contains(kind)
        }

		let type : ZRelayoutMapType = isBigMap ? .big : .small

		gMapView?.removeAllTextViews(ofType: type)

		let total = specificWidget?.layoutAllPseudoViews(parentPseudoView: specificView, for: widgetType, atIndex: specificIndex, recursing: recursing, kind, visited: [])

		if  let    r = rootWidget, (!isBigMap || gMapLayoutMode == .linearMode) {
			let line = r.createLineFor(child: r)
			rootLine = line

			line.addDots(reveal: ZoneDot(view: r.absoluteView))
		}

		layoutForCurrentScrollOffset()

		if  let t = total {
			printDebug(.dWidget, "layout \(widgetType.description): \(t)")
		}
    }

	// MARK: - events
	// MARK: -

    override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  !gDeferringRedraw, gIsReadyToShowUI {
			if  kind == .sResize {
				resize()
				layoutForCurrentScrollOffset()
			} else {
				layoutWidgets(for: iSignalObject, kind)
			}

			gDragView?.setAllSubviewsNeedDisplay()
		}
	}

	func resize() {
		mapPseudoView?.frame = view.bounds

		gMapView?.resize()
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture
	}

	func restartGestureRecognition() {
		gestureView?.gestureHandler = self

		gDragging.draggedZones.removeAll()
	}

	func scrollEvent(move: Bool, to location: CGPoint) {
		if  move {
			gScrollOffset = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)

			layoutForCurrentScrollOffset()
		}

		priorScrollLocation = location
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if  gIsDraggableMode,
			let gesture  = iGesture as? ZKeyPanGestureRecognizer {
			let location = gesture.location(in: gesture.view)

			printDebug(.dClick, "drag")

			if  isEditingText(at: location) {
				restartGestureRecognition()                       // let text editor consume the gesture
			} else {
				gDragging.handleDragGesture(gesture, in: self)
			}

			return true
        }

		return false
    }
	
	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if (gIsMapOrEditIdeaMode || gIsEssayMode),
		    let    gesture  = iGesture as? ZKeyClickGestureRecognizer {
			let   location  = gesture.location(in: gMapView)
            let editWidget  = gCurrentlyEditingWidget
            var  notInEdit  = true

			printDebug(.dClick, "only")

			if  editWidget != nil {

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let textRect = editWidget!.convert(editWidget!.bounds, to: gMapView)
                notInEdit    = !textRect.contains(location)
            }

            if  notInEdit {

				if !gIsEssayMode {
					gSetBigMapMode()
				}

				gTextEditor.stopCurrentEdit()
				
				if  let any = detect(at: location) {
					if  let w = any as? ZoneWidget {
						w.widgetZone?.grab()
					} else if let d = any as? ZoneDot,
						let   flags = gesture.modifiers {
						d.widgetZone?.dotClicked(flags, isReveal: d.isReveal)
					}
				} else if gIsMapMode {

					// //////////////////////
					// click in background //
					// //////////////////////

					if !kIsPhone {	// default reaction to click on background: select here
						gHereMaybe?.grab()  // safe version of here prevent crash early in launch
						gMapView?.setNeedsDisplay()
					}
                } else if gIsEssayMode {
					gControllers.swapMapAndEssay(force: .wMapMode)
				}

                gSignal([ZSignalKind.sData])
            }

            restartGestureRecognition()
        }
	}

    // MARK: - internals
    // MARK: -

	func widgetHit(by gesture: ZGestureRecognizer?, locatedInBigMap: Bool = true) -> (Bool, Zone?, CGPoint)? {
		if  let         viewG = gesture?.view,
			let     locationM = gesture?.location(in: viewG),
			let       widgetM = rootWidget?.widgetNearestTo(locationM, in: mapPseudoView, hereZone) {
			let     alternate = isBigMap ? gSmallMapController : gMapController
			if  let  mapViewA = alternate?.mapPseudoView, !kIsPhone,
				let locationA = mapPseudoView?.convertPoint(locationM, toRootPseudoView: mapViewA),
				let   widgetA = alternate?.rootWidget?.widgetNearestTo(locationA, in: mapViewA, alternate?.hereZone),
				let  dragDotM = widgetM.parentLine?.dragDot,
				let  dragDotA = widgetA.parentLine?.dragDot {
				let   vectorM = dragDotM.absoluteFrame.center - locationM
				let   vectorA = dragDotA.absoluteFrame.center - locationM
				let   lengthM = vectorM.length
				let   lengthA = vectorA.length

				// ////////////////////////////////////////////////////// //
				// determine which drag dot's center is closest to cursor //
				// ////////////////////////////////////////////////////// //

				if  lengthA < lengthM {
					return (false, widgetA.widgetZone, locatedInBigMap ? locationM : locationA)
				}
			}

            return (true, widgetM.widgetZone, locationM)
        }

        return nil
    }
    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: gMapView)

            return rect.contains(location)
        }

        return false
    }

    func relationOf(_ point: CGPoint, to iWidget: ZoneWidget?) -> ZRelation {
        var     relation = ZRelation.upon
		if  let     text = iWidget?.pseudoTextWidget {
			let     rect = text.absoluteFrame.insetBy(dx: 0.0, dy: 5.0)
			let     minY = rect.minY
			let     maxY = rect.maxY
			let        y = point.y
            if         y < minY {
                relation = .below
            } else if  y > maxY {
                relation = .above
			}
		}

        return relation
    }

    // MARK: - detect
    // MARK: -

	func detect(at location: CGPoint) -> Any? {
		if  isBigMap,
			let    any = gSmallMapController?.detect(at: location) {
			return any
		}
		
		return rootWidget?.detect(at: location)
	}

}

