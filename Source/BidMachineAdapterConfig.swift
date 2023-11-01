// Copyright 2023-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Foundation


/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class BidMachineAdapterConfiguration: NSObject {
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
}
