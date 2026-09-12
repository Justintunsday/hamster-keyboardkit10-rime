import KeyboardKit
import PinyinCore
import SwiftUI

struct PinyinKeyboardView: View {
    let services: KeyboardServices
    @ObservedObject var session: KeyboardSession
    let onTransition: (PinyinTransition) -> Void
    let onModeChange: (PinyinMode) -> Void

    var body: some View {
        KeyboardView(
            services: services,
            buttonContent: { $0.view },
            buttonView: { $0.view },
            collapsedView: { $0.view },
            emojiKeyboard: { $0.view },
            toolbar: { _ in
                CandidateToolbar(
                    state: session.state,
                    onCandidate: { index in
                        onTransition(session.selectCandidate(at: index))
                    },
                    onModeChange: onModeChange
                )
            }
        )
    }
}

private struct CandidateToolbar: View {
    let state: CompositionState
    let onCandidate: (Int) -> Void
    let onModeChange: (PinyinMode) -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(PinyinMode.allCases, id: \.self) { mode in
                    Button(mode.title) {
                        onModeChange(mode)
                    }
                    .font(.system(size: 12, weight: mode == state.mode ? .bold : .regular))
                    .foregroundStyle(mode == state.mode ? Color.accentColor : .primary)
                    .frame(minWidth: 28, minHeight: 24)
                }

                Text(state.rawPinyin.isEmpty ? "拼音" : state.rawPinyin)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)

            if case .rimeFailed(let message) = state.runtimeStatus {
                Text("RIME 错误：\(message)")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if state.candidates.isEmpty {
                        Text(state.rawPinyin.isEmpty ? "候选" : "无候选")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(state.candidates.enumerated()), id: \.element.id) { index, candidate in
                            Button {
                                onCandidate(index)
                            } label: {
                                Text(candidate.text)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 8)
                                    .frame(minHeight: 28)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 34)
        }
        .padding(.vertical, 4)
        .background(.bar)
    }
}
