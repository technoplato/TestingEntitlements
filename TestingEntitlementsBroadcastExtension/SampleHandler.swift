import ReplayKit
import Combine
import Photos
import Dispatch
import MachO

func currentMemoryUsage() -> UInt? {
    var taskInfo = task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size) / 4
    let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
        }
    }

    if result == KERN_SUCCESS {
        return taskInfo.resident_size
    } else {
        print("Error with task_info(): " +
                (String(cString: mach_error_string(result), encoding: .ascii) ?? "unknown error"))
        return nil
    }
}

let memoryInfoPublisher = Timer.publish(every: 0.1, on: .main, in: .common)
    .autoconnect()
    .map { _ in currentMemoryUsage() }
    .eraseToAnyPublisher()

class SampleHandler: RPBroadcastSampleHandler {
    func reportMemory() {
        var taskInfo = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size)/4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            logEvent("Memory in use (in bytes): \(taskInfo.resident_size)")
        } else {
            logEvent("Error with task_info(): " +
                (String(cString: mach_error_string(result), encoding: .ascii) ?? "unknown error"))
        }
    }
    var fileManager: FileManager!
    var groupURL: URL!
    var fileURL: URL!
    var framesSaved = 0
  var previousTimestamp = 0.0
    let videoFramePublisher = PassthroughSubject<CMSampleBuffer, Never>()
    var cancellables = Set<AnyCancellable>()
  var ciContext: CIContext! // Reusable CIContext
  var latestSampleBuffer: CMSampleBuffer?
  
  override init() {
      super.init()
      setup()
    ciContext = CIContext() // Initialize the CIContext

      videoFramePublisher
          .sink { [weak self] sampleBuffer in
              self?.latestSampleBuffer = sampleBuffer
          }
          .store(in: &cancellables)

      Timer.publish(every: 1.0, on: .main, in: .common)
          .autoconnect()
          .sink { [weak self] _ in
              guard let self = self, self.framesSaved < 5, let sampleBuffer = self.latestSampleBuffer else { return }

              let timestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer).seconds
              if timestamp - self.previousTimestamp >= 1.0 {
                  self.saveFrameToPhotoLibrary(sampleBuffer)
                  self.previousTimestamp = timestamp
                  self.latestSampleBuffer = nil // Reset the latest frame
              }
          }
          .store(in: &cancellables)

  
    
    memoryInfoPublisher
        .sink { memoryUsage in
            guard let memoryUsage = memoryUsage else { return }
            print("Current memory usage: \(memoryUsage)")

            // Implement your logic to buffer or process frames based on memory usage
            // For example:
//            if memoryUsage < someSafeMemoryThreshold {
//                // Safe to process frames
//            } else {
//                // Buffer frames or take other memory-reducing actions
//            }
        }
        .store(in: &cancellables)
  }
  
    func setup() {
        logEvent("Setting up...")
        fileManager = FileManager.default
        groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.knophy.mybroadcast")!
        fileURL = groupURL.appendingPathComponent("identity.txt")
    }

  func saveFrameToPhotoLibrary(_ sampleBuffer: CMSampleBuffer) {
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    print("Failed to get image buffer from sample buffer.")
                    return
                }

                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                
                if let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                    print("CGImage created successfully.")
                    
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: UIImage(cgImage: cgImage))
                    }, completionHandler: { [weak self] success, error in
                        DispatchQueue.main.async {
                            if success {
                                self?.framesSaved += 1
                                print("Frame saved successfully.")
                            } else {
                                print("Failed to save frame: \(String(describing: error))")
                            }
                        }
                    })
                } else {
                    print("Failed to create CGImage.")
                }
            }
        }
    }


    func writeIdentity() {
        do {
            try "asdfasdfasdf".write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            logEvent("Failed to write identity: \(error)")
        }
    }

    func readIdentity() -> String {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            logEvent("Failed to read identity: \(error)")
            return ""
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        logEvent("Broadcast started - Setup Info: \(String(describing: setupInfo))")

        logEvent(readIdentity())
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
//            logEvent("Processing video sample buffer")
            videoFramePublisher.send(sampleBuffer)
        case RPSampleBufferType.audioApp:
//            logEvent("Processing app audio sample buffer")
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
//            logEvent("Processing microphone audio sample buffer")
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
//            logEvent("Encountered unknown type of sample buffer")
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

