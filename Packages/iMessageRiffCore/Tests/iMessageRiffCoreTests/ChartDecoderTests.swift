import Foundation
import Testing
import iMessageRiffCore

@Suite("Chart decoder")
struct ChartDecoderTests {
    /// A small chart file. Each test changes one piece of its text.
    private static let file = """
        {
          "format": "riff-chart",
          "version": 1,
          "songId": "test-song",
          "part": "lead",
          "difficulty": "expert",
          "lanes": 4,
          "resolution": 192,
          "tempo": [{ "tick": 0, "mbpm": 128000 }],
          "timeSignatures": [{ "tick": 0, "num": 4, "den": 4 }],
          "notes": [{ "tick": 768, "lane": 0 }, { "tick": 960, "lane": 2, "length": 192 }],
          "hype": [{ "start": 3072, "end": 4608 }],
          "sections": [{ "tick": 0, "name": "Intro" }],
          "computed": {
            "rulesVersion": 1, "noteCount": 2, "baseScore": 0, "maxScore": 0,
            "starCutoffs": [0, 0, 0, 0, 0], "hash": "00000000"
          }
        }
        """

    /// What the decoder refuses the file with after `target` is replaced; nil if it reads the file.
    private func failure(replacing target: String, with replacement: String) -> ChartDecoder.Failure? {
        let text = Self.file.replacingOccurrences(of: target, with: replacement)
        #expect(text != Self.file, "the edit '\(target)' matched nothing")
        do {
            _ = try ChartDecoder.decode(Data(text.utf8))
            return nil
        } catch let failure as ChartDecoder.Failure {
            return failure
        } catch {
            Issue.record("unexpected error: \(error)")
            return nil
        }
    }

    /// Whether the failure is `malformed` and its text names `field`.
    private func isMalformed(_ failure: ChartDecoder.Failure?, naming field: String) -> Bool {
        guard case .malformed(let text) = failure else { return false }
        return text.contains(field)
    }

    @Test("A well-formed file decodes")
    func decodes() throws {
        let chart = try ChartDecoder.decode(Data(Self.file.utf8))
        #expect(chart.songId == "test-song")
        #expect(chart.difficulty == .expert)
        #expect(chart.tempo == [TempoSegment(tick: 0, mbpm: 128_000)])
        #expect(chart.notes == [Note(tick: 768, lane: 0), Note(tick: 960, lane: 2, length: 192)])
        #expect(chart.hype == [HypePhrase(start: 3072, end: 4608)])
        #expect(chart.computed.noteCount == 2)
    }

    @Test("Another format or a newer version is named as such, whatever else the file holds")
    func formatAndVersion() {
        #expect(failure(replacing: "riff-chart", with: "riff-song") == .unknownFormat("riff-song"))
        #expect(failure(replacing: "\"version\": 1", with: "\"version\": 2") == .unsupportedVersion(2))
        let newer = failure(replacing: "\"version\": 1,", with: "\"version\": 2, \"future\": true,")
        #expect(newer == .unsupportedVersion(2))
    }

    // Foundation's decoder reports these as invalid JSON with no path, so the chart decoder finds the number.
    @Test("A number that is a fraction, or too large for an integer, is refused with its path")
    func numbersMustBeWhole() {
        let complaint = " is not a whole number, or is too large"
        let fraction = failure(replacing: "\"tick\": 768", with: "\"tick\": 768.5")
        #expect(fraction == .malformed("notes[0].tick" + complaint))
        let tooLarge = failure(replacing: "\"tick\": 768", with: "\"tick\": 99999999999999999999")
        #expect(tooLarge == .malformed("notes[0].tick" + complaint))
        let version = failure(replacing: "\"version\": 1", with: "\"version\": 1.5")
        #expect(version == .malformed("version" + complaint))
    }

    @Test("A missing field, a wrong type, a null or an unknown difficulty is refused")
    func malformedFields() {
        #expect(failure(replacing: "\"lanes\": 4,", with: "") == .malformed("lanes is missing"))
        let misnamed = failure(replacing: "\"mbpm\": 128000", with: "\"bpm\": 128")
        #expect(misnamed == .malformed("tempo[0].mbpm is missing"))

        let edits: [(target: String, replacement: String, field: String)] = [
            ("\"resolution\": 192", "\"resolution\": \"192\"", "resolution"),
            ("\"expert\"", "\"extreme\"", "difficulty"),
            ("\"lanes\": 4", "\"lanes\": null", "lanes"),
            ("\"hype\": [{ \"start\": 3072, \"end\": 4608 }]", "\"hype\": {}", "hype"),
        ]
        for edit in edits {
            let result = failure(replacing: edit.target, with: edit.replacement)
            #expect(isMalformed(result, naming: edit.field), "\(edit.replacement): \(String(describing: result))")
        }
    }

    @Test("Text that is not a JSON object is refused")
    func notJSON() {
        #expect(throws: ChartDecoder.Failure.malformed("not valid JSON")) {
            _ = try ChartDecoder.decode(Data("riff-chart".utf8))
        }
        #expect(failure(replacing: "\"format\"", with: "format") == .malformed("not valid JSON"))
        #expect(throws: ChartDecoder.Failure.malformed("the file has the wrong type")) {
            _ = try ChartDecoder.decode(Data("[]".utf8))
        }
    }

    // A misspelt `length` would otherwise turn a hold into a tap without a word.
    @Test("A field the format does not define is refused, with its path")
    func unknownFields() {
        let edits: [(target: String, replacement: String, path: String)] = [
            ("\"lanes\": 4,", "\"lanes\": 4, \"speed\": 2,", "speed"),
            ("\"length\": 192", "\"lenght\": 192", "notes[1].lenght"),
            ("\"den\": 4", "\"den\": 4, \"beat\": 1", "timeSignatures[0].beat"),
            ("\"hash\": \"00000000\"", "\"hash\": \"00000000\", \"stars\": 3", "computed.stars"),
        ]
        for edit in edits {
            #expect(failure(replacing: edit.target, with: edit.replacement) == .unknownField(edit.path))
        }
    }

    @Test("A tap that writes its length as null is refused")
    func explicitNull() {
        let withNull = failure(replacing: "\"lane\": 0 }", with: "\"lane\": 0, \"length\": null }")
        #expect(withNull == .unknownField("notes[0].length"))
    }
}
