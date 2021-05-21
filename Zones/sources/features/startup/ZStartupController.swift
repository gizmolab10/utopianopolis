//
//  ZStartupController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/2/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import AuthenticationServices

var gStartupController: ZStartupController? { return gControllers.controllerForID(.idStartup) as? ZStartupController }

class ZStartupController: ZGenericController, ASAuthorizationControllerDelegate {

	override  var controllerID      : ZControllerID { return .idStartup }
	@IBOutlet var enableCloudLabel  : ZTextField?
	@IBOutlet var operationLabel    : ZTextField?
	@IBOutlet var accessIDLabel     : ZTextField?
	@IBOutlet var loadingLabel      : ZTextField?
	@IBOutlet var helpLabel         : ZTextField?
	@IBOutlet var pleaseWait        : ZView?
	@IBOutlet var acccessToAppleID  : ZView?
	@IBOutlet var enableCloudDrive  : ZView?
	@IBOutlet var buttonsView       : ZHelpButtonsView?
	@IBOutlet var thermometerBar    : ZStartupProgressBar?
	var           startupCompletion : Closure?

	override func awakeFromNib() {
		super.awakeFromNib()
		buttonsView?.setupAndRedraw()

		gMainController?.helpButton?.isHidden = true
		buttonsView?                .isHidden = true // stupid thing doesn't respond to clicks
		thermometerBar?             .isHidden = true // stupid thing doesn't advance until end of event cycle
		enableCloudLabel?.text = enableCloudDriveText
		accessIDLabel?   .text = appleIDText
		loadingLabel?    .text = loadingText
//		helpLabel?       .text = helpText

		if  gNewUser ||
			gStartupLevel == .localOkay {
			gStartupLevel  = .firstTime
		}
	}

	override func viewWillAppear() {
		super .viewWillAppear()
		fullStartupUpdate()
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		switch iKind {
//			case .sStartupButtons:  buttonsView?.updateAndRedraw()
			case .sStartupStatus: updateThermometerBar(); updateSubviewVisibility()
			default: break
		}
	}

	func getPermissionFromUser(onCompletion: Closure? = nil) {
		if  gStartupLevel == .pleaseWait || !gHasInternet {
			onCompletion?()
		} else {
			startupCompletion = onCompletion
		}

		FOREGROUND(canBeDirect: true) {
			self.fullStartupUpdate()
		}
	}

	func fullStartupUpdate() {
		if !gHasFinishedStartup, gStartup.elapsedEnough {
			updateThermometerBar()
			updateSubviewVisibility()
			buttonsView?.updateAndRedraw()
//			CFRunLoopRun()
			RunLoop.main.acceptInput(forMode: .default, before: Date().addingTimeInterval(0.1))		// respond if user clicked a button
		}
	}

	func updateSubviewVisibility() {
		let            hasInternet = gHasInternet
		let                notWait = [.firstTime, .pleaseEnableDrive].contains(gStartupLevel)
		acccessToAppleID?.isHidden = !hasInternet || gStartupLevel != .firstTime         // .firstTime shows this
		enableCloudDrive?.isHidden = !hasInternet || gStartupLevel != .pleaseEnableDrive // .firstTime hides this
		pleaseWait?      .isHidden =  hasInternet && notWait                             // .firstTime hides this
	}

	func updateThermometerBar() {
//		thermometerBar?.updateProgress()

		operationLabel?                  .text = gCurrentOp.fullStatus
		operationLabel?          .needsDisplay = true
		thermometerBar?          .needsDisplay = true
		gMainWindow?.contentView?.needsDisplay = true
		view                     .needsDisplay = true

		gApplication.setWindowsNeedUpdate(true)
		gApplication.updateWindows()
	}

	@IBAction func handlePermissionAction(_ button: ZButton) {
		let      identifier = convertFromOptionalUserInterfaceItemIdentifier(button.identifier)
		switch   identifier {
			case   "id yes": accessAppleID()
			case    "id no": gStartupLevel = .localOkay;  startupCompletion?()
			case "continue": gStartupLevel = .pleaseWait; startupCompletion?()

				gBatches.batch(.bResumeCloud) { result in
					self.refresh()
				}
			default:         break
		}

		refresh()
	}

	func refresh() {
		view.setAllSubviewsNeedDisplay()
		fullStartupUpdate()
	}

	func accessAppleID() {
		let                     provider = ASAuthorizationAppleIDProvider()
		let                      request = provider.createRequest()
		request         .requestedScopes = [.fullName, .email]
		let      authorizationController = ASAuthorizationController(authorizationRequests: [request])
		authorizationController.delegate = self

		authorizationController.performRequests()
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
		gStartupLevel = .pleaseEnableDrive

		refresh()
	}

	var appleIDText: String = [["Seriously is an iCloud enabled app.",
								"However, to reach iCloud, it needs access to your Apple ID.",
								"Please be confident that Seriously vigorously enforces security.",
								"Seriously will never allow anyone but you access to your Apple ID",
								"nor to the information you enter into Seriously in your private database."].joined(separator: " "),
							   ["Seriously can work without an internet connection.",
								"All your work is always saved locally.",
								"When an internet connection is established,",
								"Seriously will automatically upload your work."].joined(separator: " "),
							   ["To share your personal data with other devices you own which run Seriously",
								"this and those other devices must grant Seriously access to your Apple ID."].joined(separator: ", "),
							   "Do you want to grant such access to Seriously?"].joined(separator: "\n\n")

	var enableCloudDriveText: String = [["In order to share your Seriously data with your other devices running Seriously",
										 "your cloud drive must be enabled. Unfortunately",
										 "Apple security will not allow Seriously to enable it for you."].joined(separator: ", "),
										["To enable it, please go to System Preferences,",
										 "Internet Accounts and select iCloud.",
										 "Look for iCloud Drive (it should be the first item)",
										 "and click on the button next to it labeled \"Options...\"",
										 "Scroll down until you see Seriously.",
										 "Check the box next to it."].joined(separator: " "),
										"Then return here and click Continue, below."].joined(separator: "\n\n")

	var loadingText: String = ["Your data is loading (it can take up to several minutes the first time).",
							   "Please wait until the drawing (of ideas) appears to add new ideas to it.",
							   "Also, you may have to relaunch if the app gets stuck (it sometimes does)."].joined(separator: " ")

	var helpText: String = ["Would you like to look at something more interesting than this progress bar?",
							"Each button below takes you to a chart.",
							"Some contain clickable links to further detail.",
							"Warning, since this app is busy loading data, it may hesitate to respond to your mouse clicks."].joined(separator: " ")

}
