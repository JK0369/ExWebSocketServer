//
//  AppDelegate.swift
//  ExWebSocketServer
//
//  Created by 김종권 on 2022/08/29.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

  


  func applicationDidFinishLaunching(_ aNotification: Notification) {
    guard let server = try? WebSocketServer(port: 8080) else { return }
    server.startServer()
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }


}

