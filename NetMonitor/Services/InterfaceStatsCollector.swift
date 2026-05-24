import Foundation
import Darwin
import SystemConfiguration

struct InterfaceStats {
    let name: String
    let type: String
    let bytesIn: UInt64
    let bytesOut: UInt64
}

final class InterfaceStatsCollector {

    private var interfaceTypeCache: [String: String] = [:]

    init() {
        refreshInterfaceTypeCache()
    }

    func collectStats() -> [InterfaceStats] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0 else {
            return []
        }

        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else {
            return []
        }

        var results: [InterfaceStats] = []
        var offset = 0

        while offset < len {
            let msgPtr = buf.withUnsafeMutableBufferPointer { bufPtr -> UnsafeMutableRawPointer in
                return UnsafeMutableRawPointer(bufPtr.baseAddress!.advanced(by: offset))
            }

            let msgLen = msgPtr.load(as: UInt16.self)
            let msgType = msgPtr.advanced(by: 3).load(as: UInt8.self)

            if msgType == RTM_IFINFO2 {
                let ifMsg = msgPtr.load(as: if_msghdr2.self)
                let ifData = ifMsg.ifm_data
                let ifIndex = Int(ifMsg.ifm_index)

                if let name = interfaceName(forIndex: ifIndex) {
                    let filtered = name.hasPrefix("lo") || name.hasPrefix("gif") || name.hasPrefix("stf")
                    if !filtered {
                        let type = classifyInterface(name)
                        results.append(InterfaceStats(
                            name: name,
                            type: type,
                            bytesIn: ifData.ifi_ibytes,
                            bytesOut: ifData.ifi_obytes
                        ))
                    }
                }
            }

            offset += Int(msgLen)
            if msgLen == 0 { break }
        }

        return results
    }

    private func interfaceName(forIndex index: Int) -> String? {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(UInt32(index), &name) != nil else { return nil }
        return String(cString: name)
    }

    func classifyInterface(_ name: String) -> String {
        if let cached = interfaceTypeCache[name] {
            return cached
        }

        let type: String
        if name.hasPrefix("en0") {
            type = "wifi"
        } else if name.hasPrefix("en") {
            type = "hotspot"
        } else if name.hasPrefix("bridge") {
            type = "bridge"
        } else if name.hasPrefix("utun") || name.hasPrefix("ipsec") {
            type = "vpn"
        } else if name.hasPrefix("awdl") || name.hasPrefix("llw") {
            type = "airdrop"
        } else {
            type = "other"
        }

        interfaceTypeCache[name] = type
        return type
    }

    func refreshInterfaceTypeCache() {
        interfaceTypeCache.removeAll()

        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return }
        for iface in interfaces {
            guard let bsdName = SCNetworkInterfaceGetBSDName(iface) as String? else { continue }
            guard let ifType = SCNetworkInterfaceGetInterfaceType(iface) as String? else { continue }

            let wifiType = kSCNetworkInterfaceTypeIEEE80211 as String
            let ethernetType = kSCNetworkInterfaceTypeEthernet as String

            if ifType == wifiType {
                interfaceTypeCache[bsdName] = "wifi"
            } else if ifType == ethernetType {
                // Non-en0 ethernet interfaces are USB tethering / mobile hotspot
                if bsdName == "en0" {
                    interfaceTypeCache[bsdName] = "wifi"
                } else {
                    interfaceTypeCache[bsdName] = "hotspot"
                }
            }
        }
    }
}
