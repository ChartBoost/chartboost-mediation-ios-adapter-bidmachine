// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import BidMachine

final class BidMachineAdapterBannerAd: BidMachineAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// The BidMachineSDK ad instance.
    private var ad: BidMachineBanner?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)

        guard let requestedSize = request.bannerSize,
              let loadedSize = BannerSize.largestStandardFixedSizeThatFits(in: requestedSize)?.size,
              let bannerType = PlacementFormat.from(size: loadedSize) else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }

        // Make request configuration
        let config: BidMachineRequestConfigurationProtocol
        do {
            config = try BidMachineSdk.shared.requestConfiguration(bannerType)
        } catch {
            self.log(.loadFailed(error))
            completion(.failure(error))
            return
        }

        self.size = PartnerBannerSize(size: loadedSize, type: .fixed)
        self.loadCompletion = completion

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

        BidMachineSdk.shared.banner(config) { [weak self, weak viewController] ad, error in
            guard let self else {
                return
            }
            guard let ad else {
                let chartboostMediationError = self.error(.loadFailureUnknown, error: error)
                self.log(.loadFailed(chartboostMediationError))
                completion(.failure(chartboostMediationError))
                return
            }
            self.view = ad
            ad.controller = viewController
            ad.delegate = self
            ad.loadAd()
        }
    }
}

extension BidMachineAdapterBannerAd: BidMachineAdDelegate {
    func didLoadAd(_ ad: BidMachine.BidMachineAdProtocol) {
        // Because 'show' isn't a separate step for banners, we don't declare a load success until
        // after any show checks are done
        guard let bannerAdView = ad as? BidMachineBanner,
              bannerAdView.canShow else {
            let loadError = error(.loadFailureUnknown)
            log(.loadFailed(loadError))
            loadCompletion?(.failure(loadError)) ?? log(.loadResultIgnored)
            loadCompletion = nil
            return
        }
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
        log(.delegateCallIgnored)
    }

    func didFailPresentAd(_ ad: BidMachineAdProtocol, _ error: Error) {
        log(.delegateCallIgnored)
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

extension PlacementFormat {
    static func from(size: CGSize) -> PlacementFormat? {
        // Translate IAB size to a BidMachine placement format
        switch size {
        case BannerSize.standard.size:
            return .banner320x50
        case BannerSize.medium.size:
            return .banner300x250
        case BannerSize.leaderboard.size:
            return .banner728x90
        default:
            // Not a standard IAB size
            return nil
        }
    }
}
