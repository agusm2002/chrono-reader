import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit

// Clase para manejar notificaciones de la aplicación
class AppLifecycleObserver: ObservableObject {
    init() {
        // Registrar para notificaciones de ciclo de vida de la aplicación
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc func appDidEnterBackground() {
        print("Aplicación entró en segundo plano")
        // Asegurarse de que la sesión de audio siga activa
        AudioManager.shared.reactivateAudioSession()
    }
    
    @objc func appWillEnterForeground() {
        print("Aplicación volverá al primer plano")
        // Reactivar la sesión de audio
        AudioManager.shared.reactivateAudioSession()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

class AudioPlayerViewModel: ObservableObject {
    // Reproductor de audio
    private var audioPlayer: AVPlayer?
    private var timeObserverToken: Any?
    
    // Estado del reproductor
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var loadingState: LoadingState = .loading
    @Published var playbackRate: Float = 1.0
    @Published var showChapters: Bool = false
    @Published var chapters: [AudioChapter] = []
    @Published var currentChapterIndex: Int = 0
    
    // Propiedades para el progreso por capítulo
    @Published var currentChapterProgress: Double = 0 // Progreso de 0 a 1 dentro del capítulo actual
    
    // Libro actual
    private var book: CompleteBook
    
    enum LoadingState {
        case loading
        case ready
        case failed
    }
    
    init(book: CompleteBook) {
        self.book = book
        // Asegurarse de que la sesión de audio esté configurada
        AudioManager.shared.setupAudioSession()
        setupAudioPlayer()
    }
    
    deinit {
        removePeriodicTimeObserver()
        
        // Desactivar la sesión de audio al finalizar
        AudioManager.shared.deactivateAudioSession()
        
        // Eliminar observadores de notificaciones
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupAudioPlayer() {
        guard let url = book.metadata.localURL else {
            loadingState = .failed
            return
        }
        
        // La configuración de la sesión de audio ahora se maneja en AudioManager
        
        // Configurar controles remotos (centro de control)
        setupRemoteTransportControls()
        
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // Configuración avanzada del reproductor para segundo plano
        audioPlayer?.automaticallyWaitsToMinimizeStalling = true
        audioPlayer?.allowsExternalPlayback = true
        
        // Prevenir que el sistema suspenda la reproducción
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error al activar la sesión de audio: \(error)")
        }
        
        // Registrar para notificaciones de ruta de audio
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Obtener la duración
        asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            guard let self = self else { return }
            
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            DispatchQueue.main.async {
                if status == .loaded {
                    self.duration = asset.duration.seconds
                    self.loadingState = .ready
                    self.setupPeriodicTimeObserver()
                    self.loadChapters(from: asset)
                    
                    // Restaurar la posición guardada
                    self.restoreSavedProgress()
                } else {
                    self.loadingState = .failed
                }
            }
        }
        
        // Observar cuando termina la reproducción
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    private func loadChapters(from asset: AVAsset) {
        asset.loadValuesAsynchronously(forKeys: ["availableChapterLocales"]) { [weak self] in
            guard let self = self else { return }
            
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "availableChapterLocales", error: &error)
            
            if status == .loaded, let locale = asset.availableChapterLocales.first {
                let chapterMetadataGroups = asset.chapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: [AVMetadataKey.commonKeyTitle])
                
                DispatchQueue.main.async {
                    self.chapters = chapterMetadataGroups.enumerated().compactMap { index, group in
                        guard let titleItem = AVMetadataItem.metadataItems(from: group.items, filteredByIdentifier: AVMetadataIdentifier.commonIdentifierTitle).first,
                              let title = titleItem.stringValue
                        else { return nil }
                        
                        let timeRange = group.timeRange
                        
                        return AudioChapter(
                            id: index,
                            title: title,
                            startTime: timeRange.start.seconds,
                            duration: timeRange.duration.seconds
                        )
                    }
                    
                    if self.chapters.isEmpty {
                        // Si no hay capítulos definidos, crear uno para todo el audio
                        self.chapters = [AudioChapter(
                            id: 0,
                            title: self.book.displayTitle,
                            startTime: 0,
                            duration: self.duration
                        )]
                    }
                }
            }
        }
    }
    
    @objc private func playerDidFinishPlaying(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isPlaying = false
            self.currentTime = 0
            
            // Guardar el progreso como completado
            self.saveProgress(progress: 1.0)
        }
    }
    
    // MARK: - Controles remotos y manejo de interrupciones
    
