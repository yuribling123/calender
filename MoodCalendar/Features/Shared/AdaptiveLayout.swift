import SwiftUI
import UIKit

/// Measures the actual iPad window or sheet. iPhone receives no new layout container.
struct AdaptivePage<Content: View>: View {
    @ViewBuilder var content: (CGSize?) -> Content

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            GeometryReader { geometry in
                content(geometry.size)
            }
        } else {
            content(nil)
        }
    }
}

extension View {
    @ViewBuilder
    func iPadFillPage() -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            self
        }
    }

    @ViewBuilder
    func iPadScrollable(background: Color = .clear) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            ScrollView { self }.background(background)
        } else {
            self
        }
    }

    /// Keep iPhone layout untouched. On iPad, accept narrower window proposals
    /// while capping wide content; apply inside a scroll view, after its padding.
    @ViewBuilder
    func iPadReadableWidth(_ maximumWidth: CGFloat = 600) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self
                .frame(maxWidth: maximumWidth)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }
}
