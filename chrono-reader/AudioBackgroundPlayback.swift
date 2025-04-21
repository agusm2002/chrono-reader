import SwiftUI
import AVFoundation

// Este archivo se encarga de configurar la reproducción en segundo plano a nivel de aplicación
// Se debe incluir en el archivo principal de la aplicación (App.swift o similar)

struct AudioBackgroundPlaybackModifier: ViewModifier {
    @State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                setupBackgroundPlayback()
            }
            .onDisappear {
                endBackgroundTask()
            }
    }
    
    private func setupBackgroundPlayback() {
        // Configurar la sesión de audio para reproducción en segundo plano
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                policy: .longFormAudio,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Registrar para notificaciones de interrupción
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Reactivar la sesión de audio después de una interrupción
                try? AVAudioSession.sharedInstance().setActive(true)
            }
            
            // Iniciar una tarea en segundo plano
            registerBackgroundTask()
            
        } catch {
            print("Error al configurar la reproducción en segundo plano: \(error)")
        }
    }
    
    private func registerBackgroundTask() {
        // Finalizar cualquier tarea en segundo plano existente
        endBackgroundTask()
        
        // Registrar una nueva tarea en segundo plano
        backgroundTask = UIApplication.shared.beginBackgroundTask { [self] in
            endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// Extensión para facilitar el uso del modificador
extension View {
    func enableAudioBackgroundPlayback() -> some View {
        self.modifier(AudioBackgroundPlaybackModifier())
    }
}
