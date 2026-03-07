import Foundation
import UIKit

// Este archivo contiene la configuración necesaria para habilitar la reproducción en segundo plano
// NOTA: Es necesario habilitar manualmente la capacidad "Background Modes" en Xcode

class BackgroundPlaybackConfig {
    static let shared = BackgroundPlaybackConfig()
    
    private init() {}
    
    // Esta función debe ser llamada desde el AppDelegate o SceneDelegate
    func configureBackgroundPlayback() {
        // Registrar para recibir eventos de control remoto
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        // Registrar para notificaciones de ciclo de vida de la aplicación
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        print("BackgroundPlaybackConfig: Configuración inicializada")
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("BackgroundPlaybackConfig: Aplicación entró en segundo plano")
        // Aquí puedes agregar código adicional para manejar la transición a segundo plano
    }
    
    @objc private func handleAppWillEnterForeground() {
        print("BackgroundPlaybackConfig: Aplicación volverá a primer plano")
        // Aquí puedes agregar código adicional para manejar la transición a primer plano
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}

// INSTRUCCIONES PARA HABILITAR LA REPRODUCCIÓN EN SEGUNDO PLANO EN XCODE:
/*
 1. Abre el proyecto en Xcode
 2. Selecciona el target principal de la aplicación
 3. Ve a la pestaña "Signing & Capabilities"
 4. Haz clic en "+ Capability"
 5. Busca y añade "Background Modes"
 6. Marca la casilla "Audio, AirPlay, and Picture in Picture"
 
 Esto añadirá automáticamente la configuración necesaria al archivo Info.plist del proyecto.
 */
