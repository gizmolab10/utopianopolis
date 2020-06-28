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
	@IBOutlet var accessIDLabel     : ZTextField?
	@IBOutlet var loadingLabel      : ZTextField?
	@IBOutlet var helpLabel         : ZTextField?
	@IBOutlet var pleaseWait        : ZView?
	@IBOutlet var acccessToAppleID  : ZView?
	@IBOutlet var enableCloudDrive  : ZView?
	@IBOutlet var buttonsView       : ZHelpButtonsView?
	@IBOutlet var thermometerBar    : ZStartupProgressBar?

	override func awakeFromNib() {
		super.awakeFromNib()
		buttonsView?.setupAndRedraw()

		enableCloudLabel?.text = enableText
		accessIDLabel?   .text = accessText
		loadingLabel?    .text = loadingText
		helpLabel?       .text = helpText

		if  gDebugMode.contains(.dNewUser) {
			gStartupLevel  = .firstTime
		}

		if  gStartupLevel == .localOkay {
			gStartupLevel  = .firstTime
		}
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  iKind == .sStartup {
			updateThermometerBar()
			updateSubviewVisibility()
			buttonsView?.updateAndRedraw()
		}
	}

	func updateSubviewVisibility() {
		let            hasInternet = gHasInternet
		let              firstTime = ![.pleaseWait, .ignoreDrive, .localOkay].contains(gStartupLevel)
		acccessToAppleID?.isHidden = !hasInternet || gStartupLevel != .firstTime   // .firstTime shows this
		enableCloudDrive?.isHidden = !hasInternet || gStartupLevel != .enableDrive // .firstTime hides this
		pleaseWait?      .isHidden =  hasInternet && firstTime                     // .firstTime hides this
	}

	func updateThermometerBar() {
		if !gHasFinishedStartup {
			thermometerBar?.update()
			view.setAllSubviewsNeedDisplay()
			thermometerBar?.display()
		}
	}

	@IBAction func handlePermissionAction(_ button: ZButton) {
		let      identifier = convertFromOptionalUserInterfaceItemIdentifier(button.identifier)
		switch   identifier {
			case    "id no": gStartupLevel = .localOkay
			case   "id yes": accessAppleID()
			case "continue": gStartupLevel = .pleaseWait

				gBatches.batch(.bResumeCloud) { result in
					self.refresh()
				}
			default:         break
		}

		refresh()
	}

	func refresh() {
		view.setAllSubviewsNeedDisplay()
		gSignal([.sStartup])
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
		gStartupLevel = .enableDrive

		refresh()
	}

	var accessText: String = [["Seriously is an iCloud enabled app.",
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

	var enableText: String = [["In order to share your Seriously data with your other devices running Seriously,",
							   "your cloud drive must be enabled.",
							   "Unfortunately, Apple security will not allow Seriously to enable it for you."].joined(separator: " "),
							  ["To enable it, please go to System Preferences,",
							   "Internet Accounts and select iCloud.",
							   "Look for iCloud Drive (it should be the first item)",
							   "and click on the button next to it labeled \"Options...\"",
							   "Scroll down until you see Seriously.",
							   "Check the box next to it."].joined(separator: " "),
							  "Then return here and click Continue, below."].joined(separator: "\n\n")

	var loadingText: String = "Your data is loading (it may take up to half a minute; sorry for the wait)."

	var helpText: String = "Would you like to look at something else than the progress bar?"

}
