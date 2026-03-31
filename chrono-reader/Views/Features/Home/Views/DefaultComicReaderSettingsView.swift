import SwiftUI

struct DefaultComicReaderSettingsView: View {
    @AppStorage(ComicReaderDefaultsStorage.readingModeKey)
    private var defaultReadingModeRawValue: String = ComicReaderSettings.default.readingModeRawValue

    @AppStorage(ComicReaderDefaultsStorage.doublePagedKey)
    private var defaultDoublePaged: Bool = ComicReaderSettings.default.doublePaged

    @AppStorage(ComicReaderDefaultsStorage.isolateFirstPageKey)
    private var defaultIsolateFirstPage: Bool = ComicReaderSettings.default.isolateFirstPage

    @AppStorage(ComicReaderDefaultsStorage.useWhiteBackgroundKey)
    private var defaultUseWhiteBackground: Bool = ComicReaderSettings.default.useWhiteBackground

    @AppStorage(ComicReaderDefaultsStorage.showThumbnailsKey)
    private var defaultShowThumbnails: Bool = ComicReaderSettings.default.showThumbnails

    private var selectedReadingMode: ReadingMode {
        ReadingMode(rawValue: defaultReadingModeRawValue) ?? .PAGED_COMIC
    }

    var body: some View {
        List {
            Section {
                Text("Estas opciones se aplican solo cuando abres un comic nuevo. Si luego cambias la configuracion dentro de un comic, ese comic conserva su propia configuracion.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("MODO DE LECTURA").textCase(.uppercase)) {
                ForEach(ReadingMode.allCases) { mode in
                    Button {
                        defaultReadingModeRawValue = mode.rawValue
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedReadingMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.appTheme())
                            }
                        }
                    }
                }
            }

            Section(header: Text("OPCIONES").textCase(.uppercase)) {
                if selectedReadingMode.isVertical {
                    HStack {
                        Text("Paginas dobles")
                        Spacer()
                        Text("No disponible en vertical")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Toggle("Paginas dobles", isOn: $defaultDoublePaged)

                    if defaultDoublePaged {
                        Toggle("Combinar portada", isOn: $defaultIsolateFirstPage)
                    }
                }

                Toggle("Fondo claro", isOn: $defaultUseWhiteBackground)
                Toggle("Vista previa de miniaturas", isOn: $defaultShowThumbnails)
            }
        }
        .navigationTitle("Lector de comics")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: defaultReadingModeRawValue) { newValue in
            let newMode = ReadingMode(rawValue: newValue) ?? .PAGED_COMIC
            if newMode.isVertical {
                defaultDoublePaged = false
            }
        }
    }
}

struct DefaultComicReaderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DefaultComicReaderSettingsView()
        }
    }
}
