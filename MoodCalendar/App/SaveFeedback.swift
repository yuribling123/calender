import AVFoundation

enum SaveFeedback {
    private static var activePlayer: AVAudioPlayer?

    static func play() {
        guard let url = Bundle.main.url(forResource: "save-chime", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }

        player.volume = 0.32
        player.prepareToPlay()
        player.play()
        activePlayer = player
    }
}
