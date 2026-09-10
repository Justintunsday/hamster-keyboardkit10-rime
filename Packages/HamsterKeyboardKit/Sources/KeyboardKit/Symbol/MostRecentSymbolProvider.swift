//
//  MostRecentSymbolProvider.swift
//  Hamster
//
//  Created by morse on 2023/5/30.
//

import Foundation
import HamsterKit
import OSLog

public class MostRecentSymbolProvider: FrequentSymbolProvider {
  public init(
    maxCount: Int = 30,
    defaults: UserDefaults? = nil
  ) {
    self.maxCount = maxCount
    if let defaults {
      self.defaults = defaults
    } else {
      do {
        self.defaults = try UserDefaults.hamster
      } catch {
        Logger.statistics.error("Most recent symbol App Group UserDefaults unavailable: \(error.localizedDescription)")
        self.defaults = nil
      }
    }
  }
  
  private let defaults: UserDefaults?
  private let maxCount: Int
  public static let key = "com.ihsiao.app.hamster.keyboard.mostRecentSymbolProvider.symbol"
  private static let common = ["，", "。", "？", "！"]
  
  var symbols: [Symbol] {
    symbolChars.map { Symbol(char: $0) }
  }
  
  var symbolChars: [String] {
    defaults?.stringArray(forKey: Self.key) ?? Self.common
  }
  
  func registerSymbol(_ symbol: Symbol) {
    var symbols = self.symbols.filter { $0.char != symbol.char }
    symbols.insert(symbol, at: 0)
    let result = Array(symbols.prefix(maxCount))
    let chars = result.map { $0.char }
    defaults?.set(chars, forKey: Self.key)
  }
  
  public func reset() {
    defaults?.set(Self.common, forKey: Self.key)
  }
}
