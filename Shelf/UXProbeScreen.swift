#if DEBUG
import SwiftUI

/// Device-only probes for the optional native behaviors in UX specification section 14.
struct UXProbeScreen: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 70) {
                HStack(spacing: 100) {
                    Button { } label: { probeLabel("Card") }.buttonStyle(.card).accessibilityIdentifier("probe.card")
                    Button { } label: { probeLabel("Borderless") }.buttonStyle(.borderless).accessibilityIdentifier("probe.borderless")
                }
                NavigationLink("搜索范围探针") { SearchScopeProbe() }.accessibilityIdentifier("probe.search")
            }
        }
    }
    private func probeLabel(_ title: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.fill").resizable().scaledToFit().frame(width: 400, height: 225)
            Text(title).font(.system(size: 29))
        }
    }
}
private struct SearchScopeProbe: View {
    @State private var query = ""
    @State private var scope = "all"
    var body: some View {
        Text("搜索范围 API 探针").searchable(text: $query)
            .searchScopes($scope) { Text("全部").tag("all"); Text("分类").tag("category") }
    }
}
#endif
