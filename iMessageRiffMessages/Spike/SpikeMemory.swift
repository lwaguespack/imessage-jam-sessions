import Darwin
import Foundation

enum SpikeMemory {
    static func footprint() throws -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard let offset = MemoryLayout<task_vm_info_data_t>.offset(of: \.phys_footprint) else {
            throw MemoryError.unknownLayout
        }
        let required = mach_msg_type_number_t(
            (offset + MemoryLayout<UInt64>.size + MemoryLayout<natural_t>.size - 1)
                / MemoryLayout<natural_t>.size)
        guard result == KERN_SUCCESS, count >= required else {
            throw MemoryError.unavailable(result, count, required)
        }
        return info.phys_footprint
    }

    static func record(_ label: String, report: SpikeReport) {
        do {
            let bytes = try footprint()
            report.record("S6 \(label) footprintBytes=\(bytes)")
        } catch {
            report.record("S6 \(label) ERROR \(error.localizedDescription)")
        }
    }

    private enum MemoryError: LocalizedError {
        case unavailable(kern_return_t, mach_msg_type_number_t, mach_msg_type_number_t)
        case unknownLayout

        var errorDescription: String? {
            switch self {
            case .unavailable(let code, let count, let required):
                "Memory footprint unavailable (task_info \(code), count \(count)/\(required))."
            case .unknownLayout:
                "Memory footprint field is unavailable in task_vm_info."
            }
        }
    }
}
