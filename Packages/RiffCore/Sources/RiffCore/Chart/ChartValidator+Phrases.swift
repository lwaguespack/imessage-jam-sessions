extension ChartValidator {
    static func phraseIssues(_ timeline: ChartTimeline, config: GameConfig) -> [ChartIssue] {
        let chart = timeline.chart
        let charts = config.charts
        var issues: [ChartIssue] = []
        if chart.hype.count < charts.minPhrasesPerSong || chart.hype.count > charts.maxPhrasesPerSong {
            let message =
                "a chart needs \(charts.minPhrasesPerSong) to \(charts.maxPhrasesPerSong) phrases; "
                + "this one has \(chart.hype.count)"
            issues.append(ChartIssue(.phraseCount, message))
        }
        for phrase in chart.hype {
            let members = chart.notes.filter { phrase.start <= $0.tick && $0.tick < phrase.end }.count
            if members < charts.minNotesPerPhrase {
                let message = "a phrase needs at least \(charts.minNotesPerPhrase) notes; this one has \(members)"
                issues.append(ChartIssue(.phraseMembers, tick: phrase.start, message))
            }
        }
        let tail = charts.minBeatsAfterLastPhrase * chart.resolution
        if let lastPhrase = chart.hype.last, let lastNote = chart.notes.last, lastPhrase.end + tail > lastNote.tick {
            let message =
                "the last phrase must end at least \(charts.minBeatsAfterLastPhrase) beats before the final note"
            issues.append(ChartIssue(.phraseTail, tick: lastPhrase.end, message))
        }
        // The song's length in ticks runs to the end of its last note.
        let songTicks = timeline.endTicks.max() ?? 0
        let capacityTicks = config.hype.phraseGain * chart.resolution * chart.hype.count
        if capacityTicks * 100 > charts.maxHypeCapacitySharePercent * songTicks {
            let message =
                "the phrases can fill \(capacityTicks / chart.resolution) beats of Hype, more than "
                + "\(charts.maxHypeCapacitySharePercent)% of the song's \(songTicks / chart.resolution) beats"
            issues.append(ChartIssue(.hypeCapacity, message))
        }
        return issues
    }

    static func songLengthIssues(
        _ timeline: ChartTimeline, manifest: SongManifest?, config: GameConfig
    ) -> [ChartIssue] {
        var issues: [ChartIssue] = []
        let songs = config.songs
        let shortest = (songs.minDurationMicros - songs.durationToleranceMicros) / 1_000
        // Also the limit for a chart checked without its manifest.
        var limit = (songs.maxDurationMicros + songs.durationToleranceMicros) / 1_000
        if let manifest {
            if manifest.id != timeline.chart.songId {
                let message = "the chart is for '\(timeline.chart.songId)' and the manifest for '\(manifest.id)'"
                issues.append(ChartIssue(.manifestSong, message))
            }
            let stated = Int64(manifest.durationMs)
            if stated < shortest || stated > limit {
                let message = "the manifest's durationMs is \(stated); it must be \(shortest) to \(limit)"
                issues.append(ChartIssue(.manifestDuration, message))
            }
            limit = stated
        }
        // In milliseconds rounded up, so a note that ends a microsecond late is late.
        let end = ((timeline.endTimes.max() ?? 0) + 999) / 1_000
        if end > limit {
            issues.append(ChartIssue(.songLength, "the last note ends at \(end) ms; the song may be \(limit) ms long"))
        }
        return issues
    }
}
