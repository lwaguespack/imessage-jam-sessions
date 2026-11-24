import Foundation
import Observation
import QuartzCore
import SwiftUI
import UIKit

@MainActor
@Observable
final class SpikeReport {
    private(set) var recentLines: [String] = []
    private(set) var storageError: String?

    @ObservationIgnored private var handle: FileHandle?
    @ObservationIgnored private var fileURL: URL?
    @ObservationIgnored private let dates: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init() {
        do {
            guard
                let directory = FileManager.default.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask
                ).first
            else {
                throw ReportError.noApplicationSupport
            }
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("device-spike-report.txt")
            if !FileManager.default.fileExists(atPath: url.path) {
                guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                    throw ReportError.cannotCreateFile
                }
            }
            handle = try FileHandle(forWritingTo: url)
            fileURL = url
        } catch {
            showError("Could not open the persistent report: \(error.localizedDescription)")
        }

        let device = UIDevice.current
        record(
            "PROCESS start pid=\(ProcessInfo.processInfo.processIdentifier) "
                + "device=\(device.model) iOS=\(device.systemVersion) app=\(AppInfo.version)"
        )
    }

    func record(_ message: String) {
        let line = "[\(dates.string(from: Date())) host=\(String(format: "%.6f", CACurrentMediaTime()))] \(message)"
        recentLines.append(line)
        if recentLines.count > 12 {
            recentLines.removeFirst(recentLines.count - 12)
        }

        guard let handle else { return }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
        } catch {
            showError("Could not save the report: \(error.localizedDescription)")
        }
    }

    func copy() {
        do {
            guard let fileURL else { throw ReportError.noReport }
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            UIPasteboard.general.string = text
            record("REPORT copied to clipboard")
        } catch {
            showError("Could not copy the report: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        storageError = message
        NSLog("%@", message)
    }

    private enum ReportError: LocalizedError {
        case noApplicationSupport
        case cannotCreateFile
        case noReport

        var errorDescription: String? {
            switch self {
            case .noApplicationSupport: "Application Support is unavailable."
            case .cannotCreateFile: "The report file could not be created."
            case .noReport: "The persistent report is unavailable."
            }
        }
    }
}

struct SpikeReportControls: View {
    let report: SpikeReport
    @State private var observation = ""

    var body: some View {
        Section("Report") {
            if let error = report.storageError {
                Text(error).foregroundStyle(.red)
            }
            TextField("Add your observation", text: $observation, axis: .vertical)
            Button("Add observation") {
                let text = observation.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                report.record("OWNER \(text)")
                observation = ""
            }
            .disabled(observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Copy report") { report.copy() }
            Text("The report contains participant IDs. Share it only with people you trust.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(Array(report.recentLines.suffix(4).enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption.monospaced()).textSelection(.enabled)
            }
        }
    }
}
