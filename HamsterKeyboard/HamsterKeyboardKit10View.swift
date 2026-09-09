//
//  HamsterKeyboardKit10View.swift
//  HamsterKeyboard
//
//  Simplified Chinese pinyin UI built on KeyboardKit 10.9.4's public
//  KeyboardView. Rime remains responsible for composition and candidates.
//

import Combine
import HamsterKeyboardKit
import KeyboardKit
import SwiftUI

struct HamsterKeyboardKit10View: View {
  let services: KeyboardKit.KeyboardServices
  let state: KeyboardKit.KeyboardState
  let rimeContext: RimeContext

  @State private var inputText = ""
  @State private var candidates: [CandidateSuggestion] = []

  var body: some View {
    KeyboardKit.KeyboardView(
      layout: KeyboardKit.KeyboardLayout.standard(for: state.keyboardContext),
      services: services,
      buttonContent: { AnyView($0.view) },
      buttonView: { AnyView($0.view) },
      collapsedView: { AnyView($0.view) },
      emojiKeyboard: { AnyView($0.view) },
      toolbar: { params in
        AnyView(
          VStack(spacing: 0) {
            if !inputText.isEmpty || !candidates.isEmpty {
              HamsterCandidateToolbar(
                inputText: inputText,
                candidates: candidates,
                selectCandidate: { index in
                  Task { @MainActor in
                    rimeContext.selectCandidate(index: index)
                  }
                }
              )
              .frame(minHeight: 42, maxHeight: 52)
            }
            params.view
          }
        )
      }
    )
    .onReceive(rimeContext.userInputKeyPublished) { input in
      inputText = input
      candidates = input.isEmpty ? [] : rimeContext.suggestions
    }
    .onReceive(rimeContext.$suggestions) { suggestions in
      candidates = inputText.isEmpty ? [] : suggestions
    }
  }
}

private struct HamsterCandidateToolbar: View {
  let inputText: String
  let candidates: [CandidateSuggestion]
  let selectCandidate: (Int) -> Void

  var body: some View {
    HStack(spacing: 0) {
      Text(inputText)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 8)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
          ForEach(candidates) { candidate in
            Button {
              selectCandidate(candidate.index)
            } label: {
              HStack(spacing: 3) {
                Text(candidate.label)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text(candidate.title)
                  .font(.system(size: 18))
                  .foregroundStyle(.primary)
              }
              .padding(.horizontal, 7)
              .frame(minHeight: 32)
              .background(Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial)
  }
}
