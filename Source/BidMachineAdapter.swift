// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import UIKit
import BidMachine
import BidMachineApiCore  // Needed for the PlacementFormat type

final class BidMachineAdapter: PartnerAdapter {
    private let SOURCE_ID_KEY = "source_id"

    /// The version of the partner SDK.
    var partnerSDKVersion: String {
        BidMachineAdapterConfiguration.partnerSDKVersion
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    var adapterVersion: String {
        BidMachineAdapterConfiguration.adapterVersion
    }

    /// The partner's unique identifier.
    var partnerID: String {
        BidMachineAdapterConfiguration.partnerID
    }

    /// The human-friendly partner name.
    var partnerDisplayName: String {
        BidMachineAdapterConfiguration.partnerDisplayName
    }

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
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.setUpStarted)

        BidMachineSdk.shared.populate {
            $0.withTestMode(BidMachineAdapterConfiguration.testMode)
                .withLoggingMode(BidMachineAdapterConfiguration.logging)
                .withBidLoggingMode(BidMachineAdapterConfiguration.bidLogging)
                .withEventLoggingMode(BidMachineAdapterConfiguration.eventLogging)
        }

        guard let sourceID = configuration.credentials[SOURCE_ID_KEY] as? String else {
            let error = error(.initializationFailureInvalidCredentials, description: "The 'source ID' was invalid")
            log(.setUpFailed(error))
            completion(.failure(error))
            return
        }

        // Apply initial consents
        setConsents(configuration.consents, modifiedKeys: Set(configuration.consents.keys))
        setIsUserUnderage(configuration.isUserUnderage)

        // Initialize the SDK
        BidMachineSdk.shared.initializeSdk(sourceID)
        guard BidMachineSdk.shared.isInitialized == true else {
            let error = error(.initializationFailureUnknown)
            log(.setUpFailed(error))
            completion(.failure(error))
            return
        }
        log(.setUpSucceded)
        completion(.success([:]))
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PartnerAdPreBidRequest, completion: @escaping (Result<[String : String], Error>) -> Void) {
        log(.fetchBidderInfoStarted(request))
        let placementFormat: BidMachineApiCore.PlacementFormat
        switch request.format {
        case PartnerAdFormats.banner:
            placementFormat = .banner
        case PartnerAdFormats.interstitial, PartnerAdFormats.rewardedInterstitial:
            placementFormat = .interstitial
        case PartnerAdFormats.rewarded:
            placementFormat = .rewarded
        default:
            let error = error(.prebidFailureUnsupportedAdFormat)
            log(.fetchBidderInfoFailed(request, error: error))
            completion(.failure(error))
            return
        }

        BidMachineSdk.shared.token(with: placementFormat) { [self] token in
            log(.fetchBidderInfoSucceeded(request))
            completion(.success(token.map { ["token": $0] } ?? [:]))
        }
    }

    /// Indicates that the user consent has changed.
    /// - parameter consents: The new consents value, including both modified and unmodified consents.
    /// - parameter modifiedKeys: A set containing all the keys that changed.
    func setConsents(_ consents: [ConsentKey: ConsentValue], modifiedKeys: Set<ConsentKey>) {
        if modifiedKeys.contains(partnerID) || modifiedKeys.contains(ConsentKeys.gdprConsentGiven) {
            let consent = consents[partnerID] ?? consents[ConsentKeys.gdprConsentGiven]
            switch consent {
            case ConsentValues.granted:
                BidMachineSdk.shared.regulationInfo.populate { $0.withGDPRConsent(true) }
                log(.privacyUpdated(setting: "gdprConsent", value: true))
            case ConsentValues.denied:
                BidMachineSdk.shared.regulationInfo.populate { $0.withGDPRConsent(false) }
                log(.privacyUpdated(setting: "gdprConsent", value: false))
            default:
                break   // do nothing
            }
        }

        if modifiedKeys.contains(ConsentKeys.tcf), let tcfString = consents[ConsentKeys.tcf] {
            let gdprApplies = UserDefaults.standard.string(forKey: .tcfGDPRAppliesKey) == .tcgGDPRAppliesTrue
            BidMachineSdk.shared.regulationInfo.populate {
                $0.withGDPRZone(gdprApplies)
                $0.withGDPRConsentString(tcfString)
            }
            log(.privacyUpdated(setting: "gdprConsentString", value: tcfString))
        }

        if modifiedKeys.contains(ConsentKeys.usp), let privacyString = consents[ConsentKeys.usp] {
            log(.privacyUpdated(setting: "usPrivacyString", value: privacyString))
            BidMachineSdk.shared.regulationInfo.populate { $0.withUSPrivacyString(privacyString) }
        }
    }

    /// Indicates that the user is underage signal has changed.
    /// - parameter isUserUnderage: `true` if the user is underage as determined by the publisher, `false` otherwise.
    func setIsUserUnderage(_ isUserUnderage: Bool) {
        log(.privacyUpdated(setting: "COPPA", value: isUserUnderage))
        BidMachineSdk.shared.regulationInfo.populate { $0.withCOPPA(isUserUnderage) }
    }

    /// Creates a new banner ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeBannerAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerBannerAd {
        // Multiple banner loads are allowed so a banner prefetch can happen during auto-refresh.
        // ChartboostMediationSDK 5.x does not support loading more than 2 banners with the same placement, and the partner may or may not support it.
        BidMachineAdapterBannerAd(adapter: self, request: request, delegate: delegate)
    }

    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeFullscreenAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerFullscreenAd {
        // Prevent multiple loads for the same partner placement, since the partner SDK cannot handle them.
        guard !storage.ads.contains(where: { $0.request.partnerPlacement == request.partnerPlacement }) else {
            log("Failed to load ad for already loading placement \(request.partnerPlacement)")
            throw error(.loadFailureLoadInProgress)
        }
        
        switch request.format {
        case PartnerAdFormats.interstitial:
            return BidMachineAdapterInterstitialAd(adapter: self, request: request, delegate: delegate)
        case PartnerAdFormats.rewarded, PartnerAdFormats.rewardedInterstitial:
            return BidMachineAdapterRewardedAd(adapter: self, request: request, delegate: delegate)
        default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }
}

private extension String {
    /// This key for the TCFv2 string when stored in UserDefaults is defined by the IAB in Consent Management Platform API Final v.2.2 May 2023
   /// https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/master/TCFv2/IAB%20Tech%20Lab%20-%20CMP%20API%20v2.md#what-is-the-cmp-in-app-internal-structure-for-the-defined-api
    static let tcfGDPRAppliesKey = "IABTCF_gdprApplies"
    /// The value for `tcfGDPRAppliesKey` that indicates that GDPR does apply.
    static let tcgGDPRAppliesTrue = "1"
}
