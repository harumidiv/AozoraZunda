import SwiftUI

// 図書館・部屋・本棚で共通の RPG 風ウインドウと選択肢

extension View {
    /// 紺地に白枠の RPG 風ウインドウの見た目にする
    func gameWindowStyle() -> some View {
        font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.12, green: 0.14, blue: 0.28).opacity(0.92), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).inset(by: 2).stroke(.white, lineWidth: 2))
    }

    /// ウインドウの左上に話している人の名札を付ける
    func speakerName(_ name: String) -> some View {
        overlay(alignment: .topLeading) {
            Text(name)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(ShelfPalette.highlight)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color(red: 0.12, green: 0.14, blue: 0.28), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).inset(by: 1).stroke(.white, lineWidth: 2))
                .offset(x: 10, y: -14)
        }
    }
}

/// メッセージウインドウ内の選択肢
struct WindowChoice: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChoiceLabel(title: title)
        }
        .buttonStyle(.plain)
    }
}

struct ChoiceLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Text("▶")
                .font(.caption2)
                .foregroundStyle(ShelfPalette.highlight)
            Text(title)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// ウインドウに並べる選択肢。押すと処理を実行するか、画面を移動する
struct GameChoice {
    enum Kind {
        case action(() -> Void)
        case route(ShelfRoute)
        case book(CatalogBook)
        case reader(ReaderRoute)
    }

    let title: String
    let kind: Kind
    var isEnabled = true

    init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.kind = .action(action)
        self.isEnabled = isEnabled
    }

    init(_ title: String, route: ShelfRoute) {
        self.title = title
        self.kind = .route(route)
    }

    init(_ title: String, book: CatalogBook) {
        self.title = title
        self.kind = .book(book)
    }

    init(_ title: String, reader: ReaderRoute) {
        self.title = title
        self.kind = .reader(reader)
    }
}

struct GameChoiceView: View {
    let choice: GameChoice

    var body: some View {
        Group {
            switch choice.kind {
            case .action(let action):
                WindowChoice(title: choice.title, action: action)
            case .route(let route):
                NavigationLink(value: route) {
                    ChoiceLabel(title: choice.title)
                }
                .buttonStyle(.plain)
            case .book(let book):
                NavigationLink(value: book) {
                    ChoiceLabel(title: choice.title)
                }
                .buttonStyle(.plain)
            case .reader(let route):
                NavigationLink(value: route) {
                    ChoiceLabel(title: choice.title)
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(!choice.isEnabled)
        .opacity(choice.isEnabled ? 1 : 0.5)
    }
}
