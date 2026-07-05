import Foundation
import AppKit

public enum MediaTrackerEvent: Sendable {
    case trackChanged(MediaTrack)
    case playbackStarted(MediaTrack)
    case playbackPaused(MediaTrack)
    case sessionEnded(MediaSession, ActivityRecord)
    case error(Error)
}

public struct MediaTrack: Sendable, Equatable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String?
    public var genre: String?
    public var duration: TimeInterval
    public var platform: String
    public var isPlaying: Bool

    public init(id: String = UUID().uuidString, title: String, artist: String, album: String? = nil,
                genre: String? = nil, duration: TimeInterval = 0, platform: String, isPlaying: Bool = true) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.duration = duration
        self.platform = platform
        self.isPlaying = isPlaying
    }
}

public struct MediaSession: Sendable, Equatable {
    public var id: String
    public var track: MediaTrack
    public var startTime: Date
    public var endTime: Date?
    public var listenDuration: TimeInterval
    public var playCount: Int

    public var duration: TimeInterval {
        endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
    }

    public init(id: String = UUID().uuidString, track: MediaTrack, startTime: Date = Date(),
                endTime: Date? = nil, listenDuration: TimeInterval = 0, playCount: Int = 1) {
        self.id = id
        self.track = track
        self.startTime = startTime
        self.endTime = endTime
        self.listenDuration = listenDuration
        self.playCount = playCount
    }
}

public actor MediaTracker {
    public static let shared = MediaTracker()

    private var activeSession: MediaSession?
    private var activeTrack: MediaTrack?
    private var monitoringTask: Task<Void, Never>?
    private let stream = AsyncStream<MediaTrackerEvent>.makeStream()
    private var isEnabled = false
    private var wasPlaying = false

    public var events: AsyncStream<MediaTrackerEvent> {
        stream.stream
    }

    public var currentTrack: MediaTrack? { activeTrack }
    public var currentSession: MediaSession? { activeSession }

    private static let musicApps: Set<String> = [
        "com.apple.Music",
        "com.spotify.client",
    ]

    private init() {}

    // MARK: - Lifecycle

    public func start() {
        guard !isEnabled else { return }
        isEnabled = true
        startMonitoring()
    }

    public func stop() {
        isEnabled = false
        monitoringTask?.cancel()
        monitoringTask = nil
        endCurrentSession()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkMedia()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: - Media Detection

    private func checkMedia() async {
        guard isEnabled else { return }

        let spotifyTrack = await extractSpotify()
        let musicTrack = await extractAppleMusic()

        let track = spotifyTrack ?? musicTrack

        guard let track else {
            if wasPlaying {
                wasPlaying = false
                endCurrentSession()
            }
            return
        }

        wasPlaying = track.isPlaying

        guard track.isPlaying else {
            if activeTrack != nil {
                stream.continuation.yield(.playbackPaused(track))
            }
            return
        }

        if let activeTrack, activeTrack.id != track.id {
            endCurrentSession()
            startNewSession(with: track)
        } else if activeTrack == nil {
            startNewSession(with: track)
        }

        stream.continuation.yield(.trackChanged(track))
        activeTrack = track
    }

    // MARK: - Spotify

    private func extractSpotify() async -> MediaTrack? {
        let script = """
        tell application "Spotify"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set trackDuration to duration of current track
                return "SPOTIFY|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration
            else
                return "SPOTIFY_PAUSED"
            end if
        end tell
        """

        guard let result = await runAppleScript(script) else { return nil }

        if result == "SPOTIFY_PAUSED" {
            if let active = activeTrack, active.platform == "Spotify" {
                return MediaTrack(id: active.id, title: active.title, artist: active.artist,
                                  album: active.album, duration: active.duration, platform: "Spotify", isPlaying: false)
            }
            return nil
        }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 4, parts[0] == "SPOTIFY" else { return nil }

        let title = parts[1]
        let artist = parts[2]
        let album = parts[3].isEmpty ? nil : parts[3]
        let duration = parts.count >= 5 ? (Double(parts[4]) ?? 0) / 1000 : 0

        return MediaTrack(title: title, artist: artist, album: album, duration: duration, platform: "Spotify")
    }

    // MARK: - Apple Music

    private func extractAppleMusic() async -> MediaTrack? {
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set trackGenre to genre of current track
                set trackDuration to duration of current track
                return "MUSIC|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & trackGenre & "|||" & trackDuration
            else
                return "MUSIC_PAUSED"
            end if
        end tell
        """

        guard let result = await runAppleScript(script) else { return nil }

        if result == "MUSIC_PAUSED" {
            if let active = activeTrack, active.platform == "Apple Music" {
                return MediaTrack(id: active.id, title: active.title, artist: active.artist,
                                  album: active.album, genre: active.genre, duration: active.duration,
                                  platform: "Apple Music", isPlaying: false)
            }
            return nil
        }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 4, parts[0] == "MUSIC" else { return nil }

        let title = parts[1]
        let artist = parts[2]
        let album = parts[3].isEmpty ? nil : parts[3]
        let genre = parts.count >= 5 ? (parts[4].isEmpty ? nil : parts[4]) : nil
        let duration = parts.count >= 6 ? Double(parts[5]) ?? 0 : 0

        return MediaTrack(title: title, artist: artist, album: album, genre: genre, duration: duration, platform: "Apple Music")
    }

    // MARK: - Session Management

    private func startNewSession(with track: MediaTrack) {
        stream.continuation.yield(.playbackStarted(track))
        let session = MediaSession(track: track)
        activeSession = session
        activeTrack = track
    }

    private func endCurrentSession() {
        guard var session = activeSession else { return }
        session.endTime = Date()
        activeSession = nil
        activeTrack = nil

        guard session.duration >= 10 else { return }

        let meta = MediaMetadata(
            trackName: session.track.title,
            artist: session.track.artist,
            album: session.track.album,
            genre: session.track.genre,
            duration: session.track.duration,
            platform: session.track.platform
        )
        let metaJSON = (try? JSONEncoder().encode(meta)).flatMap { String(data: $0, encoding: .utf8) }

        let record = ActivityRecord(
            activityType: .media,
            category: "music",
            appBundleID: session.track.platform == "Spotify" ? "com.spotify.client" : "com.apple.Music",
            appName: session.track.platform,
            title: "\(session.track.artist) — \(session.track.title)",
            contentExcerpt: nil,
            metadataJSON: metaJSON,
            duration: session.duration,
            confidence: 0.9,
            source: "media_tracker",
            sessionID: session.id
        )

        Task { @MainActor in
            await ActivityTracker.shared.insert(record)
        }

        stream.continuation.yield(.sessionEnded(session, record))
    }

    // MARK: - Helpers

    private func runAppleScript(_ source: String) async -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return output.stringValue
    }
}
