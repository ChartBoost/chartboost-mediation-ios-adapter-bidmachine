// Copyright 2023-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import UIKit
import BidMachine

final class BidMachineAdapter: PartnerAdapter {
    private let COPPA_KEY = "com.chartboost.adapter.bidmachine.coppa"
    private let GDPR_ZONE_KEY = "com.chartboost.adapter.bidmachine.gdprzone"
    private let GDPR_CONSENT_KEY = "com.chartboost.adapter.bidmachine.gdprconsent"
    private let US_PRIVACY_STRING_KEY = "com.chartboost.adapter.bidmachine.usprivacystring"

    private let SOURCE_ID_KEY = "source_id"

    private var coppa: Bool? {
        get { UserDefaults.standard.value(forKey: COPPA_KEY) as? Bool }
        set { UserDefaults.standard.setValue(newValue, forKey: COPPA_KEY) }
    }

    private var gdprZone: Bool? {
        get { UserDefaults.standard.value(forKey: GDPR_ZONE_KEY) as? Bool }
        set { UserDefaults.standard.setValue(newValue, forKey: GDPR_ZONE_KEY) }
    }

    private var gdprConsent: Bool? {
        get { UserDefaults.standard.value(forKey: GDPR_CONSENT_KEY) as? Bool }
        set { UserDefaults.standard.setValue(newValue, forKey: GDPR_CONSENT_KEY) }
    }

    private var usPrivacyString: String? {
        get { UserDefaults.standard.string(forKey: US_PRIVACY_STRING_KEY) }
        set { UserDefaults.standard.setValue(newValue, forKey: US_PRIVACY_STRING_KEY) }
    }

    /// The version of the partner SDK.
    let partnerSDKVersion = BidMachineSdk.sdkVersion
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.2.3.0.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "bidmachine"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "BidMachine"

    /// Ad storage managed by Chartboost Mediation SDK.
    let storage: PartnerAdapterStorage

    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {
        self.storage = storage
    }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)

        // Populate only the info we have non-nil saved values for
        if let coppa = coppa {
            BidMachineSdk.shared.regulationInfo.populate { $0.withCOPPA(coppa) }
        }
        if let gdprZone = gdprZone {
            BidMachineSdk.shared.regulationInfo.populate { $0.withGDPRZone(gdprZone) }
        }
        if let gdprConsent = gdprConsent {
            BidMachineSdk.shared.regulationInfo.populate { $0.withGDPRConsent(gdprConsent) }
        }
        if let usPrivacyString = usPrivacyString {
            BidMachineSdk.shared.regulationInfo.populate { $0.withUSPrivacyString(usPrivacyString) }
        }
        // These settings all have default values
        BidMachineSdk.shared.populate {
            $0.withTestMode(BidMachineAdapterConfiguration.testMode)
                .withLoggingMode(BidMachineAdapterConfiguration.logging)
                .withBidLoggingMode(BidMachineAdapterConfiguration.bidLogging)
                .withEventLoggingMode(BidMachineAdapterConfiguration.eventLogging)
        }

        guard let sourceID = configuration.credentials[SOURCE_ID_KEY] as? String else {
            let error = error(.initializationFailureInvalidCredentials, description: "The 'source ID' was invalid")
            log(.setUpFailed(error))
            completion(error)
            return
        }
        // Initialize the SDK
        BidMachineSdk.shared.initializeSdk(sourceID)
        guard BidMachineSdk.shared.isInitialized == true else {
            let error = error(.initializationFailureUnknown)
            log(.setUpFailed(error))
            completion(error)
            return
        }
        log(.setUpSucceded)
        completion(nil)
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        log(.fetchBidderInfoStarted(request))
        guard let token = BidMachineSdk.shared.token else {
            let error = error(.prebidFailureInvalidArgument, description: "No bidding token provided by BidMachine SDK")
            log(.fetchBidderInfoFailed(request, error: error))
            completion(nil)
            return
        }
        log(.fetchBidderInfoSucceeded(request))
        completion(["token": token])
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        if let applies = applies {
            gdprZone = applies
            log(.privacyUpdated(setting: "gdprZone", value: applies))
            // It is unknown whether populating this value after initializing the BidMachine SDK does anything
            BidMachineSdk.shared.regulationInfo.populate { $0.withGDPRZone(applies) }
        }

        // In the case where status == .unknown, we do nothing
        if status == .denied {
            gdprConsent = false
            log(.privacyUpdated(setting: "gdprConsent", value: false))
            // It is unknown whether populating this value after initializing the BidMachine SDK does anything
            BidMachineSdk.shared.regulationInfo.populate { $0.withGDPRConsent(false) }
        } else if status == .granted {
            gdprConsent = true
            log(.privacyUpdated(setting: "gdprConsent", value: true))
            // It is unknown whether populating this value after initializing the BidMachine SDK does anything
            BidMachineSdk.shared.regulationInfo.populate { $0.withGDPRConsent(true) }
        }
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        usPrivacyString = privacyString
        log(.privacyUpdated(setting: "usPrivacyString", value: privacyString))
        // It is unknown whether populating this value after initializing the BidMachine SDK does anything
        BidMachineSdk.shared.regulationInfo.populate { $0.withUSPrivacyString(privacyString) }
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        coppa = isChildDirected
        log(.privacyUpdated(setting: "COPPA", value: isChildDirected))
        // It is unknown whether populating this value after initializing the BidMachine SDK does anything
        BidMachineSdk.shared.regulationInfo.populate { $0.withCOPPA(isChildDirected) }
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        // Prevent multiple loads for the same partner placement, since the partner SDK cannot handle them.
        // Banner loads are allowed so a banner prefetch can happen during auto-refresh.
        // ChartboostMediationSDK 4.x does not support loading more than 2 banners with the same placement, and the partner may or may not support it.
        guard !storage.ads.contains(where: { $0.request.partnerPlacement == request.partnerPlacement })
            || request.format == .banner
        else {
            log("Failed to load ad for already loading placement \(request.partnerPlacement)")
            throw error(.loadFailureLoadInProgress)
        }
        
        switch request.format {
        case .interstitial:
            return BidMachineAdapterInterstitialAd(adapter: self, request: request, delegate: delegate)
        case .rewarded:
            return BidMachineAdapterRewardedAd(adapter: self, request: request, delegate: delegate)
        case .banner:
            return BidMachineAdapterBannerAd(adapter: self, request: request, delegate: delegate)
        default:
            // Not using the `.adaptiveBanner` case directly to maintain backward compatibility with Chartboost Mediation 4.0
            if request.format.rawValue == "adaptive_banner" {
                return BidMachineAdapterBannerAd(adapter: self, request: request, delegate: delegate)
            } else {
                throw error(.loadFailureUnsupportedAdFormat)
            }
        }
    }
}
