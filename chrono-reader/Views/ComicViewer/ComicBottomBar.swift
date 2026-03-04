import SwiftUI

struct ComicBottomBar: View {
    @ObservedObject var model: ComicViewerModel

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                gradient: Gradient(colors: [
                    model.useWhiteBackground ? Color.white.opacity(0) : Color.black.opacity(0),
                    model.useWhiteBackground ? Color.white.opacity(0.7) : Color.black.opacity(0.7)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 5) {
                Spacer()

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(model.useWhiteBackground ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
                            .frame(height: 3)
                            .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 1, x: 0, y: 0)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        model.isDraggingProgress = true
                                        let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                        let newPage = Int(round(percentage * CGFloat(model.totalPages - 1)))
                                        model.targetPage = max(0, min(newPage, model.totalPages - 1))
                                        if model.lastDraggedPage != model.targetPage {
                                            let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
                                            feedbackGenerator.prepare()
                                            feedbackGenerator.impactOccurred()
                                            model.lastDraggedPage = model.targetPage
                                        }
                                    }
                                    .onEnded { _ in
                                        if let targetPage = model.targetPage {
                                            model.currentPage = targetPage
                                            model.targetPage = nil
                                        }
                                        model.lastDraggedPage = nil
                                        model.isDraggingProgress = false
                                    }
                            )

                        let currentPageIndex = CGFloat(model.targetPage != nil ? model.targetPage! : model.currentPage)
                        let maxPageIndex = CGFloat(max(1, model.totalPages - 1))
                        let progressRatio = currentPageIndex / maxPageIndex
                        let progressWidth = geometry.size.width * progressRatio

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(model.useWhiteBackground ? Color.black : Color.white)
                            .frame(width: progressWidth, height: 3)
                            .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 1, x: 0, y: 0)

                        ZStack {
                            Rectangle()
                                .fill(model.useWhiteBackground ? Color.black.opacity(0.001) : Color.white.opacity(0.001))
                                .frame(width: 44, height: 44)

                            VStack(spacing: 0) {
                                Capsule()
                                    .fill(model.useWhiteBackground ? Color.black : Color.white)
                                    .frame(width: 6, height: 10)
                                    .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.6) : Color.black.opacity(0.6), radius: 1, x: 0, y: 0)

                                Rectangle()
                                    .fill(model.useWhiteBackground ? Color.black : Color.white)
                                    .frame(width: 2, height: 6)
                                    .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.6) : Color.black.opacity(0.6), radius: 1, x: 0, y: 0)
                            }
                            .offset(y: -8)
                        }
                        .position(x: max(7, min(geometry.size.width - 7, progressWidth)), y: 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    model.isDraggingProgress = true
                                    let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                    let newPage = Int(round(percentage * CGFloat(model.totalPages - 1)))
                                    model.targetPage = max(0, min(newPage, model.totalPages - 1))
                                    if model.lastDraggedPage != model.targetPage {
                                        let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
                                        feedbackGenerator.prepare()
                                        feedbackGenerator.impactOccurred()
                                        model.lastDraggedPage = model.targetPage
                                    }
                                }
                                .onEnded { _ in
                                    if let targetPage = model.targetPage {
                                        model.currentPage = targetPage
                                        model.targetPage = nil
                                    }
                                    model.lastDraggedPage = nil
                                    model.isDraggingProgress = false
                                }
                        )
                    }
                    .frame(height: 16)
                }
                .frame(height: 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 5)

                if model.showThumbnails && !model.pages.isEmpty {
                    ThumbnailsPreview(
                        pages: model.pages,
                        currentPage: model.targetPage ?? model.currentPage,
                        totalPages: model.totalPages,
                        useWhiteBackground: model.useWhiteBackground,
                        onPageSelected: { page in
                            model.currentPage = page
                        }
                    )
                    .padding(.bottom, 10)
                }

                HStack {
                    Spacer()
                    Text(model.targetPage != nil ? "\(model.targetPage! + 1) de \(model.totalPages)" : "\(model.currentPage + 1) de \(model.totalPages)")
                        .font(.caption)
                        .foregroundColor(model.useWhiteBackground ? .black : .white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                        .cornerRadius(10)
                    Spacer()
                }
                .padding(.bottom, 5)

                HStack(spacing: 140) {
                    Button(action: { model.previousPage() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(model.useWhiteBackground ? .black : .white)
                            .padding(12)
                            .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(model.currentPage <= 0)
                    .opacity(model.currentPage <= 0 ? 0.5 : 1.0)

                    Button(action: { model.nextPage() }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(model.useWhiteBackground ? .black : .white)
                            .padding(12)
                            .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(model.currentPage >= model.totalPages - 1)
                    .opacity(model.currentPage >= model.totalPages - 1 ? 0.5 : 1.0)
                }
                .padding(.bottom, 20)

                if let series = model.book.book.series {
                    HStack {
                        Spacer()
                        Text(series)
                            .font(.footnote)
                            .foregroundColor(model.useWhiteBackground ? .black : .white)
                            .shadow(color: model.useWhiteBackground ? .clear : .black, radius: 2, x: 0, y: 1)
                        if let issue = model.book.book.issueNumber {
                            Text("#\(issue)")
                                .font(.footnote)
                                .foregroundColor(model.useWhiteBackground ? .black : .white)
                                .shadow(color: model.useWhiteBackground ? .clear : .black, radius: 2, x: 0, y: 1)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 5)
                }
            }
        }
    }
}
