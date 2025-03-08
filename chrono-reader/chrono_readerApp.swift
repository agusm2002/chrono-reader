//
//  chrono_readerApp.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//
// App/ChronoReaderApp.swift
// App/ChronoReaderApp.swift
import SwiftUI

// Añadir claves al Info.plist
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Aplicación iniciada")
        return true
    }
}

@main
struct ChronoReaderApp: App {
    // Registrar el AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Configurar permisos de acceso a archivos
                    print("Configurando permisos de acceso a archivos")
                }
        }
    }
}
