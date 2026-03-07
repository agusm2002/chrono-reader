import Foundation
import AVFoundation
import MediaPlayer
import UIKit

// Gestor de audio para reproducción en segundo plano
class AudioManager {
    static let shared = AudioManager()
    
    // Estado para el scrubbing
    private var isScrubbingEnabled = false
    
    // Variable para evitar spam de mensajes de log sobre cambios de tema
    static var lastThemeChangeLogTime: Date = Date(timeIntervalSince1970: 0)
    static let logThrottleInterval: TimeInterval = 5 // Limitar logs a uno cada 5 segundos
    
    // Prevenir múltiples instancias
    private init() {
        setupAudioSession()
        setupRemoteCommandHandling()
    }
    
    // Configurar la sesión de audio para reproducción en segundo plano
    func setupAudioSession() {
        do {
            // Configuración para reproducción en segundo plano
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                policy: .longFormAudio,
                options: [.duckOthers, .mixWithOthers]
            )
            
            // Activar la sesión
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            // Registrar para recibir eventos de control remoto
            UIApplication.shared.beginReceivingRemoteControlEvents()
            
            print("Sesión de audio configurada correctamente para reproducción en segundo plano")
        } catch {
            print("Error al configurar la sesión de audio: \(error)")
        }
    }
    
    // Configurar manejo de comandos remotos a nivel global
    private func setupRemoteCommandHandling() {
        // Asegurarse de que el scrubbing esté habilitado globalmente
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Habilitar el comando para cambiar la posición de reproducción
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        // Registrar para notificaciones de cambio de ruta de audio
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Registrar para notificaciones de interrupción
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    // Manejar cambios en la ruta de audio (auriculares, altavoces, etc.)
    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Reactivar la sesión de audio si es necesario
        if reason == .newDeviceAvailable || reason == .categoryChange {
            reactivateAudioSession()
        }
    }
    
    // Manejar interrupciones de audio (llamadas telefónicas, alarmas, etc.)
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .ended {
            // Reactivar la sesión de audio cuando termina la interrupción
            reactivateAudioSession()
        }
    }
    
    // Reactivar la sesión de audio (llamar cuando se reanuda la app)
    func reactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Sesión de audio reactivada")
        } catch {
            print("Error al reactivar la sesión de audio: \(error)")
        }
    }
    
    // Desactivar la sesión de audio (llamar cuando se cierra el reproductor)
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            UIApplication.shared.endReceivingRemoteControlEvents()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            print("Sesión de audio desactivada")
        } catch {
            print("Error al desactivar la sesión de audio: \(error)")
        }
    }
}

// Variable global para interceptar NSLog
var logPrint: (String) -> Void = { message in
    // Filtrar mensajes de spam sobre cambios de tema
    if message.contains("Cambio detectado en el color del tema") {
        let now = Date()
        if now.timeIntervalSince(AudioManager.lastThemeChangeLogTime) >= AudioManager.logThrottleInterval {
            AudioManager.lastThemeChangeLogTime = now
            NSLog("⚠️ Múltiples detecciones de cambio de tema durante la reproducción de audio - Esto podría afectar el rendimiento")
        }
    } else {
        NSLog("%@", message)
    }
}
