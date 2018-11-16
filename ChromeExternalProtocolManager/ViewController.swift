//
//  ViewController.swift
//  ChromeExternalProtocolManager
//
//  Created by Ligeng on 2018/11/15.
//  Copyright © 2018 Ligeng. All rights reserved.
//

import Cocoa
import SwiftyJSON

class ViewController: NSViewController {
    
    @IBOutlet weak var tableView: NSTableView!
    var protocolArr: [String] = []
    let prefPath = FileManager.default.homeDirectoryForCurrentUser.path
        + "/Library/Application Support/Google/Chrome/Default/Preferences"
    
    func readPref() -> JSON? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: prefPath), options: .mappedIfSafe)
            return JSON(data)
        } catch let error as NSError {
            print("error happened: \(error)")
        }
        return nil
    }

    func loadData() {
        var prefJSON = readPref()
        let excludedSchemes = prefJSON!["protocol_handler"]["excluded_schemes"]
        
        protocolArr.removeAll()
        for (key, value):(String, JSON) in excludedSchemes {
            if (!value.bool!) {
                protocolArr.append(key)
            }
        }
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self

        // Do any additional setup after loading the view.
        loadData()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.title = NSLocalizedString("Chrome External Protocal Manager", comment: "")
        self.view.window?.styleMask.remove(.resizable)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func refreshList(_ sender: Any) {
        self.loadData()
    }
    
    @IBAction func removeProtocol(_ sender: NSButton) {
        let answer = confirm(question: NSLocalizedString("Chrome will be closed during the process", comment: ""),
                                text: NSLocalizedString("Make sure you don't have unsaved drafts in chrome", comment: ""))
        if answer {
            let pipe = Pipe()
            
            let task = Process()
            task.launchPath = "/usr/bin/killall"
            task.arguments = ["Google Chrome"]
            task.standardOutput = pipe
            task.standardError = pipe
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
 
            let rowIdx = tableView.row(for: sender)
            Timer.scheduledTimer(timeInterval: 5,
                                 target: self,
                                 selector: (#selector(ViewController.updatePref)),
                                 userInfo: rowIdx,
                                 repeats: false)
        }
    }
    
    @objc func updatePref(timer: Timer) {
        do {
            var prefJson = readPref()
            prefJson!["protocol_handler"]["excluded_schemes"][protocolArr[timer.userInfo as! Int]] = true
            try prefJson?.rawString()!.write(to: URL(fileURLWithPath: prefPath), atomically: false, encoding: .utf8)
            loadData()
            if !NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Google Chrome.app")) {
                let alert = NSAlert()
                alert.messageText = "Failed to relauch Chrome. Please do it manually."
                alert.alertStyle = .informational
                alert.runModal()
            }
        } catch let error as NSError {
            print("error happened: \(error)")
        }
    }
    
    func confirm(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        return alert.runModal() == .alertFirstButtonReturn
    }

    
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return protocolArr.count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as? NSTableCellView
        if tableColumn?.identifier.rawValue == "protocol" {
            let textfield = cell?.viewWithTag(1) as! NSTextField
            textfield.stringValue = protocolArr[row]
        }
        return cell
    }
}

