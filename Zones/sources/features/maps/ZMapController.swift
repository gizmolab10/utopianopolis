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

var gMapController    : ZMapController? { return gControllers.controllerForID(.idMainMap) as? ZMapController }
var gMapView          : ZMapView?       { return gMapController?.view as? ZMapView }
var gLinesAndDotsView : ZMapView?       { return gMapView?.decorationsView }

class ZMapController: ZGesturesController, ZScrollDelegate, ZGeometry {

	var                priorLocation = CGPoint.zero
	override  var       controllerID : ZControllerID  { return .idMainMap }
	var                mapLayoutMode : ZMapLayoutMode { return gMapLayoutMode }
	var                 inLinearMode : Bool           { return mapLayoutMode == .linearMode }
	var               inCircularMode : Bool           { return mapLayoutMode == .circularMode }
	var               canDrawWidgets : Bool           { return gCanDrawWidgets } // overridden by help dots controller
	var                   isExemplar : Bool           { return controllerID == .idHelpDots }
	var                    isMainMap : Bool           { return controllerID == .idMainMap }
	var                     hereZone : Zone?          { return gHereMaybe ?? gCloud?.rootZone }
	var                      mapType : ZMapType       { return .tMainMap }
	var                mapPseudoView : ZPseudoView?
	var                   hereWidget : ZoneWidget?
	var                     rootLine : ZoneLine?
	var                      mapView : ZMapView?
	@IBOutlet var  mapContextualMenu : ZContextualMenu?
	@IBOutlet var ideaContextualMenu : ZoneContextualMenu?
	override func controllerStartup() { controllerSetup(with: gMapView) }    // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup

	override func controllerSetup(with iMapView: ZMapView?) {
		if  let                     map = iMapView {
			mapView                     = map
			gestureView                 = map         // do this before calling super setup: it uses gesture view
			hereWidget                  = ZoneWidget (view: map)
			mapPseudoView               = ZPseudoView(view: map)
			view.layer?.backgroundColor = kClearColor.cgColor
			mapPseudoView?       .frame = map.frame

			if  isMainMap || isExemplar {
				map.setup(with: self)
			}

			super.controllerSetup(with: map)
			platformSetup()
			mapPseudoView?.addSubpseudoview(hereWidget!)
		}
	}

	func drawWidgets(for phase: ZDrawPhase) {
		if  canDrawWidgets {
			if  phase == .pDots, inLinearMode {
				rootLine?.draw(phase) // for here's drag dot
			}

			hereZone?.widget?.traverseAllWidgetProgeny() { widget in
				widget.draw(phase)
			}

			if  phase == .pLines, inCircularMode,
				gCirclesDisplayMode.contains(.cRings) {
				circularDrawLevelRings()      // now, draw level rings
			}
		}
	}

    #if os(OSX)
    
	func platformSetup() {}
    
    #elseif os(iOS)
    
    @IBOutlet weak var mobileKeyInput: ZMobileKeyInput?
    
    func platformSetup() {
		assignAsFirstResponder(mobileKeyInput)
    }

    #if false

	private func updateMinZoomScaleForSize(_ size: CGSize) {
        let           w = hereWidget
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
		gFavorites.push(gHere)
	}

	func recenter(_ SPECIAL: Bool = false) {
		gScaling          = 1.0
		gMapOffset        = !SPECIAL ? .zero : CGPoint(x: kHalfDetailsWidth, y: .zero)
		gMapRotationAngle = .zero

		layoutForCurrentScrollOffset()
	}

	func setNeedsDisplay() {
		mapView?                 .setNeedsDisplay()
		mapView?.decorationsView?.setNeedsDisplay()
	}

	func setAllSubviewsNeedDisplay() {
		mapView?                 .setAllSubviewsNeedDisplay()
		mapView?.decorationsView?.setAllSubviewsNeedDisplay()
	}

	var doNotLayout: Bool {
		return (kIsPhone && (isMainMap == gShowFavoritesMapForIOS)) || (isMainMap && (gIsEditIdeaMode || gIsEssayMode))
	}

	func createAndLayoutWidgets(_ kind: ZSignalKind) {
		createWidgets(kind)
		layoutForCurrentScrollOffset()
	}

    func createWidgets(_ kind: ZSignalKind) {
		if  kind == .sResize { return }

		if  doNotLayout {
			if  isMainMap, gIsEssayMode {   // do not create widgets behind essay view
				mapView?.removeAllTextViews(ofType: .main)
				clearAllToolTips(for: isMainMap ? .main : .favorites)
			}

			return
		}

		printDebug(.dSpeed, "\(zClassName) createWidgets")

		hereWidget?.widgetZone = hereZone
		gTextCapturing         = false

		mapView?.removeAllTextViews(ofType: isMainMap ? .main : .favorites)           // clear remnants of prior loop

		// ////////////////// //
		// create widget tree //
		// ////////////////// //

		if  let total = hereWidget?.createPseudoViews(for: mapPseudoView, for: mapType, atIndex: nil, kind, visited: []) {
			printDebug(.dWidget, "layout \(mapType.description): \(total)")
		}

		if  let    w = hereWidget, (!isMainMap || gMapLayoutMode == .linearMode) {    // create drag dot for here
			let line = w.createLineFor(child: w)
			rootLine = line

			line.addDots(reveal: ZoneDot(view: w.absoluteView))
		}
    }

