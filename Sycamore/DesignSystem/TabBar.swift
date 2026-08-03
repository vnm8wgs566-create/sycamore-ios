//
//  TabBar.swift
//  Sycamore
//
//  The floating pill tab bar. Four items; the selected one grows into a white capsule carrying
//  icon *and* label, the rest stay icon-only.
//

import SwiftUI

// `AppTab` — its titles and its two symbol sets — is declared alongside the rest of the
// navigation vocabulary in `Store/AppStore.swift`.

// MARK: - Tab bar

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var tabs: [AppTab] = AppTab.allCases

    @Namespace private var capsuleNamespace

    init(selection: Binding<AppTab>, tabs: [AppTab] = AppTab.allCases) {
        self._selection = selection
        self.tabs = tabs
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                item(tab)
            }
        }
        .padding(6)
        .background(plate)
        .overlay(ring)
        .overlay(innerHighlight)
        .shadow(Shadows.tabBar)
    }

    // MARK: Items

    private func item(_ tab: AppTab) -> some View {
        let isSelected = tab == selection

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 7) {
                // `selectedSymbol` already names the outline glyph for the two symbols with no
                // filled variant (list.number, slider.horizontal.3), so the selected item just
                // stops being hollow rather than changing shape.
                Image(systemName: isSelected ? tab.selectedSymbol : tab.symbol)
                    .font(.system(size: 20, weight: .regular))

                if isSelected {
                    Text(tab.title)
                        .typeStyle(.tabLabel)
                }
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.tabInactive)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Theme.surface)
                        .shadow(Shadows.tabItem)
                        .matchedGeometryEffect(id: "selectedTab", in: capsuleNamespace)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: Plate

    /// `rgba(250,250,251,.82)` over a 30px blur with 180% saturation. `ultraThinMaterial`
    /// carries the blur and most of the saturation; the plate colour sits on top of it.
    private var plate: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(Capsule(style: .continuous).fill(Theme.tabBarPlate))
    }

    /// `0 0 0 .5px rgba(11,11,12,.07)`.
    private var ring: some View {
        Capsule(style: .continuous)
            .strokeBorder(Theme.ink.opacity(0.07), lineWidth: BorderWidth.ring)
    }

    /// `inset 0 1px 0 rgba(255,255,255,.95)` — a one-point lip along the top edge only, which
    /// is why the gradient runs to clear well before the bottom.
    private var innerHighlight: some View {
        Capsule(style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.95), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Placement

extension View {
    /// Floats the tab bar 22pt above the bottom safe area, over the receiver.
    ///
    /// The bar does not reserve layout space, so scrolling content underneath it needs
    /// `Spacing.tabBarClearance` of bottom padding to clear it.
    func floatingTabBar(selection: Binding<AppTab>, tabs: [AppTab] = AppTab.allCases) -> some View {
        overlay(alignment: .bottom) {
            FloatingTabBar(selection: selection, tabs: tabs)
                .padding(.bottom, Spacing.tabBarInset)
        }
    }
}

// MARK: - Previews

/// Hoisted to file scope on purpose. A `View` type declared *inside* a `#Preview`
/// closure that also returns it makes the compiler's symbol mangler recurse without
/// bound (the type's mangling names the closure, whose type names the type).
private struct TabBarPreviewHarness: View {
    @State private var selection: AppTab = .groups

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(selection.title)
                .typeStyle(.tabTitle, color: Theme.ink)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.grouped)
        .floatingTabBar(selection: $selection)
    }
}

#Preview("Tab bar") {
    TabBarPreviewHarness()
}

#Preview("Tab bar — every selection") {
    return VStack(spacing: 18) {
        ForEach(AppTab.allCases) { tab in
            FloatingTabBar(selection: .constant(tab))
        }
    }
    .padding(Spacing.section)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.grouped)
}
