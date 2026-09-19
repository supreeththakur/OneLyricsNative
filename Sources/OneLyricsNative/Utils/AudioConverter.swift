import Foundation
import AVFoundation

enum AudioConverter {
    enum ConversionError: Error {
        case exportSessionCreationFails
        case exportFailed
        case unknown
    }
    
    /// Converts the source audio file to M4A (AAC) and saves it to a temporary directory.
    /// - Parameter sourceURL: The URL of the audio file to convert (e.g. MP3).
    /// - Returns: The URL of the converted `.m4a` file.
    static func convertToM4A(sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        
        // Wait for tracks to be loaded to ensure it's a valid audio file
        let _ = try await asset.load(.tracks)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ConversionError.exportSessionCreationFails
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".m4a"
        let destinationURL = tempDir.appendingPathComponent(fileName)
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return destinationURL
        case .failed, .cancelled:
            if let error = exportSession.error {
                throw error
            }
            throw ConversionError.exportFailed
        default:
            throw ConversionError.unknown
        }
    }
}