	var mapOrigin: CGPoint? {
		if  let      mapSize = mapView?.frame.size.dividedInHalf {
			let      mainMap = gMapOffset.offsetBy(-dotHeight, 22.0)
			let favoritesMap = CGPoint(x: -12.0, y: -6.0)
			let     exemplar = CGPoint(x: .zero, y: -8.0)
			var       offset = isExemplar ? exemplar : isMainMap ? mainMap : favoritesMap
			if  !kIsPhone {
				offset.y     = -offset.y    // default values are in iphone coordinates whereas y coordination is opposite in non-iphone devices
			}

			return (isMainMap ? CGPoint(mapSize) : .zero) + offset
		}

		return nil
	}

	func replaceAllToolTips(_ flags: ZEventFlags) {
		clearAllToolTips()
		updateAllToolTips(flags)
	}

	func updateAllToolTips(_ flags: ZEventFlags) {
		view.traverseHierarchy() { subview in
			if  let s = subview as? ZToolTipper {
				s.updateToolTips(flags)
			}

			return .eContinue
		}

		gWidgets.updateAllToolTips(flags)
	}

	func clearAllToolTips(for type: ZRelayoutMapType = .both) {
		view.traverseHierarchy() { subview in
			if  let t = subview as? ZoneTextWidget,
				let z = t.widgetZone,
				z.isInMap(of: type) {
				t.clearToolTips()
			}

			return .eContinue
		}

		gWidgets.clearAllToolTips(for: type)
	}

	func layoutForCurrentScrollOffset() {
		printDebug(.dSpeed, "\(zClassName) layoutForCurrentScrollOffset")

		clearAllToolTips(for: isMainMap ? .main : .favorites)
		gRemoveAllTracking()

		if  gIsEssayMode, isMainMap {
			return               // when in essay mode, do not process main map's widgets
		}

		if  let  mOrigin = mapOrigin,
			let   widget = hereWidget {
			let     size = widget.drawnSize.dividedInHalf
			let   origin = isMainMap ? mOrigin - size : mOrigin
			widget.frame = CGRect(origin: origin, size: size)

			widget.grandRelayout()
			updateAllToolTips(gModifierFlags) // potentially all new widgets (and their dots): regenerate all their tool tips
			detectHover()
			setAllSubviewsNeedDisplay()
		}
	}

	// MARK: - events
	// MARK: -

    override func handleSignal(kind: ZSignalKind) {
		if  !gDeferringRedraw, gIsReadyToShowUI {
			switch kind {
				case .sResize:
					resizeMapView()
					layoutForCurrentScrollOffset()
				case .sToolTips:
					replaceAllToolTips(gModifierFlags)
				default:
					createAndLayoutWidgets(kind)
			}
		}
	}

	func resizeMapView() {
		mapPseudoView?.frame = view.bounds

		mapView?.resize()
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture
	}

	func restartGestureRecognition() {
		gestureView?.gestureHandler = self

		gDragging.draggedZones.removeAll()
		gRemoveAllTracking() // fix fluttery cursor !!!!!!!!
	}

	func offsetEvent(move: Bool, to location: CGPoint) {
		if  move {
			gMapOffset = CGPoint(x: gMapOffset.x + location.x - priorLocation.x, y: gMapOffset.y + priorLocation.y - location.y)

			layoutForCurrentScrollOffset()
		}

		priorLocation = location
	}

	func rotationEvent(_ location: CGPoint) {
		if  let        origin = mapOrigin {
			let      endAngle = (location            - origin).angle
			let    startAngle = (gDragging.dragStart - origin).angle
			gMapRotationAngle = gDragging.startAngle - startAngle + endAngle
			gDragging.current = location

			layoutForCurrentScrollOffset()
		}
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
		if  gIgnoreEvents {
			return true
		}

		gExitSearchMode(force: false)
		gHideExplanation()

		if  gIsDraggableMode,
			let gesture  = iGesture as? ZPanGestureRecognizer {
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
		if  gIgnoreEvents {
			return
		}

		gExitSearchMode(force: false)
		gHideExplanation()

		if (gIsMapOrEditIdeaMode || gIsEssayMode),
		    let        gesture = iGesture as? ZKeyClickGestureRecognizer {
			let       location = gesture.location(in: mapView)
            var notEditingIdea = true

			printDebug(.dClick, "only")

			if  let editWidget = gCurrentlyEditingWidget {

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let   textRect = editWidget.convert(editWidget.bounds, to: mapView)
                notEditingIdea = !textRect.contains(location)
            }

            if  notEditingIdea {
				gTextEditor.stopCurrentEdit()

				if  gIsEssayMode {
					gEssayView?.exit()
				} else {
					gSetMapWorkMode()
				}

				if  let any = detectHit(at: location) {
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
						setNeedsDisplay()
					}
                } else if gIsEssayMode {
					gControllers.swapMapAndEssay(force: .wMapMode)
				}

                gSignal([.sData])
            }

            restartGestureRecognition()
        }
	}

    // MARK: - internals
    // MARK: -
    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: mapView)

            return rect.contains(location)
        }

        return false
    }

    func relationOf(_ point: CGPoint, to widget: ZoneWidget?) -> ZRelation {
        var     relation = ZRelation.upon
		if  let     text = widget?.pseudoTextWidget {
			let     rect = text.absoluteFrame.insetBy(dx: .zero, dy: 5.0)
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

}

