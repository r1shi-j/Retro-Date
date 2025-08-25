//
//  ContentView.swift
//  Retro Date
//
//  Created by Rishi Jansari on 24/08/2025.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var showSavedAlert = false
    @State private var imageData: Data?
    @State private var isProcessing = false
    
//    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 20) {
            if isProcessing {
                ProgressView()
            } else {
                if let processedImage {
                    Image(uiImage: processedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                } else {
                    Text("Pick an image")
                }
            }
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Select Image")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if let processedImage, let imageData {
                Button("Save to Photos") {
                    saveImage(processedImage, originalData: imageData, albumName: "RetroDate")
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            isProcessing = true
            Task {
                if let newItem, let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    imageData = data
                    selectedImage = uiImage
                    processedImage = addTimestamp(to: uiImage, originalData: data)
                    isProcessing = false
                }
            }
        }
        .alert("Saved!", isPresented: $showSavedAlert) {
            Button("OK", role: .close) { }
            Button("Photos", role: .confirm) {
                UIApplication.shared.open(URL(string: "photos-redirect://")!)
            }
        }
//        .onAppear {
//            print("appear")
//            if let data = appState.importedData {
//                isProcessing = true
//                print("starting")
//                Task {
//                    if let uiImage = UIImage(data: data) {
//                        imageData = data
//                        selectedImage = uiImage
//                        processedImage = addTimestamp(to: uiImage, originalData: data)
//                        isProcessing = false
//                    }
//                }
//            }
//        }
    }
    
    private func addTimestamp(to image: UIImage, originalData: Data) -> UIImage? {
        let timestamp: String
        if let exifDate = getTimestamp(from: originalData) {
            timestamp = exifDate
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            timestamp = formatter.string(from: Date())
        }
        
        let normalizedImage = image.fixedOrientation()
        guard let cgImage = normalizedImage.cgImage else { return nil }
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        let result = renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
            
            let fontSize = pixelSize.height / 30
            let fontName = "Digital-7Italic"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: fontName, size: fontSize) ?? UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor.yellow
            ]
            
            let text = NSString(string: timestamp)
            let textSize = text.size(withAttributes: attributes)
            let offsetX = pixelSize.width / 50
            let offsetY = pixelSize.height / 500
            let point = CGPoint(x: pixelSize.width - textSize.width - offsetX,
                                y: pixelSize.height - textSize.height - offsetY)
            
            ctx.cgContext.setShadow(offset: .zero, blur: 20, color: UIColor(red: 0.94, green: 0.4, blue: 0.4, alpha: 1).cgColor)
            text.draw(at: point, withAttributes: attributes)
            
            ctx.cgContext.setShadow(offset: .zero, blur: 8, color: UIColor(red: 0.97, green: 0.91, blue: 0.22, alpha: 0.8).cgColor)
            text.draw(at: point, withAttributes: attributes)
            
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            text.draw(at: point, withAttributes: attributes)
        }
        
        return result
    }
    
    private func getTimestamp(from data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal] as? String else {
//            print("failed to get timestamp")
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let date = formatter.date(from: dateTimeOriginal) {
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            return formatter.string(from: date)
        }
        
        return nil
    }
    
    private func saveImage(_ processed: UIImage, originalData: Data, albumName: String) {
        guard let cgImage = processed.cgImage else { return }
        
        guard let source = CGImageSourceCreateWithData(originalData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
//            print("Failed to get metadata")
            return
        }
        
        let mutableMetadata = NSMutableDictionary(dictionary: metadata)
        mutableMetadata[kCGImagePropertyOrientation] = 1
        
        let imageData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(imageData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
//            print("Failed to create image destination")
            return
        }
        
        CGImageDestinationAddImage(destination, cgImage, mutableMetadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
//            print("Failed to finalize image with metadata")
            return
        }
        
        let albumName = "RetroDate"
        let folderName = "Apps"
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            
            var targetAlbum: PHAssetCollection?
            let folderFetch = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: nil)
            folderFetch.enumerateObjects { folderObj, _, stop in
                if folderObj.localizedTitle == folderName {
                    let albumFetch = PHAssetCollection.fetchCollections(in: folderObj, options: nil)
                    albumFetch.enumerateObjects { collectionObj, _, stop2 in
                        if let albumObj = collectionObj as? PHAssetCollection, albumObj.localizedTitle == albumName {
                            targetAlbum = albumObj
                            stop2.pointee = true
                        }
                    }
                    stop.pointee = true
                }
            }
            
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData as Data, options: nil)
                
                guard let placeholder = creationRequest.placeholderForCreatedAsset else { return }
                
                if let album = targetAlbum {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                } else {
                    let albumCreationRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    albumCreationRequest.addAssets([placeholder] as NSArray)
                }
            }, completionHandler: { success, error in
                if let error {
                    print("Error saving image with metadata: \(error)")
                } else if success {
                    showSavedAlert = true
                }
            })
        }
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return normalizedImage
    }
}

#Preview {
    ContentView()
}
