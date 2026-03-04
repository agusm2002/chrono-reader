import SwiftUI
import UIKit

struct ComicSettingsView: View {
    @Binding var readingMode: ReadingMode
    @Binding var doublePaged: Bool
    @Binding var isolateFirstPage: Bool
    @Binding var useWhiteBackground: Bool
    @Binding var showThumbnails: Bool
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .background(Color.black.opacity(0.2))
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }

            VStack(spacing: 0) {
                HStack {
                    Text("Configuración")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 24)

                Divider()
                    .background(Color.secondary.opacity(0.2))
                    .padding(.horizontal, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MODO DE LECTURA")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                ForEach(ReadingMode.allCases) { mode in
                                    ReadingModeRow(
                                        mode: mode,
                                        isSelected: readingMode == mode,
                                        action: {
                                            withAnimation {
                                                readingMode = mode
                                                if mode.isVertical && doublePaged {
                                                    DispatchQueue.main.async { doublePaged = false }
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("OPCIONES")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)

                            VStack(spacing: 16) {
                                if !readingMode.isVertical {
                                    SettingsToggleRow(
                                        title: "Páginas dobles",
                                        subtitle: "Muestra dos páginas simultáneamente",
                                        iconName: "book.pages.fill",
                                        isEnabled: true,
                                        isActive: doublePaged,
                                        binding: $doublePaged
                                    )

                                    if doublePaged {
                                        SettingsToggleRow(
                                            title: "Combinar portada",
                                            subtitle: "Mostrar la primera página junto con otra (cuando está activado) o por separado (cuando está desactivado)",
                                            iconName: "doc.viewfinder",
                                            isEnabled: doublePaged,
                                            isActive: isolateFirstPage,
                                            binding: Binding(
                                                get: { isolateFirstPage },
                                                set: { newValue in
                                                    isolateFirstPage = newValue
                                                    DispatchQueue.main.async {
                                                        NotificationCenter.default.post(
                                                            name: Notification.Name("ForceUpdateDoublePages"),
                                                            object: nil,
                                                            userInfo: ["isolateFirstPage": newValue]
                                                        )
                                                    }
                                                }
                                            )
                                        )
                                        .padding(.leading, 24)
                                    }
                                }

                                SettingsToggleRow(
                                    title: "Fondo claro",
                                    subtitle: "Cambia entre fondos claro y oscuro para una lectura más cómoda",
                                    iconName: useWhiteBackground ? "sun.max.fill" : "moon.fill",
                                    isEnabled: true,
                                    isActive: useWhiteBackground,
                                    binding: $useWhiteBackground
                                )

                                SettingsToggleRow(
                                    title: "Vista previa de miniaturas",
                                    subtitle: "Muestra miniaturas de las páginas encima de la barra de progreso",
                                    iconName: "photo.on.rectangle",
                                    isEnabled: true,
                                    isActive: showThumbnails,
                                    binding: $showThumbnails
                                )
                            }
                            .padding(.horizontal, 24)
                        }

                        VStack {
                            Text("Chrono Reader")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top)
                            Text("v1.0")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.85, 380))
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, UIScreen.main.bounds.height < 700 ? 20 : 40)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
        }
        .zIndex(10)
    }
}

// Subcomponentes: ReadingModeRow & SettingsToggleRow
struct ReadingModeRow: View {
    let mode: ReadingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(backgroundColor)
        .overlay(borderOverlay)
        .onTapGesture { action() }
    }

    private var iconName: String {
        switch mode {
        case .PAGED_COMIC: return "arrow.right"
        case .PAGED_MANGA: return "arrow.left"
        case .VERTICAL: return "arrow.down"
        }
    }

    private var description: String {
        switch mode {
        case .PAGED_COMIC: return "Avanza páginas de izquierda a derecha (estilo occidental)"
        case .PAGED_MANGA: return "Avanza páginas de derecha a izquierda (estilo japonés)"
        case .VERTICAL: return "Desplazamiento vertical continuo (estilo webtoon)"
        }
    }

    private var backgroundColor: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    var iconColor: Color? = nil
    let isEnabled: Bool
    let isActive: Bool
    @Binding var binding: Bool

    var body: some View {
        HStack {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor != nil ? iconColor : (isActive ? .accentColor : .primary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isEnabled ? .primary : .secondary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer()

            Toggle("", isOn: $binding)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.5)
                .frame(width: 55)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.05)))
    }
}
