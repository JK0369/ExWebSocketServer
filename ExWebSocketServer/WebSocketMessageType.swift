//
//  WebSocketMessageType.swift
//  ExWebSocket
//
//  Created by 김종권 on 2022/08/27.
//

import Foundation

enum WebSocketMessageType: String {
  case connected = "connect.connected"
  case failed =  "connect.failed"
  case tradingQuote = "trading.quote"
  case connectionAck = "connect.ack"
}

struct SocketQuoteResponse: Codable {
  let t: String
  let body: QuoteResponseBody
}

struct QuoteResponseBody: Codable {
  let securityId: String
  let currentPrice: String
}

struct ConnectionAck: Codable {
  let t: String
  let connectionId: Int
}
