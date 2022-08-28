//
//  WebSocketServer.swift
//  ExWebSocket
//
//  Created by 김종권 on 2022/08/28.
//

import Foundation
import Network

enum WebSocketServerError: Error {
  case port
  case nwListener
}

final class WebSocketServer {
  var listener: NWListener
  var connectedClients = [NWConnection]()
  private var timer: Timer?
  
  /// listener 인스턴스 초기화
  /// 필수기능에 해당하는 옵션 활성화 (address, port재사용 / peer to peer 적용 / ping 자동 응답)
  init(port: UInt16) throws {
    let parameters = NWParameters(tls: nil)
    /// local address와 port재사용
    parameters.allowLocalEndpointReuse = true
    /// connection에 peer to peer 기술을 적용
    parameters.includePeerToPeer = true
    
    /// Connection을 위해서, ping 메시지를 보내면, 자동으로 pong을 보내게 하는 옵션
    let wsOptions = NWProtocolWebSocket.Options()
    wsOptions.autoReplyPing = true
    
    parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
    
    do {
      if let port = NWEndpoint.Port(rawValue: port) {
        self.listener = try NWListener(using: parameters, on: port)
      } else {
        throw WebSocketServerError.port
      }
    } catch {
      throw WebSocketServerError.nwListener
    }
  }
  
  deinit {
    self.timer?.invalidate()
  }
  
  /// 웹 서버 실행
  /// 1. 새로운 클라이언트 연결에 대해 대응할 수 있는 서버 리스너에 추가
  /// 2. 상태 변경에 관한 서버 업데이트
  /// 3. 서버가 주기적으로 연결된 클라이언트에 값을 보내도록 타이머 시작
  func startServer() {
    let serverQueue = DispatchQueue(label: "ServerQueue")

    /// 1. 새로운 클라이언트 연결에 대해 대응할 수 있는 서버 리스너에 추가
    self.listener.newConnectionHandler = { [weak self] newConnection in
      guard let ss = self else { return }
      
      print("New connection connecting")
      
      func receive() {
        /// 새로운 connection에 message 보내기
        newConnection.receiveMessage(completion: { [weak ss] data, context, isComplete, error in
          guard let ss = ss else { return }
          
          if let data = data, let context = context {
            print("Received a new message from client, data=\(data), context=\(context)")
            try? ss.handleMessageFromClient(data: data, context: context, stringVal: "", connection: newConnection)
            receive()
          }
        })
      }
      receive()
      
      newConnection.stateUpdateHandler = { [weak ss] state in
        guard let ss = ss else { return }
        
        switch state {
        case .ready:
          print("client ready")
          /// 클라이언트가 준비 완료되면 서버가 클라이언트에게 성공적으로 연결했다는 메시지 전송
          try? ss.sendMessageToClient(
            data: JSONEncoder().encode(["t": "connect.connected"]),
            client: newConnection
          )
        case let .failed(error):
          print("client connection failed \(error)")
        case let .waiting(error):
          print("waiting for long time \(error)")
        default:
          break
        }
      }
      
      newConnection.start(queue: serverQueue)
    }

    /// 2. 상태 변경에 관한 서버 업데이트
    self.listener.stateUpdateHandler = { state in
      print(state)
      switch state {
      case .ready:
        print("server ready")
      case let .failed(error):
        print("server failed with \(error)")
      default:
        break
      }
    }

    /// 3. 서버가 주기적으로 연결된 클라이언트에 값을 보내도록 타이머 시작
    self.listener.start(queue: serverQueue)
    self.startTimer()
  }
  
  private func handleMessageFromClient(
    data: Data,
    context: NWConnection.ContentContext,
    stringVal: String,
    connection: NWConnection
  ) throws {
    guard let message = try? JSONSerialization.jsonObject(
      with: data,
      options: []
    ) as? [String: Any] else {
      print("Invalid value from client")
      return
    }
    
    if message["subscribeTo"] != nil {
      print("Appending new connection to connectedClients")
      self.connectedClients.append(connection)
      self.sendAckToClient(connection: connection)
      guard let tradingQuoteData = self.getTradingQuoteData() else { return }
      try? self.sendMessageToClient(data: tradingQuoteData, client: connection)
    } else if message["unsubscribeFrom"] != nil {
      print("Removing old connection from connectedClients")
      if let id = message["unsubscribeFrom"] as? Int {
        let connection = self.connectedClients.remove(at: id)
        connection.cancel()
        print("Cancelled old connection with id \(id)")
      } else {
        print("Invalid payload")
      }
    }
  }
  
  private func sendAckToClient(connection: NWConnection) {
    let model = ConnectionAck(t: "connect.ack", connectionId: self.connectedClients.count - 1)
    guard let data = try? JSONEncoder().encode(model) else { return }
    try? self.sendMessageToClient(data: data, client: connection)
  }
  
  /// 5초마다 클라이언트들에게 message를 전송
  private func startTimer() {
    self.timer = Timer.scheduledTimer(
      withTimeInterval: 5,
      repeats: true,
      block: { [weak self] _ in
        guard let ss = self else { return }
        guard !ss.connectedClients.isEmpty else { return }
        ss.sendMessageToAllClients()
      })
  }
  
  private func sendMessageToAllClients() {
    guard let data = self.getTradingQuoteData() else {
      print("failed getTradingQuoteData")
      return
    }
    for (i, client) in self.connectedClients.enumerated() {
      print("Sending message to client number \(i)")
      try? self.sendMessageToClient(data: data, client: client)
    }
  }

  private func sendMessageToClient(data: Data, client: NWConnection) throws {
    let metaData = NWProtocolWebSocket.Metadata(opcode: .binary)
    let context = NWConnection.ContentContext(identifier: "context", metadata: [metaData])
    
    client.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
      if let error = error {
        print(error)
      } else {
        print("no - op")
      }
    }))
  }

  private func getTradingQuoteData() -> Data? {
    let data = SocketQuoteResponse(
      t: "trading.quote",
      body: QuoteResponseBody(
        securityId: "100",
        currentPrice: String(Int.random(in: 1...1000))
      )
    )
    return try? JSONEncoder().encode(data)
  }
}
