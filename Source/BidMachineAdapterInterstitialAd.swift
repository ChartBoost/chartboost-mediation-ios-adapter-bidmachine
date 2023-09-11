// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import BidMachine

final class BidMachineAdapterInterstitialAd: BidMachineAdapterAd, PartnerAd {
    
    /// The BidMachineSDK ad instance.
    private var ad: BidMachineInterstitial?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)

        // Make request configuration
        let config: BidMachineRequestConfigurationProtocol
        do {
            config = try BidMachineSdk.shared.requestConfiguration(.interstitial)
        } catch {
            let chartboostMediationError = self.error(.loadFailureUnknown, error: error)
            log(.loadFailed(chartboostMediationError))
            completion(.failure(chartboostMediationError))
            return
        }

        // https://docs.bidmachine.io/docs/ad-request
        // Once our placements are live, there are a few things to figure out with trial
        // and error. First, see if '.populate' can be called multiple times.
        // That way, with.Payload() could only be called when there's an ADM (assuming I'm
        // correct about that being what they mean by payload. Maybe PlacementID isn't needed
        // when we're loading an ADM, and vice versa?
        config.populate {
            $0.withPlacementId(request.partnerPlacement)
        }

        BidMachineSdk.shared.interstitial(config) { [weak self] ad, error in
            guard let self = self else {
                return
            }
            guard let ad = ad else {
                let chartboostMediationError = self.error(.loadFailureUnknown, error: error)
                log(.loadFailed(chartboostMediationError))
                completion(.failure(chartboostMediationError))
                return
            }
            loadCompletion = completion
            self.ad = ad
            ad.controller = viewController
            ad.delegate = self
            ad.loadAd()
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        guard let ad = ad, ad.canShow else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }
        showCompletion = completion
        ad.presentAd()
    }
}

extension BidMachineAdapterInterstitialAd: BidMachineAdDelegate {
    func didLoadAd(_ ad: BidMachine.BidMachineAdProtocol) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func didFailLoadAd(_ ad: BidMachine.BidMachineAdProtocol, _ error: Error) {
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func didPresentAd(_ ad: BidMachineAdProtocol) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func didFailPresentAd(_ ad: BidMachineAdProtocol, _ error: Error) {
        log(.showFailed(error))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func didDismissAd(_ ad: BidMachineAdProtocol) {
        log(.delegateCallIgnored)
    }

    func willPresentScreen(_ ad: BidMachineAdProtocol) {
        log(.delegateCallIgnored)
    }

    func didDismissScreen(_ ad: BidMachineAdProtocol) {
        log(.delegateCallIgnored)
    }

    func didUserInteraction(_ ad: BidMachineAdProtocol) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func didExpired(_ ad: BidMachineAdProtocol) {
        log(.didExpire)
        delegate?.didExpire(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func didTrackImpression(_ ad: BidMachineAdProtocol) {
        log(.didTrackImpression)
        self.delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func didTrackInteraction(_ ad: BidMachineAdProtocol) {
        log(.delegateCallIgnored)
    }
}
