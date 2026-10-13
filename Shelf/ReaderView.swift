import SwiftUI
import ShelfCore

struct ReaderView: View {
    let pages: [URL]
    let albumID: String
    @State private var page = 0
    @State private var spread = false
    @State private var controls = false
    @State private var reload = 0
    @FocusState private var focus: Focus?
    @Environment(\.dismiss) private var dismiss
    private enum Focus: Hashable { case canvas, resume }
    private var referer: String { "https://www.wnacg.com/photos-slide-aid-\(albumID).html" }
    private var indices: [Int] { ReaderLayout.visibleIndices(page: page, count: pages.count, spread: spread) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                HStack(spacing: 6) {
                    ForEach(indices, id: \.self) { index in
                        RemoteImage(url: pages[index], referer: referer).id("\(index)-\(reload)")
                            .frame(width: spread ? (geometry.size.width - 6) / 2 : geometry.size.width, height: geometry.size.height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .focusable()
                .focused($focus, equals: .canvas)
                .focusEffectDisabled()
                .onTapGesture { controls = true; focus = .resume }
                .onMoveCommand { direction in
                    if direction == .left { turn(forward: true) }
                    if direction == .right { turn(forward: false) }
                    if direction == .down || direction == .up { controls = true; focus = .resume }
                }
                VStack(spacing: 22) {
                    Text(pageLabel).font(.callout.monospacedDigit())
                        .padding(.horizontal, 18).padding(.vertical, 8).background(.black.opacity(0.7), in: Capsule())
                    if controls {
                        HStack(spacing: 28) {
                            Button("下一页 ←") { turn(forward: true) }.disabled(page + (spread ? 2 : 1) >= pages.count)
                            Button("上一页 →") { turn(forward: false) }.disabled(page == 0)
                            Button(spread ? "切换单页" : "双页并排") { spread.toggle() }
                            Button("重试图片") { reload += 1 }
                            Button("继续阅读") { controls = false; focus = .canvas }.focused($focus, equals: .resume)
                            Button("关闭") { dismiss() }
                        }.padding(30).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    }
                }.padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
        .onAppear { focus = .canvas }
        .onExitCommand { if controls { controls = false; focus = .canvas } else { dismiss() } }
        .onPlayPauseCommand { controls.toggle(); focus = controls ? .resume : .canvas }
        .task(id: page) {
            // A bounded memory cache; prefetch the next five pages, no disk/offline storage.
            let end = min(pages.count, page + 6)
            for index in (page + 1)..<end {
                if Task.isCancelled { return }
                _ = try? await ImageStore.shared.image(pages[index], referer: referer)
            }
        }
    }
    private var pageLabel: String {
        let last = min(pages.count, page + (spread ? 2 : 1))
        return spread && last > page + 1 ? "\(page + 1)–\(last) / \(pages.count)" : "\(page + 1) / \(pages.count)"
    }
    private func turn(forward: Bool) {
        page = ReaderLayout.advanced(page: page, count: pages.count, spread: spread, forward: forward)
    }
}
