import SwiftUI

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    var style: ToastStyle = .success
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: style.iconName)
                    .foregroundColor(style.iconColor)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6).opacity(0.95))
            )
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom))
            .animation(.spring(), value: isShowing)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
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
                    .zIndex(100)
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, style: ToastStyle = .success) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, style: style))
    }
} 