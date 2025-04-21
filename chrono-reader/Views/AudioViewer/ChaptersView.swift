import SwiftUI

struct ChaptersView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Encabezado
            HStack {
                Text("Capítulos")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color("AdaptiveText"))
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 15)
            
            Divider()
                .padding(.horizontal)
            
            // Lista de capítulos
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.chapters) { chapter in
                        ChapterItemView(
                            chapter: chapter,
                            isCurrentChapter: viewModel.currentChapterIndex == chapter.id,
                            currentTime: viewModel.currentTime,
                            onTap: {
                                // Navegar al capítulo
                                viewModel.seek(to: chapter.startTime)
                            }
                        )
                        
                        Divider()
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color("BackgroundColor"))
    }
}

struct ChapterItemView: View {
    let chapter: AudioChapter
    let isCurrentChapter: Bool
    let currentTime: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Indicador visual
                Circle()
                    .fill(isCurrentChapter ? Color("ControlButtonColor") : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color("ControlButtonColor").opacity(0.4), lineWidth: 1)
                    )
                
                // Información del capítulo
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                        .font(.system(size: 16, weight: isCurrentChapter ? .semibold : .regular))
                        .foregroundColor(Color("AdaptiveText"))
                        .lineLimit(2)
                    
                    // Duración del capítulo
                    Text(formatTime(seconds: chapter.duration))
                        .font(.system(size: 12))
                        .foregroundColor(Color("AdaptiveText").opacity(0.7))
                }
                
                Spacer()
                
                // Indicador de progreso o botón de reproducción
                if isCurrentChapter {
                    // Cálculo del progreso en este capítulo
                    let progress = max(0, min(1, (currentTime - chapter.startTime) / chapter.duration))
                    
                    // Mostrar progreso circular si está en este capítulo
                    ZStack {
                        Circle()
                            .stroke(Color("ControlButtonColor").opacity(0.2), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(Color("ControlButtonColor"), lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color("ControlButtonColor"))
                    }
                } else {
                    // Botón simple de reproducción para otros capítulos
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color("AdaptiveText").opacity(0.7))
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(isCurrentChapter ? Color("ControlButtonColor").opacity(0.05) : Color.clear)
    }
    
    // Formatea la duración en formato hh:mm:ss o mm:ss
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

// Vista de previsualización para el diseño
struct ChaptersView_Previews: PreviewProvider {
    static var previews: some View {
        // Crear un modelo de prueba
        let dummyURL = URL(fileURLWithPath: "dummy/path.m4b")
        let previewBook = CompleteBook(
            id: UUID(),
            title: "Libro de prueba",
            author: "Autor",
            coverImage: "dummy_cover",
            type: .m4b,
            progress: 0,
            localURL: dummyURL
        )
        
        let viewModel = AudioPlayerViewModel(book: previewBook)
        // Simular algunos capítulos
        viewModel.chapters = [
            AudioChapter(id: 0, title: "Capítulo 1: Introducción", startTime: 0, duration: 900),
            AudioChapter(id: 1, title: "Capítulo 2: Desarrollo", startTime: 900, duration: 1200),
            AudioChapter(id: 2, title: "Capítulo 3: Conclusión", startTime: 2100, duration: 1500)
        ]
        
        return ChaptersView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
} 