//
//  ShareViewController.swift
//  RetroDateShare
//
//  Created by Rishi Jansari on 25/08/2025.
//

import UIKit
import Social

//class ShareViewController: SLComposeServiceViewController {
//    override func isContentValid() -> Bool {
//        // Do validation of contentText and/or NSExtensionContext attachments here
//        return true
//    }
//
//    override func didSelectPost() {
//        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
//    
//        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
//        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
//    }
//
//    override func configurationItems() -> [Any]! {
//        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
//        return []
//    }
//}


//import MobileCoreServices
import Photos
//import ImageIO

//class ShareViewController: UIViewController {
//    
//    override func viewDidLoad() {
//        print("load1")
//        super.viewDidLoad()
//        
//        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
//            extensionContext?.cancelRequest(withError: NSError(domain: "RetroDate", code: 1, userInfo: nil))
//            print("1 exit")
//            return
//        }
//        
//        for provider in item.attachments ?? [] {
//            print("2")
//            if provider.hasItemConformingToTypeIdentifier("public.image") {
//                print("3")
//                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { (item, error) in
//                    print("4")
//                    if let url = item as? URL, let image = UIImage(contentsOfFile: url.path) {
//                        print("5")
//                        DispatchQueue.main.async {
//                            print("load2")
//                            self.openInRetroDate(image)
//                        }
//                    } else if let image = item as? UIImage {
//                        print("6")
//                        DispatchQueue.main.async {
//                            print("load2.5")
//                            self.openInRetroDate(image)
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    private func openInRetroDate(_ image: UIImage) {
//        print("7")
//        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("retrodate_share.jpg")
//        if let data = image.jpegData(compressionQuality: 1.0) {
//            try? data.write(to: tempURL)
//        }
//        print("load3.0")
//        let urlScheme = "retrodate://import?file=\(tempURL.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
//        
//        if let url = URL(string: urlScheme) {
//            self.extensionContext?.open(url, completionHandler: { success in
//                print("load3 complete")
//                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
//            })
//        } else {
//            print("load3 cancel")
//            self.extensionContext?.cancelRequest(withError: NSError(domain: "RetroDate", code: 4))
//        }
//    }
//}

import UIKit
import SwiftUI
import Photos

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create your ContentView variant for the extension
        let contentView = ExtensionContentView { image in
            self.saveToPhotos(image: image)
        }
        
        // Embed SwiftUI in this view controller
        let hostingController = UIHostingController(rootView: contentView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        loadSharedImage()
    }
    
    private func loadSharedImage() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else { return }
        for provider in item.attachments ?? [] {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { (item, error) in
                    if let url = item as? URL, let image = UIImage(contentsOfFile: url.path),
                       let data = try? Data(contentsOf: url) {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .didLoadSharedImage, object: ["image": image, "data": data])
                        }
                    } else if let image = item as? UIImage,
                              let data = image.jpegData(compressionQuality: 1.0) {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .didLoadSharedImage, object: ["image": image, "data": data])
                        }
                    }
                }
            }
        }
    }
    
    private func saveToPhotos(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { success, error in
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
    }
}

extension Notification.Name {
    static let didLoadSharedImage = Notification.Name("didLoadSharedImage")
}
import SwiftUI

struct ExtensionContentView: View {
    @State private var data: Data?
    @State private var image: UIImage?
    let saveAction: (UIImage) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                
                Button("Add Timestamp & Save") {
                    // Call your existing addTimestamp function
                    if let data {
                        if let stamped = addTimestamp(to: image, originalData: data) {
                            saveAction(stamped)
                        }
                    }
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Loading image…")
            }
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: .didLoadSharedImage)) { notification in
            if let dict = notification.object as? [String: Any],
               let img = dict["image"] as? UIImage,
               let imgData = dict["data"] as? Data {
                self.image = img
                self.data = imgData
            }
        }
    }
    
    private func addTimestamp(to image: UIImage, originalData: Data) -> UIImage? {
        // Get timestamp from EXIF if possible
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
        return renderer.image { ctx in
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