    private func setupRemoteTransportControls() {
        // Obtener el centro de comandos remotos
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Añadir manejadores para los comandos remotos
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.togglePlayPause()
                return .success
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.togglePlayPause()
                return .success
            }
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)] // 15 segundos
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.skipForward()
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)] // 15 segundos
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.skipBackward()
            return .success
        }
        
        // Habilitar el comando para cambiar la posición de reproducción (arrastrar la barra de progreso)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, 
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            // Obtener la nueva posición en segundos
            let newPosition = positionEvent.positionTime
            
            // Verificar que la posición sea válida
            guard newPosition >= 0, newPosition <= self.duration else {
                return .commandFailed
            }
            
            // Buscar a la nueva posición
            self.seek(to: newPosition)
            print("Control remoto: Cambio de posición a \(newPosition) segundos")
            
            return .success
        }
        
        // Configurar observadores para interrupciones de audio
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // La interrupción comenzó (llamada telefónica, alarma, etc.)
            if isPlaying {
                // Guardar el estado pero no llamar a togglePlayPause para evitar problemas
                isPlaying = false
                audioPlayer?.pause()
                
                // Actualizar la información de reproducción
                updateNowPlayingInfo()
            }
        case .ended:
            // La interrupción terminó
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                
                // Si la interrupción terminó y se puede reanudar, reanudar la reproducción
                if options.contains(.shouldResume) && !isPlaying {
                    // Reactivar la sesión de audio primero
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        print("Error al reactivar la sesión de audio: \(error)")
                    }
                    
                    // Reanudar la reproducción
                    isPlaying = true
                    audioPlayer?.play()
                    
                    // Actualizar la información de reproducción
                    updateNowPlayingInfo()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Manejar cambios en la ruta de audio (auriculares conectados/desconectados, etc.)
        switch reason {
        case .oldDeviceUnavailable:
            // Dispositivo de salida desconectado (auriculares desconectados)
            if isPlaying {
                togglePlayPause()
            }
        case .newDeviceAvailable, .categoryChange:
            // Nuevo dispositivo conectado o cambio de categoría
            // Reactivar la sesión para asegurar que el audio sigue funcionando
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Error al reactivar la sesión de audio: \(error)")
            }
        default:
            break
        }
    }
    
    // Actualizar la información en el centro de control
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        // Añadir título, artista y álbum
        nowPlayingInfo[MPMediaItemPropertyTitle] = book.book.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = book.book.author
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Audiolibro"
        
        // Añadir duración y posición actual
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        
        // Añadir tasa de reproducción
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        
        // Añadir información para el scrubbing (arrastrar la barra de progreso)
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = duration > 0 ? currentTime / duration : 0
        
        // Añadir portada si está disponible
        if let image = book.getCoverImage() {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // Actualizar la información
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupPeriodicTimeObserver() {
        // Crear un intervalo de tiempo para actualizar la posición actual
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // Añadir un observador periódico para actualizar la posición actual
        timeObserverToken = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let seconds = CMTimeGetSeconds(time)
            if !seconds.isNaN && !seconds.isInfinite {
                self.currentTime = seconds
                
                // Actualizar el índice del capítulo actual y el progreso dentro del capítulo
                self.updateCurrentChapterInfo()
                
                // Actualizar la información en el centro de control para mantener
                // la barra de progreso actualizada
                self.updateNowPlayingInfo()
                
                // Guardar la posición actual para reanudar más tarde
                if let url = self.book.metadata.localURL?.absoluteString {
                    UserDefaults.standard.set(seconds, forKey: "audioPosition_\(url)")
                }
            }
        }
    }
    
    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    // MARK: - Controles de reproducción
    
    func togglePlayPause() {
        // Asegurarse de que la sesión de audio esté activa antes de reproducir
        if !isPlaying {
            // Reactivar la sesión de audio
            AudioManager.shared.reactivateAudioSession()
            audioPlayer?.play()
        } else {
            audioPlayer?.pause()
        }
        
        isPlaying.toggle()
        
        // Actualizar la información en el centro de control
        updateNowPlayingInfo()
        
        // Imprimir estado para depuración
        print("Audio estado: \(isPlaying ? "reproduciendo" : "pausado")")
    }
    
    func seek(to time: Double) {
        guard duration > 0, time >= 0, time <= duration else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        
        // Asegurarse de que la sesión de audio esté activa
        AudioManager.shared.reactivateAudioSession()
        
        // Usar try? para manejar posibles errores sin crashear
        try? audioPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] success in
            if success {
                // Actualizar inmediatamente la información en el centro de control
                // después de cambiar la posición
                self?.currentTime = time
                self?.updateCurrentChapterInfo()
                self?.updateNowPlayingInfo()
            }
        })
    }
    
    func skipForward() {
        guard let currentTime = audioPlayer?.currentTime().seconds else { return }
        let newTime = min(currentTime + 15, duration)
        seek(to: newTime)
    }
    
    func skipBackward() {
        guard let currentTime = audioPlayer?.currentTime().seconds else { return }
        let newTime = max(currentTime - 15, 0)
        seek(to: newTime)
    }
    
    func setPlaybackRate(_ rate: Float) {
        // No actualizar si la tasa es la misma para evitar reconstrucciones innecesarias
        if abs(playbackRate - rate) < 0.01 {
            return
        }
        
        // Actualizar en main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Actualizar el reproductor y la propiedad publicada
            self.playbackRate = rate
            self.audioPlayer?.rate = rate
            
            // Actualizar la información de reproducción para reflejar la nueva velocidad
            self.updateNowPlayingInfo()
            
            // Imprimir estado para depuración
            print("Velocidad de reproducción actualizada a: \(rate)x")
        }
    }
    
    func jumpToChapter(_ chapterIndex: Int) {
        guard chapterIndex < chapters.count else { return }
        let chapter = chapters[chapterIndex]
        seek(to: chapter.startTime)
        currentChapterIndex = chapterIndex
    }
    
    // Avanzar al siguiente capítulo
    func nextChapter() {
        guard !chapters.isEmpty else { return }
        let nextIndex = min(currentChapterIndex + 1, chapters.count - 1)
        if nextIndex != currentChapterIndex {
            jumpToChapter(nextIndex)
        }
    }
    
    // Retroceder al capítulo anterior
    func previousChapter() {
        guard !chapters.isEmpty else { return }
        let prevIndex = max(currentChapterIndex - 1, 0)
        if prevIndex != currentChapterIndex {
            jumpToChapter(prevIndex)
        }
    }
    
    // MARK: - Gestión de progreso
    
    func saveProgress(progress: Double) {
        // Evitar actualizaciones innecesarias
        if abs(progress - book.book.progress) < 0.01 {
            return
        }
        
        // Usar un valor redondeado para evitar actualizaciones con valores muy similares
        let roundedProgress = (progress * 100).rounded() / 100
        
        // Crear una copia local para evitar referencias circulares
        let bookCopy = book
        
        // Ejecutar en un hilo en segundo plano para evitar bloquear la UI
        DispatchQueue.global(qos: .background).async {
            let updatedBook = bookCopy.withUpdatedProgress(roundedProgress)
            
            // Notificar en el hilo principal
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("BookProgressUpdated"),
                    object: nil,
                    userInfo: ["book": updatedBook]
                )
            }
        }
    }
    
    // Método para actualizar el capítulo actual basado en el tiempo
    private func updateCurrentChapterIndex() {
        // Buscar el capítulo que contiene la posición actual
        for (index, chapter) in chapters.enumerated() {
            let chapterEndTime = chapter.startTime + chapter.duration
            if currentTime >= chapter.startTime && currentTime < chapterEndTime {
                currentChapterIndex = index
                return
            }
        }
        
        // Si no se encuentra un capítulo específico, usar el último
        if !chapters.isEmpty && currentTime >= duration * 0.99 {
            currentChapterIndex = chapters.count - 1
        }
    }
    
    // Método para obtener el capítulo actual
    func getCurrentChapter() -> AudioChapter? {
        guard !chapters.isEmpty, currentChapterIndex < chapters.count else {
            return nil
        }
        return chapters[currentChapterIndex]
    }
    
    // Método para actualizar la información del capítulo actual y su progreso
    private func updateCurrentChapterInfo() {
        // Actualizar el índice del capítulo actual
        updateCurrentChapterIndex()
        
        // Calcular el progreso dentro del capítulo actual
        if let currentChapter = getCurrentChapter() {
            let timeInChapter = currentTime - currentChapter.startTime
            currentChapterProgress = min(1.0, max(0.0, timeInChapter / currentChapter.duration))
        } else {
            currentChapterProgress = 0
        }
    }
    
    // Restaurar el progreso guardado
    private func restoreSavedProgress() {
        // Verificar que tenemos una duración válida
        guard duration > 0 else { return }
        
        // Obtener el progreso guardado del libro
        let savedProgress = book.book.progress
        
        // Solo restaurar si hay un progreso significativo guardado
        if savedProgress > 0.01 {
            // Calcular la posición en segundos
            let timeToRestore = duration * savedProgress
            
            // Buscar el capítulo correspondiente
            if !chapters.isEmpty {
                for (index, chapter) in chapters.enumerated() {
                    let chapterEndTime = chapter.startTime + chapter.duration
                    if timeToRestore >= chapter.startTime && timeToRestore < chapterEndTime {
                        currentChapterIndex = index
                        break
                    }
                }
            }
            
            // Posicionar el reproductor en el tiempo guardado
            seek(to: timeToRestore)
            
            // Actualizar la UI para reflejar la posición restaurada
            self.currentTime = timeToRestore
            
            // Actualizar el progreso del capítulo
            updateCurrentChapterInfo()
        }
    }
}

