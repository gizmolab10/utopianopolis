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
	@IBOutlet var thermometerBar    : ZStartupProgressBar?
	var           startupCompletion : Closure?

	override func awakeFromNib() {
		super.awakeFromNib()

		gMainController?.helpButton?.isHidden = true
		enableCloudLabel?.text = enableCloudDriveText
		accessIDLabel?   .text = appleIDText
		loadingLabel?    .text = loadingText

		if  gNewUser ||
			gStartupLevel == .localOkay {
			gStartupLevel  = .firstTime
		}
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		startupUpdate()
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		switch kind {
			case .spStartupStatus: updateStartupStatus()
			default: break
		}
	}

	func getPermissionFromUser(onCompletion: Closure? = nil) {
		if  gStartupLevel == .pleaseWait || !gHasInternet {
			onCompletion?()
		} else {
			startupCompletion = onCompletion
		}
	}

	func pingRunloop() {
		startupUpdate()
	}

	func startupUpdate() {
		if !gHasFinishedStartup, gStartup.oneTimerIntervalHasElapsed {
			FOREGROUND(forced: true) {
				self.updateStartupStatus()
			}
		}
	}

	func updateStartupStatus() {
		let            hasInternet = gHasInternet
		let                notWait = [.firstTime, .pleaseEnableDrive].contains(gStartupLevel)
		acccessToAppleID?.isHidden = !hasInternet || gStartupLevel != .firstTime         // .firstTime shows this
		enableCloudDrive?.isHidden = !hasInternet || gStartupLevel != .pleaseEnableDrive // .firstTime hides this
		pleaseWait?      .isHidden =  hasInternet && notWait                             // " " "

		if  gAssureProgressTimesAreLoaded() {
			let       statusText = gCurrentOp.fullStatus
			let         rootView = gMainWindow?.contentView
			operationLabel?.text = statusText

//			print(statusText)

			rootView?.applyToAllVisibleSubviews { v in
				v.setNeedsDisplay()
			}

			thermometerBar?.updateProgress()
			gApplication.setWindowsNeedUpdate(true)
			gApplication.updateWindows()

//			rootView?.applyToAllVisibleSubviews { v in
//				v.display()
//			}
		}
	}

	@IBAction func handlePermissionAction(_ button: ZButton) {
		let      identifier = gConvertFromOptionalUserInterfaceItemIdentifier(button.identifier)
		switch   identifier {
			case   "id yes": accessAppleID()
			case    "id no": gStartupLevel = .localOkay;  startupCompletion?()
			case "continue": gStartupLevel = .pleaseWait; startupCompletion?()

				gBatches.batch(.bResumeCloud) { result in
					self.startupUpdate()
				}
			default:         break
		}

		startupUpdate()
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

		startupUpdate()
	}

	var appleIDText: String = [["Seriously is an iCloud enabled app.",
								"However, to reach iCloud, it needs access to your Apple ID.",
								"Please be confident that Seriously vigorously enforces security.",
								"Seriously will never allow anyone but you access to your Apple ID",
								"nor to the information you enter into Seriously in your private database."].joined(separator: kSpace),
							   ["Seriously can work without an internet connection.",
								"All your work is always saved locally.",
								"When an internet connection is established,",
								"Seriously will automatically upload your work."].joined(separator: kSpace),
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
										 "Check the box next to it."].joined(separator: kSpace),
										"Then return here and click Continue, below."].joined(separator: "\n\n")

	var loadingText: String = ["Your data is loading (it can take up to a minute the first time).",
							   "Please wait until the drawing (of ideas) appears before adding new ideas to it."].joined(separator: kSpace)

	var helpText: String = ["Would you like to look at something more interesting than this progress bar?",
							"Each button below takes you to a chart.",
							"Some contain clickable links to further detail.",
							"Warning, since this app is busy loading data, it may hesitate to respond to your mouse clicks."].joined(separator: kSpace)

}
