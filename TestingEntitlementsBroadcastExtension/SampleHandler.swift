import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    var fileManager: FileManager!
    var groupURL: URL!
    var fileURL: URL!

    override init() {
        super.init()
        setup()
    }

    func setup() {
        fileManager = FileManager.default
        groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.knophy.mybroadcast")!
        fileURL = groupURL.appendingPathComponent("identity.txt")
    }

    func writeIdentity() {
        do {
            try "asdfasdfasdf".write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write identity: \(error)")
        }
    }

    func readIdentity() -> String {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Failed to read identity: \(error)")
            return ""
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        logEvent("Broadcast started - Setup Info: \(String(describing: setupInfo))")

      print(writeIdentity())
        print(readIdentity())
    }
    
    override func broadcastPaused() {
        logEvent("Broadcast paused")
    }
    
    override func broadcastResumed() {
        logEvent("Broadcast resumed")
    }
    
    override func broadcastFinished() {
        logEvent("Broadcast finished")
    }
    
    override func broadcastAnnotated(withApplicationInfo applicationInfo: [AnyHashable : Any]) {
        if let applicationName = applicationInfo["UIApplicationOpenURLOptionUniversalLinksOnly"] as? String {
            logEvent("Application opened: \(applicationName)")
        } else {
            logEvent("Received application info: \(applicationInfo)")
        }
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            logEvent("Processing video sample buffer")
            // Handle video sample buffer
            break
        case RPSampleBufferType.audioApp:
            logEvent("Processing app audio sample buffer")
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
            logEvent("Processing microphone audio sample buffer")
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
            logEvent("Encountered unknown type of sample buffer")
            fatalError("Unknown type of sample buffer")
        }
    }
}
func logEvent(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let timestamp = formatter.string(from: Date())
    print("\(timestamp): \(message)")
}
