// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Foundation


/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class BidMachineAdapterConfiguration: NSObject {
    private static let COPPA_KEY = "com.chartboost.adapter.bidmachine.coppa"
    private static let GDPR_ZONE_KEY = "com.chartboost.adapter.bidmachine.gdprzone"
    private static let GDPR_CONSENT_KEY = "com.chartboost.adapter.bidmachine.gdprconsent"
    private static let US_PRIVACY_STRING_KEY = "com.chartboost.adapter.bidmachine.usprivacystring"

    /// Init flag for starting up BidMachine SDK in test mode.
    /// Default value is 'false'.
    @objc public static var testMode: Bool = false

    /// Init flag for turning on BidMachine SDK general logging.
    /// Default value is 'false'.
    @objc public static var logging: Bool = false

    /// Init flag for turning on BidMachine SDK bidding logging.
    /// Default value is 'false'.
    @objc public static var bidLogging: Bool = false

    /// Init flag for turning on BidMachine SDK event logging.
    /// Default value is 'false'.
    @objc public static var eventLogging: Bool = false

    public static var coppa: Bool? {
        get { UserDefaults.standard.value(forKey: COPPA_KEY) as? Bool }
        set { UserDefaults.standard.setValue(newValue, forKey: COPPA_KEY) }
    }

    public static var gdprZone: Bool? {
        get { UserDefaults.standard.value(forKey: GDPR_ZONE_KEY) as? Bool }
        set { UserDefaults.standard.setValue(newValue, forKey: GDPR_ZONE_KEY) }
    }

    public static var gdprConsent: Bool? {
        get { UserDefaults.standard.value(forKey: GDPR_CONSENT_KEY) as? Bool }
        set { UserDefaults.standard.setValue(newValue, forKey: GDPR_CONSENT_KEY) }
    }

    public static var usPrivacyString: String? {
        get { UserDefaults.standard.string(forKey: US_PRIVACY_STRING_KEY) }
        set { UserDefaults.standard.setValue(newValue, forKey: US_PRIVACY_STRING_KEY) }
    }
}
