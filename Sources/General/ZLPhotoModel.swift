//
//  ZLPhotoModel.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/11.
//
//  Copyright (c) 2020 Long Zhang <495181165@qq.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit
import Photos

public extension ZLPhotoModel {
    enum MediaType: Int {
        case unknown = 0
        case image
        case gif
        case livePhoto
        case video
    }
}

public class ZLPhotoModel: NSObject {
    public let ident: String
    
    public let asset: PHAsset

    public var type: ZLPhotoModel.MediaType = .unknown
    
    public var duration = ""
    
    public var image: UIImage? = nil
    
    public var videoUrl: URL? = nil
    
    public var isSelected = false
    
    private var pri_dataSize: ZLPhotoConfiguration.KBUnit?
    
    public var dataSize: ZLPhotoConfiguration.KBUnit? {
        if let pri_dataSize = pri_dataSize {
            return pri_dataSize
        }
        
        let size = ZLPhotoManager.fetchAssetSize(for: asset)
        pri_dataSize = size
        
        return size
    }
    
    private var pri_editImage: UIImage?
    
    public var editImage: UIImage? {
        set {
            pri_editImage = newValue
        }
        get {
            if let _ = editImageModel {
                return pri_editImage
            } else {
                return nil
            }
        }
    }
    
    public var second: ZLPhotoConfiguration.Second {
        guard type == .video else {
            return 0
        }
        return Int(round(asset.duration))
    }
    
    public var whRatio: CGFloat {
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }
    
    public var previewSize: CGSize {
        let scale: CGFloat = UIScreen.main.scale
        if whRatio > 1 {
            let h = min(UIScreen.main.bounds.height, ZLMaxImageWidth) * scale
            let w = h * whRatio
            return CGSize(width: w, height: h)
        } else {
            let w = min(UIScreen.main.bounds.width, ZLMaxImageWidth) * scale
            let h = w / whRatio
            return CGSize(width: w, height: h)
        }
    }
    
    // Content of the last edit.
    public var editImageModel: ZLEditImageModel?
    
    public init(asset: PHAsset) {
        ident = asset.localIdentifier
        self.asset = asset
        super.init()
        
        type = transformAssetType(for: asset)
        if type == .video {
            duration = transformDuration(for: asset)
        }
        getImageFromPHAsset(phAsset: asset) { img in
            self.image = img
        }
        getVideoURL(for: asset) { url in
            self.videoUrl = url
        }
    }
    
    public func getVideoURL(for asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let options = PHVideoRequestOptions()
        options.version = .original

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, _, _) in
            guard let avAsset = avAsset else {
                completion(nil)
                return
            }

            if let urlAsset = avAsset as? AVURLAsset {
                // If it's already an AVURLAsset, use its URL directly
                let videoURL = urlAsset.url
                completion(videoURL)
            } else {
                // If it's not an AVURLAsset, export it to a temporary file
                let temporaryDirectoryURL = FileManager.default.temporaryDirectory
                let uniqueFilename = ProcessInfo.processInfo.globallyUniqueString
                let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("\(uniqueFilename).mov")

                do {
                    let exporter = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
                    exporter?.outputFileType = AVFileType.mov
                    exporter?.outputURL = temporaryFileURL

                    exporter?.exportAsynchronously {
                        if exporter?.status == .completed {
                            completion(temporaryFileURL)
                        } else {
                            completion(nil)
                        }
                    }
                } catch {
                    completion(nil)
                }
            }
        }
    }
    
    public func getImageFromPHAsset(phAsset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let imageManager = PHImageManager.default()

        // Define options for retrieving the image
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat

        // Request the image data for the PHAsset
        imageManager.requestImage(for: phAsset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: requestOptions) { (image, info) in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    public func transformAssetType(for asset: PHAsset) -> ZLPhotoModel.MediaType {
        switch asset.mediaType {
        case .video:
            return .video
        case .image:
            if asset.zl.isGif {
                return .gif
            }
            if asset.mediaSubtypes.contains(.photoLive) {
                return .livePhoto
            }
            return .image
        default:
            return .unknown
        }
    }
    
    public func transformDuration(for asset: PHAsset) -> String {
        let dur = Int(round(asset.duration))
        
        switch dur {
        case 0..<60:
            return String(format: "00:%02d", dur)
        case 60..<3600:
            let m = dur / 60
            let s = dur % 60
            return String(format: "%02d:%02d", m, s)
        case 3600...:
            let h = dur / 3600
            let m = (dur % 3600) / 60
            let s = dur % 60
            return String(format: "%02d:%02d:%02d", h, m, s)
        default:
            return ""
        }
    }
}

public extension ZLPhotoModel {
    static func == (lhs: ZLPhotoModel, rhs: ZLPhotoModel) -> Bool {
        return lhs.ident == rhs.ident
    }
}
