import Flutter
import Foundation
import CoreNFC

@available(iOS 11.0, *)
public class SwiftFlutterNfcReaderPlugin: NSObject, FlutterPlugin {
    
    fileprivate var nfcSession: NFCNDEFReaderSession? = nil
    fileprivate var resulter: FlutterResult? = nil

    fileprivate let kId = "nfcId"
    fileprivate let kContent = "nfcContent"
    fileprivate let kStatus = "nfcStatus"
    fileprivate let kError = "nfcError"
    fileprivate let kErrorCode = "nfcErrorCode"
    
    fileprivate var eventSink: FlutterEventSink?
    fileprivate var flutterListening: Bool? = false;

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "flutter_nfc_reader/read", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "flutter_nfc_reader/stream", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterNfcReaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance);
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "NfcRead":
            let map = call.arguments as? Dictionary<String, String>
            let instruction = map?["instruction"] ?? ""
            resulter = result
            activateNFC(instruction, invalidateAfterFirstRead: true)
        case "NfcStop":
            disableNFC()
        default:
            result("iOS " + UIDevice.current.systemVersion)
        }
    }

}

// MARK: - NFC Actions
@available(iOS 11.0, *)
extension SwiftFlutterNfcReaderPlugin {
    func activateNFC(_ instruction: String?, invalidateAfterFirstRead: Bool? = false) {
        
        let invalidateAfterFirstRead = invalidateAfterFirstRead ?? false
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: DispatchQueue(label: "queueName", attributes: .concurrent), invalidateAfterFirstRead: invalidateAfterFirstRead)
        
        // then setup a new session
        if let instruction = instruction {
            nfcSession?.alertMessage = instruction
        }
        
        // start
        if let nfcSession = nfcSession {
            nfcSession.begin()
        }
    }
    
    func disableNFC() {
        nfcSession?.invalidate()
        let data = [kId: "", kContent: "", kError: "", kStatus: "stopped"]

        resulter?(data)
        resulter = nil
    }

}

// MARK: - NFCDelegate
@available(iOS 11.0, *)
extension SwiftFlutterNfcReaderPlugin : NFCNDEFReaderSessionDelegate, FlutterStreamHandler {
    
    
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else { return }
	    guard let payload = message.records.first else { return }
	    guard let payloadContent = String(data: payload.payload, encoding: String.Encoding.utf8) else { return }

        let data = [kId: "", kContent: payloadContent, kError: "", kStatus: "read", kErrorCode: 0] as [String : Any]

        if (eventSink != nil) {
            eventSink!(data)
        }
        
        resulter?(data);
        
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        
        if let readerError = error as? NFCReaderError {
            if (readerError.code == .readerSessionInvalidationErrorFirstNDEFTagRead) {
                print("Single tag read")
                nfcSession = nil
            } else {
                let data = [kId: "", kContent: "", kError: error.localizedDescription, kStatus: "error", kErrorCode: error._code] as [String : Any]
                
                if (eventSink != nil) {
                    eventSink!(data)
                }
                
                resulter?(data);
            }
        }
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        self.flutterListening=true
        if let args = arguments as? Array<Any> {
            if args.count > 0 {
                let options=args[0] as? Dictionary<String, Any>
                if let instruction = options?["instruction"] as? String {
                    self.activateNFC(instruction);
                }
            }
        }
        return nil
    }
}
