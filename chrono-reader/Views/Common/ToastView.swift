import SwiftUI

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    var style: ToastStyle = .success
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: style.iconName)
                        .foregroundColor(style.iconColor)
                        .font(.system(size: 18))
                    
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appTheme().opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: min(geometry.size.width - 80, 350))
                .padding(.bottom, 64)
            }
            .position(x: geometry.size.width/2, y: geometry.size.height - 32)
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: isShowing)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    self.isShowing = false
                }
            }
        }
    }
}

enum ToastStyle {
    case success
    case error
    case warning
    case info
    
    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success:
            return Color.appTheme()
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return Color.appTheme()
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let style: ToastStyle
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                ToastView(message: message, isShowing: $isShowing, style: style)
                    .zIndex(9999)
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, style: ToastStyle = .success) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, style: style))
    }
} 