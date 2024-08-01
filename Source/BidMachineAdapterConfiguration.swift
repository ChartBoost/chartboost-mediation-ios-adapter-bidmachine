// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import BidMachine
import ChartboostMediationSDK
import Foundation

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class BidMachineAdapterConfiguration: NSObject, PartnerAdapterConfiguration {
    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        BidMachineSdk.sdkVersion
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version,
    /// the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.
    /// <Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "5.2.7.0.0"

    /// The partner's unique identifier.
    @objc public static let partnerID = "bidmachine"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "BidMachine"

    /// Init flag for starting up BidMachine SDK in test mode.
    /// Default value is 'false'.
    @objc public static var testMode = false

    /// Init flag for turning on BidMachine SDK general logging.
    /// Default value is 'false'.
    @objc public static var logging = false

    /// Init flag for turning on BidMachine SDK bidding logging.
    /// Default value is 'false'.
    @objc public static var bidLogging = false

    /// Init flag for turning on BidMachine SDK event logging.
    /// Default value is 'false'.
    @objc public static var eventLogging = false
}
