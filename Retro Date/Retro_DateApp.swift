//
//  Retro_DateApp.swift
//  Retro Date
//
//  Created by Rishi Jansari on 24/08/2025.
//

import SwiftUI

@Observable
class AppState {
//    var importedImage: UIImage?
    var importedData: Data?
    var shouldPresentEditor = false
}

@main
struct Retro_DateApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    handleRetroDateURL(url)
                }
        }
    }
    
    private func handleRetroDateURL(_ url: URL) {
        // retrodate://import?file=/path/to/file.jpg
        guard url.scheme == "retrodate", url.host == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value
        else { return }
        
        let decodedPath = fileParam.removingPercentEncoding ?? fileParam
        let fileURL = URL(fileURLWithPath: decodedPath)
        
        // Load off the main thread, then publish on the main thread
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: fileURL)/*,
                  let image = UIImage(data: data)*/ else {
                print("RetroDate: failed to read image at \(fileURL.path)")
                return
            }
            DispatchQueue.main.async {
//                appState.importedImage = image
                appState.importedData = data
                appState.shouldPresentEditor = true
            }
        }
    }
}
