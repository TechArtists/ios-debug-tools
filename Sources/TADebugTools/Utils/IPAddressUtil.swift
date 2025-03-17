/*
MIT License

Copyright (c) 2025 Tech Artists Agency

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

//
//  IPAdressUtil.swift
//  TADebugTools
//
//  Created by Robert Tataru on 16.12.2024.
//

import Foundation
import SystemConfiguration.CaptiveNetwork

enum IPAddressUtil {
    static func getDeviceIPAddress() -> String? {
        var address: String?

        // Iterate over all available network interfaces
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family

                // Check if it's an IPv4 or IPv6 address
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    // Check interface name
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" {
                        // Convert interface address to a readable string
                        var addr = interface?.ifa_addr.pointee
                        let hostname = UnsafeMutablePointer<Int8>.allocate(capacity: Int(NI_MAXHOST))
                        defer { hostname.deallocate() }
                        if getnameinfo(&addr!, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                       hostname, socklen_t(NI_MAXHOST),
                                       nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
