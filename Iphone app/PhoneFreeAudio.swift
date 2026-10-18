//
//  PhoneFreeAudio.swift
//  Iphone app
//
//  The completion bell: a short glockenspiel chime that marks a phone-free
//  timer finishing, played by the app itself.
//
//  Playing it here rather than relying only on a notification sound is what
//  lets it ignore the Ring/Silent switch. The `playback` audio category keeps
//  sounding when the phone is muted; the `ambient` category follows the switch
//  like everything else. (A notification sound cannot do this without Apple's
//  Critical Alerts entitlement, which is why the bell is played in-app when the
//  app is running, and left to the notification when it is not.)
//
//  Both categories mix with other audio, so the bell never cuts off whatever
//  the user is listening to.
//

import AVFoundation

/// Plays the chime that marks a timer finishing.
@MainActor
final class PhoneFreeAudio: NSObject, AVAudioPlayerDelegate {
    static let shared = PhoneFreeAudio()

    /// The name of the bell in the app bundle. Also used as the notification
    /// sound, so the two always match to the ear.
    static let soundName = "PhoneFreeChime"
    static let soundExtension = "wav"

    private var player: AVAudioPlayer?

    /// Plays the bell.
    ///
    /// - Parameter overrideSilent: when `true` the bell sounds even with the
    ///   Ring/Silent switch on silent; when `false` it follows the switch.
    func play(overrideSilent: Bool) {
        guard let url = Bundle.main.url(
            forResource: Self.soundName,
            withExtension: Self.soundExtension
        ) else { return }

        do {
            let session = AVAudioSession.sharedInstance()

            // `.playback` sounds through the Ring/Silent switch and mixes with
            // other audio; `.ambient` already mixes and follows the switch, and
            // does not accept the mixing option.
            if overrideSilent {
                try session.setCategory(
                    .playback,
                    mode: .default,
                    options: [.mixWithOthers]
                )
            } else {
                try session.setCategory(.ambient, mode: .default)
            }

            try session.setActive(true)

            // A fresh player each time, so a bell landing on the tail of the
            // last one restarts cleanly instead of being clipped.
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = 0.85
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            // The bell is a nicety. If the session or the file will not come
            // up, stay silent rather than interrupt with an error — the
            // notification path still rings when the app is closed.
        }
    }

    /// Hands the audio session back to whatever was playing before the bell.
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        let finished = ObjectIdentifier(player)

        Task { @MainActor in
            // A bell that landed on this one's tail owns the session now, so
            // only the current player may switch it off.
            guard let current = self.player,
                  ObjectIdentifier(current) == finished else { return }

            self.player = nil

            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }
}
