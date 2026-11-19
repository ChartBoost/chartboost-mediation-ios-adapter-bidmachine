// Copyright 2023-2026 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import BidMachine
import ChartboostMediationSDK
import Foundation

class BidMachineAdapterAd: NSObject {
    /// The partner adapter that created this ad.
    let adapter: PartnerAdapter

    /// Extra ad information provided by the partner.
    var details: PartnerDetails = [:]

    /// The ad load request associated to the ad.
    /// It should be the one provided on ``PartnerAdapter/makeBannerAd(request:delegate:)``
    /// or ``PartnerAdapter/makeFullscreenAd(request:delegate:)``.
    let request: PartnerAdLoadRequest

    /// The partner ad delegate to send ad life-cycle events to.
    /// It should be the one provided on ``PartnerAdapter/makeBannerAd(request:delegate:)``
    /// or ``PartnerAdapter/makeFullscreenAd(request:delegate:)``.
    weak var delegate: PartnerAdDelegate?

    /// The completion for the ongoing load operation.
    var loadCompletion: ((Error?) -> Void)?

    /// The completion for the ongoing show operation.
    var showCompletion: ((Error?) -> Void)?

    /// Waterfall item price
    var price: Double? {
        let setting = request.partnerSettings["price"]
        let priceNSNum = setting as? NSNumber
        return priceNSNum?.doubleValue
    }

    /// The placement for a non-programmatic load, with the waterfall item price as BidMachine's price floor.
    var placement: Placement {
        Placement(id: request.partnerPlacement, extras: price.map { ["price_floor": $0] } ?? [:])
    }

    /// The BidMachine SDK instance created by the adapter during set up.
    var bidMachine: BidMachineInstance? {
        (adapter as? BidMachineAdapter)?.instance
    }

    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) {
        self.adapter = adapter
        self.request = request
        self.delegate = delegate
    }
}
