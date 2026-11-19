import Foundation
import RiffCore
import Testing

@Suite("Song manifest")
struct SongManifestTests {
    /// PLAN.md appendix B with its times in whole milliseconds (CHART_FORMAT.md section 5).
    private static let exampleJSON = """
        {
          "id": "neon-nights",
          "title": "Neon Nights",
          "artist": "Placeholder Artist",
          "durationMs": 88000,
          "previewStartMs": 31000,
          "audioOffsetMs": 0,
          "stems": { "backing": "backing.m4a", "lead": "lead.m4a" },
          "charts": {
            "lead": {
              "easy": "lead_easy.json",
              "medium": "lead_medium.json",
              "hard": "lead_hard.json",
              "expert": "lead_expert.json"
            }
          },
          "intensity": { "lead": { "easy": 1, "medium": 3, "hard": 5, "expert": 7 } },
          "artwork": "art.png",
          "license": "LICENSES/neon-nights.md"
        }
        """

    @Test("A manifest decodes field for field and survives a round trip")
    func decodes() throws {
        let manifest = try JSONDecoder().decode(SongManifest.self, from: Data(Self.exampleJSON.utf8))
        #expect(manifest.id == "neon-nights")
        #expect(manifest.title == "Neon Nights")
        #expect(manifest.artist == "Placeholder Artist")
        #expect(manifest.durationMs == 88_000)
        #expect(manifest.previewStartMs == 31_000)
        #expect(manifest.audioOffsetMs == 0)
        #expect(manifest.stems == SongManifest.Stems(backing: "backing.m4a", lead: "lead.m4a"))
        let files = ["lead_easy.json", "lead_medium.json", "lead_hard.json", "lead_expert.json"]
        #expect(Difficulty.allCases.map { manifest.charts.lead[$0] } == files)
        #expect(Difficulty.allCases.map { manifest.intensity.lead[$0] } == [1, 3, 5, 7])
        #expect(manifest.artwork == "art.png")
        #expect(manifest.license == "LICENSES/neon-nights.md")

        let data = try CanonicalJSON.encode(manifest)
        #expect(try JSONDecoder().decode(SongManifest.self, from: data) == manifest)
    }

    // Manifest times are whole milliseconds (D-087).
    @Test("A duration with a fraction is refused")
    func refusesFractionalTimes() {
        let fractional = Self.exampleJSON.replacingOccurrences(of: "88000", with: "88000.5")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SongManifest.self, from: Data(fractional.utf8))
        }
    }
}
