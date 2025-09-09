// Copyright 2023-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import BidMachine
import ChartboostMediationSDK
import Foundation

final class BidMachineAdapterRewardedAd: BidMachineAdapterAd, PartnerFullscreenAd {
    /// The BidMachineSDK ad instance.
    private var ad: BidMachineRewarded?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)
        loadCompletion = completion

        // only the throwing call in do/catch
        let placement: BidMachinePlacement
        do {
            placement = try BidMachineSdk.shared.placement(from: .rewarded) {
                $0.withPlacementId(self.request.partnerPlacement)
            }
        } catch {
            log(.loadFailed(error))
            completion(error)
            return
        }

        // pre-bind to avoid capturing self in the builder
        let adm   = self.request.adm
        let price = self.price

        if adm == nil && price == nil {
            let error = error(.loadFailureInvalidAdRequest)
            log(.loadFailed(error))
            completion(error)
            return
        }

        let request = BidMachineSdk.shared.auctionRequest(placement: placement) { builder in
            if let adm {
                builder.withPayload(adm)
            } else if let price {
                // On Android the UUID is automatically generated, on iOS it must be passed in.
                // https://docs.bidmachine.io/docs/in-house-mediation-android#price-floor-parameters
                // https://docs.bidmachine.io/docs/ad-request#parameters
                builder.appendPriceFloor(price, UUID().uuidString)
            }
        }

        BidMachineSdk.shared.rewarded(request: request) { [weak self] rewarded, error in
            guard let self else { return }
            guard let ad = rewarded else {
                let error = self.error(.loadFailureUnknown, error: error)
                self.log(.loadFailed(error))
                completion(error)
                return
            }

            self.ad = ad
            ad.delegate = self
            ad.loadAd()
        }
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        log(.showStarted)
        ad?.controller = viewController
        guard let ad, ad.canShow else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(error)
            return
        }
        showCompletion = completion
        ad.presentAd()
    }
}

extension BidMachineAdapterRewardedAd: BidMachineAdDelegate {
    func didLoadAd(_ ad: BidMachine.BidMachineAdProtocol) {
        log(.loadSucceeded)
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func didFailLoadAd(_ ad: BidMachine.BidMachineAdProtocol, _ error: Error) {
        log(.loadFailed(error))
        loadCompletion?(error) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func didPresentAd(_ ad: BidMachineAdProtocol) {
        log(.showSucceeded)
        showCompletion?(nil) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func didFailPresentAd(_ ad: BidMachineAdProtocol, _ error: Error) {
        log(.showFailed(error))
        showCompletion?(error) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func didDismissAd(_ ad: BidMachineAdProtocol) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }

    func willPresentScreen(_ ad: BidMachineAdProtocol) {
        log(.delegateCallIgnored)
    }

    func didDismissScreen(_ ad: BidMachineAdProtocol) {
        log(.delegateCallIgnored)
    }

    func didUserInteraction(_ ad: BidMachineAdProtocol) {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    func didExpired(_ ad: BidMachineAdProtocol) {
        log(.didExpire)
        delegate?.didExpire(self) ?? log(.delegateUnavailable)
    }

    func didTrackImpression(_ ad: BidMachineAdProtocol) {
        log(.didTrackImpression)
        self.delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    func didTrackInteraction(_ ad: BidMachineAdProtocol) {
        log(.delegateCallIgnored)
    }

    func didReceiveReward(_ ad: BidMachineAdProtocol) {
        log(.didReward)
        delegate?.didReward(self) ?? log(.delegateUnavailable)
    }
}