struct AudioChapter: Identifiable {
    let id: Int
    let title: String
    let startTime: Double
    let duration: Double
    
    var formattedStartTime: String {
        formatTime(seconds: startTime)
    }
    
    var formattedDuration: String {
        formatTime(seconds: duration)
    }
    
    private func formatTime(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// Vista de fondo adaptativa al tema
struct ThemeAdaptiveBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var useAmoledBackground: Bool
    
    // En lugar de estado, usaremos propiedades calculadas
    var body: some View {
        getBackground()
    }
    
    // Función para obtener el fondo basado en el tema actual
    private func getBackground() -> AnyView {
        if colorScheme == .dark {
            if useAmoledBackground {
                // Tema oscuro AMOLED - Negro puro
                return AnyView(Color.black)
            } else {
                // Tema oscuro regular - Gradiente oscuro elegante
                return AnyView(LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.15)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
        } else {
            // Tema claro - Gradiente que va de claro a más oscuro en la parte inferior
            return AnyView(LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.9, green: 0.95, blue: 1.0),
                    Color(red: 0.6, green: 0.7, blue: 0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
}

struct AudioPlayerView: View {
    let book: CompleteBook
    @StateObject private var viewModel: AudioPlayerViewModel
    @StateObject private var lifecycleObserver = AppLifecycleObserver()
    @Environment(\.presentationMode) var presentationMode
    
    // Estados para controlar el arrastre de la barra de progreso
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    // Estados para configuración
    @State private var showSettings = false
    @AppStorage("audioPlayer.useAmoledBackground") private var useAmoledBackground = false
    
    init(book: CompleteBook) {
        self.book = book
        _viewModel = StateObject(wrappedValue: AudioPlayerViewModel(book: book))
    }
    
    var body: some View {
        ZStack {
            // Fondo con gradiente adaptado al tema
            ThemeAdaptiveBackground(useAmoledBackground: useAmoledBackground)
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Barra superior con botones
                HStack {
                    Button(action: {
                        // Si estamos en la vista de capítulos, volver al reproductor
                        if viewModel.showChapters {
                            viewModel.showChapters = false
                        } else {
                            // Si estamos en el reproductor, guardar progreso y volver al home
                            if viewModel.duration > 0 {
                                let progress = viewModel.currentTime / viewModel.duration
                                viewModel.saveProgress(progress: progress)
                            }
                            
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color("AdaptiveText"))
                            .padding(12)
                            .background(Color("ButtonBackground").opacity(0.8))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Botón de configuración
                    Button(action: {
                        withAnimation(.spring()) {
                            showSettings = true
                        }
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(Color("AdaptiveText"))
                            .padding(12)
                            .background(Color("ButtonBackground").opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                if viewModel.showChapters {
                    ChaptersView(viewModel: viewModel)
                } else {
                    // Vista principal del reproductor
                    mainPlayerView
                }
            }
            
            // Panel de configuración
            if showSettings {
                AudioSettingsView(
                    isPresented: $showSettings,
                    useAmoledBackground: $useAmoledBackground
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .navigationBarHidden(true)
    }
    
    private var mainPlayerView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Portada del audiolibro
            coverArtView
                .padding(.bottom, 40)
            
            // Información del libro
            VStack(spacing: 8) {
                Text(book.displayTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color("AdaptiveText"))
                    .multilineTextAlignment(.center)
                
                Text(book.book.author)
                    .font(.system(size: 18))
                    .foregroundColor(Color("AdaptiveText").opacity(0.7))
            }
            .padding(.horizontal)
            
            // Capítulo actual
            if !viewModel.chapters.isEmpty {
                Text(viewModel.chapters[viewModel.currentChapterIndex].title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("AdaptiveText").opacity(0.6))
                    .padding(.top, 5)
            }
            
            Spacer()
            
            // Barra de progreso
            progressBarView
                .padding(.horizontal)
            
            // Controles de reproducción
            controlsView
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
    }
    
    private var coverArtView: some View {
        ZStack {
            // Fondo adaptativo para evitar transparencias no deseadas
            Rectangle()
                .fill(Color("CoverBackground"))
                .frame(width: 260, height: 260)
                .cornerRadius(14)
            
            if let image = book.getCoverImage() {
                // Usar una vista de imagen estática que no se recargue con cada interacción
                StableCoverImageView(image: image)
                    .frame(width: 250, height: 250)
                    .cornerRadius(12)
                    .shadow(radius: 10)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 250, height: 250)
                    .overlay(
                        Image(systemName: "headphones.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(50)
                            .foregroundColor(Color("AdaptiveText").opacity(0.7))
                    )
                    .shadow(radius: 10)
            }
        }
    }
    
    // Vista especial para manejar la imagen de portada con mejor rendimiento
    struct StableCoverImageView: View {
        let image: UIImage
        
        // Usar un estado para almacenar la imagen procesada y evitar recreaciones
        @State private var processedImage: Image?
        
        var body: some View {
            ZStack {
                if let processedImage = processedImage {
                    // Usar la imagen procesada si está disponible
                    processedImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .drawingGroup() // Usar Metal para renderizar la imagen
                } else {
                    // Mostrar un placeholder mientras se procesa la imagen
                    Color.black.opacity(0.2)
                        .onAppear {
                            // Procesar la imagen una sola vez al aparecer la vista
                            DispatchQueue.global(qos: .userInitiated).async {
                                // Crear una nueva imagen con renderizado de alta calidad
                                let renderer = UIGraphicsImageRenderer(size: image.size)
                                let processedUIImage = renderer.image { context in
                                    // Dibujar con alta calidad
                                    context.cgContext.interpolationQuality = .high
                                    image.draw(in: CGRect(origin: .zero, size: image.size))
                                }
                                
                                // Actualizar el estado en el hilo principal
                                DispatchQueue.main.async {
                                    self.processedImage = Image(uiImage: processedUIImage)
                                }
                            }
                        }
                }
            }
            .id("stableCoverImage")
        }
    }
    
    private var progressBarView: some View {
        VStack(spacing: 10) {
            
            // Barra de progreso
            ZStack(alignment: .leading) {
                // Fondo de la barra
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color("ControlButtonColor").opacity(0.2))
                    .frame(height: 6)
                
                // Progreso (ahora por capítulo)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color("ControlButtonColor"))
                    .frame(width: max(0, min(UIScreen.main.bounds.width - 40, (UIScreen.main.bounds.width - 40) * CGFloat(isDragging ? dragProgress : viewModel.currentChapterProgress))), height: 6)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let width = UIScreen.main.bounds.width - 40
                        let percentage = min(max(0, value.location.x / width), 1)
                        
                        // Actualizar solo el progreso visual durante el arrastre
                        isDragging = true
                        dragProgress = Double(percentage)
                        
                        // Proporcionar feedback háptico sutil
                        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                        feedbackGenerator.prepare()
                        
                        // Discretizar el feedback para evitar vibraciones continuas
                        let discreteProgress = Int(percentage * 20)
                        if discreteProgress % 2 == 0 {
                            feedbackGenerator.impactOccurred(intensity: 0.3)
                        }
                    }
                    .onEnded { value in
                        let width = UIScreen.main.bounds.width - 40
                        let percentage = min(max(0, value.location.x / width), 1)
                        
                        // Aplicar el cambio real al finalizar el arrastre
                        if let currentChapter = viewModel.getCurrentChapter() {
                            let chapterStartTime = currentChapter.startTime
                            let chapterDuration = currentChapter.duration
                            let seekTime = chapterStartTime + (chapterDuration * Double(percentage))
                            viewModel.seek(to: seekTime)
                        }
                        
                        // Restablecer el estado de arrastre
                        isDragging = false
                    }
            )
            
            // Tiempo actual y duración del capítulo
            HStack {
                if let currentChapter = viewModel.getCurrentChapter() {
                    // Tiempo transcurrido dentro del capítulo
                    let timeInChapter = viewModel.currentTime - currentChapter.startTime
                    Text(formatTime(seconds: timeInChapter))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("ControlButtonColor").opacity(0.8))
                    
                    Spacer()
                    
                    // Tiempo restante del capítulo
                    Text("-\(formatTime(seconds: max(0, currentChapter.duration - timeInChapter)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("ControlButtonColor").opacity(0.8))
                } else {
                    Text(formatTime(seconds: viewModel.currentTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("ControlButtonColor").opacity(0.8))
                    
                    Spacer()
                    
                    Text("-\(formatTime(seconds: max(0, viewModel.duration - viewModel.currentTime)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("ControlButtonColor").opacity(0.8))
                }
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 20) {
            // Controles de navegación entre capítulos
            HStack(spacing: 40) {
                // Botón de capítulo anterior
                Button(action: {
                    viewModel.previousChapter()
                }) {
                    Image(systemName: "chevron.backward.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundColor(Color("ControlButtonColor").opacity(0.8))
                }
                .disabled(viewModel.currentChapterIndex <= 0 || viewModel.chapters.isEmpty)
                .opacity(viewModel.currentChapterIndex <= 0 || viewModel.chapters.isEmpty ? 0.4 : 1)
                
                Spacer()
                
                // Botón de capítulo siguiente
                Button(action: {
                    viewModel.nextChapter()
                }) {
                    Image(systemName: "chevron.forward.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundColor(Color("ControlButtonColor").opacity(0.8))
                }
                .disabled(viewModel.currentChapterIndex >= viewModel.chapters.count - 1 || viewModel.chapters.isEmpty)
                .opacity(viewModel.currentChapterIndex >= viewModel.chapters.count - 1 || viewModel.chapters.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 30)
            
            // Controles principales
            HStack(spacing: 30) {
                // Retroceder 15 segundos
                Button(action: {
                    viewModel.skipBackward()
                }) {
                    Image(systemName: "gobackward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color("ControlButtonColor"))
                }
                
                // Reproducir/Pausar
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .foregroundColor(Color("ControlButtonColor"))
                }
                
                // Avanzar 15 segundos
                Button(action: {
                    viewModel.skipForward()
                }) {
                    Image(systemName: "goforward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color("ControlButtonColor"))
                }
            }
            
            // Controles secundarios
            HStack(spacing: 20) {
                // Control de velocidad - Usando Menu en lugar de ActionSheet
                Menu {
                    Button("0.75x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(0.75) 
                        }
                    }
                    Button("0.9x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(0.9) 
                        }
                    }
                    Button("1.0x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(1.0) 
                        }
                    }
                    Button("1.1x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(1.1) 
                        }
                    }
                    Button("1.2x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(1.2) 
                        }
                    }
                    Button("1.3x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(1.3) 
                        }
                    }
                    Button("1.4x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(1.4) 
                        }
                    }
                    Button("1.5x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(1.5) 
                        }
                    }
                    Button("1.75x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(1.75) 
                        }
                    }
                    Button("2.0x") { 
                        DispatchQueue.main.async {
                            viewModel.setPlaybackRate(2.0) 
                        }
                    }
                } label: {
                    // Etiqueta del menú
                    Text("\(String(format: "%.2f", viewModel.playbackRate))x")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("AdaptiveText"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("ButtonBackground").opacity(0.6))
                        .cornerRadius(12)
                }
                
                Spacer()
                
                // Botón de capítulos
                Button(action: {
                    viewModel.showChapters.toggle()
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundColor(Color("AdaptiveText"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("ButtonBackground").opacity(0.6))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    private func formatTime(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// Vista para la configuración del reproductor de audio
struct AudioSettingsView: View {
    @Binding var isPresented: Bool
    @Binding var useAmoledBackground: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Fondo semitransparente
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // Panel de configuración
            VStack(spacing: 20) {
                // Encabezado
                HStack {
                    Text("Ajustes")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                
                // Sección de apariencia
                VStack(alignment: .leading, spacing: 15) {
                    Text("Apariencia")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    Toggle(isOn: $useAmoledBackground) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fondo AMOLED")
                                .font(.system(size: 16))
                            
                            Text("Utiliza negro puro para pantallas OLED")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .disabled(colorScheme == .light)
                    .opacity(colorScheme == .light ? 0.5 : 1.0)
                }
                
                Spacer()
                
                // Nota informativa
                if colorScheme == .light {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("El fondo AMOLED solo está disponible en modo oscuro")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                }
            }
            .padding()
            .frame(width: min(UIScreen.main.bounds.width * 0.9, 360))
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding()
        }
        .zIndex(10)
    }
}
