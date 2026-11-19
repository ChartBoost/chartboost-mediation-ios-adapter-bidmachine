// Copyright 2023-2026 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import BidMachine
import ChartboostMediationSDK
import Foundation
import UIKit

final class BidMachineAdapterRewardedAd: BidMachineAdapterAd, PartnerFullscreenAd {
    /// The BidMachineSDK ad instance.
    private var ad: RewardedAd?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)
        guard let bidMachine else {
            let error = error(.loadFailurePartnerNotInitialized)
            log(.loadFailed(error))
            completion(error)
            return
        }
        // A non-programmatic load needs the waterfall price to send as BidMachine's price floor.
        guard request.adm != nil || price != nil else {
            let error = error(.loadFailureInvalidAdRequest)
            log(.loadFailed(error))
            completion(error)
            return
        }
        loadCompletion = completion

        let handleLoadResult: (RewardedAd?, BidMachineError?) -> Void = { [weak self] ad, error in
            // BidMachine calls this completion on the main thread. The hop keeps access to the main-actor ad safe if it does not.
            DispatchQueue.main.async {
                guard let self else { return }
                guard let ad else {
                    let error = self.error(.loadFailureUnknown, error: error)
                    self.log(.loadFailed(error))
                    completion(error)
                    return
                }
                self.ad = ad
                ad.delegate = self
                self.log(.loadSucceeded)
                self.loadCompletion?(nil) ?? self.log(.loadResultIgnored)
                self.loadCompletion = nil
            }
        }

        if let adm = request.adm {
            bidMachine.loadRewarded(payload: adm, completion: handleLoadResult)
        } else {
            bidMachine.loadRewarded(placement: placement, completion: handleLoadResult)
        }
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        log(.showStarted)
        MainActor.assumeIsolated {
            guard let ad, ad.canShow else {
                let error = error(.showFailureAdNotReady)
                log(.showFailed(error))
                completion(error)
                return
            }
            showCompletion = completion
            ad.show(from: viewController)
        }
    }
}

extension BidMachineAdapterRewardedAd: RewardedAdDelegate {
    @MainActor
    func didPresent(_ ad: RewardedAd) {
        log(.showSucceeded)
        showCompletion?(nil) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    @MainActor
    func didFailPresent(_ ad: RewardedAd, error: BidMachineError) {
        log(.showFailed(error))
        showCompletion?(error) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    @MainActor
    func didTrackImpression(_ ad: RewardedAd) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    @MainActor
    func didClick(_ ad: RewardedAd) {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    @MainActor
    func didDismiss(_ ad: RewardedAd) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }

    @MainActor
    func didExpire(_ ad: RewardedAd) {
        log(.didExpire)
        delegate?.didExpire(self) ?? log(.delegateUnavailable)
    }

    @MainActor
    func didReceiveReward(_ ad: RewardedAd) {
        log(.didReward)
        delegate?.didReward(self) ?? log(.delegateUnavailable)
    }
}
