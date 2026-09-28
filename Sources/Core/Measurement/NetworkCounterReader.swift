import Darwin
import Foundation

protocol NetworkCounterReading {
    func readCounters() throws -> [NetworkInterfaceCounter]
}

struct NetworkCounterReader: NetworkCounterReading {
    // Darwin routing message type RTM_IFINFO2. The iOS SDK exposes
    // NET_RT_IFLIST2 and if_msghdr2 but omits this macro from Swift.
    private static let routeMessageInterfaceInfo2: UInt8 = 0x12

    func readCounters() throws -> [NetworkInterfaceCounter] {
        var managementInformationBase: [Int32] = [
            CTL_NET,
            PF_ROUTE,
            0,
            0,
            NET_RT_IFLIST2,
            0
        ]
        var buffer: [UInt8] = []
        var bufferLength = 0
        var didRead = false

        // The interface list can change between the sizing and data sysctl
        // calls. Leave headroom and retry a bounded number of times rather than
        // reporting a transient route-table race as a failed measurement.
        for _ in 0..<3 {
            var requiredLength = 0
            guard sysctl(
                &managementInformationBase,
                u_int(managementInformationBase.count),
                nil,
                &requiredLength,
                nil,
                0
            ) == 0, requiredLength > 0 else {
                throw MeasurementError.interfaceReadFailed
            }

            buffer = [UInt8](repeating: 0, count: requiredLength + 4_096)
            bufferLength = buffer.count
            if sysctl(
                &managementInformationBase,
                u_int(managementInformationBase.count),
                &buffer,
                &bufferLength,
                nil,
                0
            ) == 0 {
                didRead = true
                break
            }

            guard errno == ENOMEM else { break }
        }

        guard didRead else {
            throw MeasurementError.interfaceReadFailed
        }

        var resultByName: [String: NetworkInterfaceCounter] = [:]
        let validLength = min(bufferLength, buffer.count)

        buffer.withUnsafeBytes { rawBuffer in
            guard rawBuffer.baseAddress != nil else { return }
            var offset = 0

            while offset + 4 <= validLength {
                let messageLength = Int(rawBuffer.loadUnaligned(
                    fromByteOffset: offset,
                    as: UInt16.self
                ))
                let messageType = rawBuffer.load(
                    fromByteOffset: offset + 3,
                    as: UInt8.self
                )

                guard messageLength > 0, offset + messageLength <= validLength else { break }

                if messageType == Self.routeMessageInterfaceInfo2,
                   messageLength >= MemoryLayout<if_msghdr2>.size {
                    let info = rawBuffer.loadUnaligned(
                        fromByteOffset: offset,
                        as: if_msghdr2.self
                    )

                    var nameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                    if if_indextoname(UInt32(info.ifm_index), &nameBuffer) != nil {
                        let nameBytes = nameBuffer
                            .prefix { $0 != 0 }
                            .map { UInt8(bitPattern: $0) }
                        let name = String(decoding: nameBytes, as: UTF8.self)
                        let counter = NetworkInterfaceCounter(
                            name: name,
                            receivedBytes: info.ifm_data.ifi_ibytes,
                            sentBytes: info.ifm_data.ifi_obytes,
                            classification: InterfaceClassifier.classify(
                                name,
                                interfaceType: info.ifm_data.ifi_type
                            ),
                            interfaceIndex: UInt32(info.ifm_index),
                            interfaceType: info.ifm_data.ifi_type
                        )
                        // NET_RT_IFLIST2 should contain one IFINFO2 message per
                        // interface. If a malformed/duplicated route dump ever
                        // contains more, keep only the most advanced counter so
                        // the same interface can never be counted twice.
                        if let existing = resultByName[name] {
                            if counter.totalBytes >= existing.totalBytes {
                                resultByName[name] = counter
                            }
                        } else {
                            resultByName[name] = counter
                        }
                    }
                }

                offset += messageLength
            }
        }

        guard !resultByName.isEmpty else {
            throw MeasurementError.interfaceReadFailed
        }

        return resultByName.values.sorted { $0.name < $1.name }
    }
}
