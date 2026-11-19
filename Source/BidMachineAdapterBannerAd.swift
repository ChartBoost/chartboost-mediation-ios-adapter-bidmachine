// Copyright 2023-2026 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import BidMachine
import ChartboostMediationSDK
import Foundation
import UIKit

final class BidMachineAdapterBannerAd: BidMachineAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// The BidMachineSDK ad instance.
    private var ad: BannerView?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)

        guard
            let requestedSize = request.bannerSize,
            let loadedSize = ChartboostMediationSDK.BannerSize.largestStandardFixedSizeThatFits(in: requestedSize),
            let bannerSize = loadedSize.bidMachineAdSize
        else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            completion(error)
            return
        }
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
        self.size = PartnerBannerSize(size: loadedSize.size, type: .fixed)
        self.loadCompletion = completion

        let handleLoadResult: (BannerView?, BidMachineError?) -> Void = { [weak self, weak viewController] banner, error in
            // BidMachine calls this completion on the main thread. The hop keeps access to the main-actor ad safe if it does not.
            DispatchQueue.main.async {
                guard let self else { return }
                guard let banner else {
                    let error = self.error(.loadFailureUnknown, error: error)
                    self.log(.loadFailed(error))
                    completion(error)
                    return
                }

                self.ad = banner
                self.view = banner
                banner.rootViewController = viewController
                banner.delegate = self
                // Because 'show' isn't a separate step for banners, we don't declare a load success until
                // after any show checks are done
                guard banner.canShow else {
                    self.ad = nil
                    self.view = nil
                    let error = self.error(.loadFailureUnknown)
                    self.log(.loadFailed(error))
                    self.loadCompletion?(error) ?? self.log(.loadResultIgnored)
                    self.loadCompletion = nil
                    return
                }
                self.log(.loadSucceeded)
                self.loadCompletion?(nil) ?? self.log(.loadResultIgnored)
                self.loadCompletion = nil
            }
        }

        if let adm = request.adm {
            bidMachine.loadBanner(payload: adm, size: bannerSize, completion: handleLoadResult)
        } else {
            bidMachine.loadBanner(placement: placement, size: bannerSize, completion: handleLoadResult)
        }
    }
}

extension BidMachineAdapterBannerAd: BannerViewDelegate {
    @MainActor
    func didPresent(_ ad: BannerView) {
        log(.delegateCallIgnored)
    }

    @MainActor
    func didFailPresent(_ ad: BannerView, error: BidMachineError) {
        log(.delegateCallIgnored)
    }

    @MainActor
    func didTrackImpression(_ ad: BannerView) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    @MainActor
    func didClick(_ ad: BannerView) {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    @MainActor
    func didExpire(_ ad: BannerView) {
        log(.didExpire)
        delegate?.didExpire(self) ?? log(.delegateUnavailable)
    }
}

extension ChartboostMediationSDK.BannerSize {
    var bidMachineAdSize: BidMachine.BannerSize? {
        switch self {
        case .standard:
            .banner
        case .medium:
            .mrec
        case .leaderboard:
            .leaderboard
        default:
            // Not a standard IAB size
            nil
        }
    }
}
