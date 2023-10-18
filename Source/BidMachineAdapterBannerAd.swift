// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import BidMachine
import BidMachineApiCore  // Needed for the PlacementFormat type

final class BidMachineAdapterBannerAd: BidMachineAdapterAd, PartnerAd {

    /// The BidMachineSDK ad instance.
    private var ad: BidMachineBanner?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)

        let bannerType = BidMachineApiCore.PlacementFormat.from(size: request.size)

        // Make request configuration
        let config: BidMachineRequestConfigurationProtocol
        do {
            config = try BidMachineSdk.shared.requestConfiguration(bannerType)
        } catch {
            let chartboostMediationError = self.error(.loadFailureUnknown, error: error)
            log(.loadFailed(chartboostMediationError))
            completion(.failure(chartboostMediationError))
            return
        }

        self.loadCompletion = completion

        // There's no harm in setting the placement ID when loading a bidding ad, but calling
        // .withPayload(request.adm ?? "") causes an error when BidMachine parses the empty string
        config.populate { $0.withPlacementId(request.partnerPlacement) }
        if let adm = request.adm {
            config.populate { $0.withPayload(adm) }
        }

        BidMachineSdk.shared.banner(config) { [weak self, weak viewController] ad, error in
            guard let self else {
                return
            }
            guard let ad else {
                let chartboostMediationError = self.error(.loadFailureUnknown, error: error)
                log(.loadFailed(chartboostMediationError))
                completion(.failure(chartboostMediationError))
                return
            }
            self.inlineView = ad
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
        // no-op
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
            let showError = error(.showFailureAdNotReady)
            log(.showFailed(showError))
            return
        }
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil

        log(.showStarted)
    }

    func didFailLoadAd(_ ad: BidMachine.BidMachineAdProtocol, _ error: Error) {
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func didPresentAd(_ ad: BidMachineAdProtocol) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
    }

    func didFailPresentAd(_ ad: BidMachineAdProtocol, _ error: Error) {
        log(.showFailed(error))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
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

extension BidMachineApiCore.PlacementFormat {
    static func from(size: CGSize?) -> BidMachineApiCore.PlacementFormat {
        let height = size?.height ?? 50
        switch height {
        case 50...89:
            return .banner320x50
        case 90...249:
            return .banner728x90
        case 250...:
            return .banner300x250
        default:
            return .banner320x50
        }
    }
}
