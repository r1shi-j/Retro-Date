//
//  PhotoEditingViewController.swift
//  RetroDatePhotoEditor
//
//  Created by Rishi Jansari on 24/08/2025.
//

import UIKit
import Photos
import PhotosUI

class PhotoEditingViewController: UIViewController, PHContentEditingController {
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func applyOverlayTapped(_ sender: UIButton) {
        guard let image = imageView.image else { return }
        imageView.image = addTimestamp(to: image)
    }
    
    var input: PHContentEditingInput!
    
    var shouldShowCancelConfirmation: Bool {
        return true
    }
    
    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        return true
    }
    
    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: UIImage) {
        self.input = contentEditingInput
        
        imageView.image = UIImage(contentsOfFile: input.fullSizeImageURL!.path)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)
    }
    
    func finishContentEditing(completionHandler: @escaping (PHContentEditingOutput?) -> Void) {
        guard let input = self.input,
              let editedImage = imageView.image,
              let jpegData = editedImage.jpegData(compressionQuality: 1.0) else {
            completionHandler(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let output = PHContentEditingOutput(contentEditingInput: input)
            
            let adjustmentInfo = "Applied RetroDate timestamp overlay"
            output.adjustmentData = PHAdjustmentData(
                formatIdentifier: "com.jansari.rishi.Retro-Date",
                formatVersion: "1.0",
                data: adjustmentInfo.data(using: .utf8) ?? Data()
            )
            
            do {
                try jpegData.write(to: output.renderedContentURL, options: .atomic)
//                print("Wrote edited JPEG to \(output.renderedContentURL)")
                completionHandler(output)
            } catch {
//                print("Error writing edited image: \(error)")
                completionHandler(nil)
            }
        }
    }
    
    func cancelContentEditing() {
//        print("cancel")
    }
    
    private func getTimestamp(from input: PHContentEditingInput) -> String? {
        guard let url = input.fullSizeImageURL,
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
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
    
    private func addTimestamp(to image: UIImage) -> UIImage {
        let timestamp: String
        if let exifDate = getTimestamp(from: self.input) {
            timestamp = exifDate
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            timestamp = formatter.string(from: Date())
        }
    
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: image.size))

            let fontSize = image.size.height / 30
            let fontName = "Digital-7Italic"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: fontName, size: fontSize) ?? UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor.yellow
            ]

            let timestampFormatter = DateFormatter()
            timestampFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            let text = NSString(string: timestamp)
            let textSize = text.size(withAttributes: attributes)
            let offsetX = image.size.width / 50
            let offsetY = image.size.height / 500
            let point = CGPoint(x: image.size.width - textSize.width - offsetX,
                                y: image.size.height - textSize.height - offsetY)

            ctx.cgContext.setShadow(offset: .zero, blur: 20, color: UIColor(red: 0.94, green: 0.4, blue: 0.4, alpha: 1).cgColor)
            text.draw(at: point, withAttributes: attributes)

            ctx.cgContext.setShadow(offset: .zero, blur: 8, color: UIColor(red: 0.97, green: 0.91, blue: 0.22, alpha: 0.8).cgColor)
            text.draw(at: point, withAttributes: attributes)
            
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            text.draw(at: point, withAttributes: attributes)
        }
    }
}
