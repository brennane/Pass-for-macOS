//Copyright 2018 Artur Sterz
//
//Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
//1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//
//2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//
//3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import SafariServices
import os.log

let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Extension")

class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:330, height:22)
        return shared
    }()
    
    func popoverViewController() -> SafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var searchResultsTable: NSTableView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    @IBOutlet weak var widthConstraint: NSLayoutConstraint!
    @IBOutlet weak var startPassformacosButton: NSButton!
    
    var resultsPasswords: [String]?
    
    @IBAction func startPassformacos(_ sender: Any) {
        let bundlePath = NSWorkspace.shared.fullPath(forApplication: "Pass for macOS.app")
        NSWorkspace.shared.launchApplication(bundlePath!)
    }
    
    @IBAction func searchPassword(_ sender: NSSearchField) {
        // This function is used, when the searchfield is used.
        resultsPasswords = sharedClientHandler.searchPasswords(searchString: sender.stringValue)
        popoverViewController().showSearchResults(fromSearchField: true)
    }
    
    func fillPasswordFromSelection(pass: String? = nil) {
        let credentials: [String]
        let password: String
        var login: String = ""
        var shortcut: String = "true"
        var message: String = ""
        
        var item = pass
        if pass == nil {
            if popoverViewController().searchResultsTable.selectedRow < 0 {
                os_log(.error, log: logger, "%s", "Something went wrong. There are not results in the results table")
                return
            }
            item = resultsPasswords?[popoverViewController().searchResultsTable.selectedRow]
            shortcut = ""
        }
        
        if item == "No matching password found." || item == "Pass for macOS is not running." {
            password = ""
            login = ""
            message = item!
        } else {
            credentials = (sharedClientHandler.getPassword(passwordFile: item!)?.components(separatedBy: "\n"))!
            password = credentials[0]

            if credentials.count > 1 {
                if credentials[1].count > 0 {
                    let loginDirty = credentials[1].drop(while: {$0 != ":"})
                    login = String(loginDirty.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        SFSafariApplication.getActiveWindow { (window) in
            window!.getActiveTab { (activeTab) in
                activeTab!.getActivePage { (activePage) in
                    activePage!.dispatchMessageToScript(withName: "credentials", userInfo: ["password": password, "login": login, "shortcut": shortcut, "message": message])
                }
            }
        }
        if pass == nil {
            popoverViewController().dismiss(SafariExtensionViewController.shared)
        }
    }
    
    func showSearchResults(fromSearchField: Bool = false) {
        // Show the results in the table
        startPassformacosButton.isHidden = true
        
        // Set the height of the popover.
        // Limit the size to 10 elements
        var height = resultsPasswords!.count < 10 ? (resultsPasswords!.count * 20) : (10 * 20)

        // Set the width of the popover, so that all results fit.
        // It should be at least 330 wide.
        var width = (resultsPasswords!.max(by: {$1.count > $0.count})?.count)! * 7
        if width < 330 {
            width = 330
        }
        
        // Do not set the focus, if app is not running, no passwords where found or the shortcut was used.
        var fail: Bool = false;
        if resultsPasswords!.count == 1 {
            if resultsPasswords![0] == "Pass for macOS is not running." {
                startPassformacosButton.isHidden = false
                height = height + 22
                fail = true
            }
            if resultsPasswords![0] == "No matching password found." {
                fail = true
            }
        }
        
        // Animate the size of the popover
        popoverViewController().heightConstraint.animator().constant = CGFloat(height)
        popoverViewController().widthConstraint.animator().constant = CGFloat(width)
        
        // show the table
        popoverViewController().searchResultsTable.isHidden = false
        popoverViewController().searchResultsTable.reloadData()
        
        if fail {
            return
        }
        
        if !fromSearchField {
            popoverViewController().searchResultsTable.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: true)
            popoverViewController().view.window?.makeFirstResponder(popoverViewController().searchResultsTable)
        }
    }
    
    override func viewDidLoad() {
        popoverViewController().searchResultsTable.delegate = popoverViewController()
        popoverViewController().searchResultsTable.dataSource = popoverViewController()
        popoverViewController().searchResultsTable.target = self
        popoverViewController().searchResultsTable.doubleAction = #selector(tableViewDoubleClick(_:))
        popoverViewController().searchResultsTable.isHidden = true
    }
    
    func resetPopover() {
        popoverViewController().heightConstraint.animator().constant = CGFloat(0)
        popoverViewController().widthConstraint.animator().constant = CGFloat(330)
        popoverViewController().searchResultsTable.isHidden = true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            // If the enter key was pressed, the selected password will be used for auto fill
            fillPasswordFromSelection()
        }
    }
    
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        fillPasswordFromSelection()
    }

}

extension SafariExtensionViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return resultsPasswords?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return (resultsPasswords!)[row]
    }
}
