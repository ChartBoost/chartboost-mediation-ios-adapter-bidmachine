// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import BidMachine

final class BidMachineAdapterRewardedAd: BidMachineAdapterAd, PartnerAd {

    /// The BidMachineSDK ad instance.
    private var ad: BidMachineRewarded?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)

        // Make request configuration
        let config: BidMachineRequestConfigurationProtocol
        do {
            config = try BidMachineSdk.shared.requestConfiguration(.rewarded)
        } catch {
            self.log(.loadFailed(error))
            completion(.failure(error))
            return
        }

        loadCompletion = completion

        if let adm = request.adm {
            config.populate { $0.withPayload(adm) }
        } else {
            config.populate {
                guard let price else {
                    let error = error(.loadFailureInvalidAdRequest)
                    self.log(.loadFailed(error))
                    completion(.failure(error))
                    return
                }
                // On Android the UUID is automatically generated, on iOS it must be passed in.
                // https://docs.bidmachine.io/docs/in-house-mediation-android#price-floor-parameters
                // https://docs.bidmachine.io/docs/ad-request#parameters
                $0.withPlacementId(request.partnerPlacement)
                .appendPriceFloor(price, UUID().uuidString)
            }
        }

        BidMachineSdk.shared.rewarded(config) { [weak self] ad, error in
            guard let self = self else {
                return
            }
            guard let ad = ad else {
                let chartboostMediationError = self.error(.loadFailureUnknown, error: error)
                self.log(.loadFailed(chartboostMediationError))
                completion(.failure(chartboostMediationError))
                return
            }
            self.ad = ad
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
        ad?.controller = viewController
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

extension BidMachineAdapterRewardedAd: BidMachineAdDelegate {
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
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil)  ?? log(.delegateUnavailable)
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

    func didReceiveReward(_ ad: BidMachineAdProtocol) {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
}

