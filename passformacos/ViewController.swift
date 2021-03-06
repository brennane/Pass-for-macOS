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

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var searchResultsTable: NSTableView!
    @IBOutlet weak var widthConstraint: NSLayoutConstraint!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    
    var resultsPasswords: [String]?

    @IBAction func searchPassword(_ sender: NSSearchField) {
        if sender.stringValue.count == 0 {
            return
        }
        resultsPasswords = passwordstore!.passSearch(password: sender.stringValue)
        showSearchResults()
    }
    
    func showSearchResults() {
        // Do not set the focus, if app is not running, no passwords where found or the shortcut was used.
        if resultsPasswords!.isEmpty {
            resultsPasswords!.append("No matching password found.")
        }
        
        // Set the height of the popover.
        // Limit the size to 10 elements
        let height = resultsPasswords!.count < 10 ? (resultsPasswords!.count * 20) : (10 * 20)

        // Set the width of the popover, so that all results fit.
        // It should be at least 330 wide.
        var width = (resultsPasswords!.max(by: {$1.count > $0.count})?.count)! * 7
        if width < 330 {
            width = 330
        }
        
        // Animate the size of the popover
        heightConstraint.animator().constant = CGFloat(height)
        widthConstraint.animator().constant = CGFloat(width)
        
        // show the table
        searchResultsTable.isHidden = false
        searchResultsTable.reloadData()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchResultsTable.delegate = self
        searchResultsTable.dataSource = self
        searchResultsTable.target = self
        searchResultsTable.doubleAction = #selector(tableViewDoubleClick(_:))
        searchResultsTable.isHidden = true
    }

    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        passwordToClipboard()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            passwordToClipboard()
        }
    }

    func passwordToClipboard() {
        if searchResultsTable.selectedRow < 0 {
            print("Something went wrong. There are not results in the results table")
            return
        }
        let item = (resultsPasswords?[searchResultsTable.selectedRow])!

        let returned = passwordstore?.passwordToClipboard(pathToFile: item)

        if returned!.components(separatedBy: " ").first == "Error:" {
            return
        }

        let delegate = NSApplication.shared.delegate as! AppDelegate
        delegate.togglePopover(nil)
    }
    
}

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return resultsPasswords?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return (resultsPasswords!)[row]
    }
}

extension NSSearchField {
    override open func performKeyEquivalent(with event: NSEvent) -> Bool {
        let commandKey = NSEvent.ModifierFlags.command.rawValue
        if event.type == NSEvent.EventType.keyDown {
            if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandKey {
                switch event.charactersIgnoringModifiers! {
                    case "x":
                        if NSApp.sendAction(#selector(NSText.cut(_:)), to:nil, from:self) { return true }
                    case "c":
                        if NSApp.sendAction(#selector(NSText.copy(_:)), to:nil, from:self) { return true }
                    case "v":
                        if NSApp.sendAction(#selector(NSText.paste(_:)), to:nil, from:self) { return true }
                    case "z":
                        if NSApp.sendAction(Selector(("undo:")), to:nil, from:self) { return true }
                    case "a":
                        if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to:nil, from:self) { return true }
                    case "q":
                        NSApplication.shared.terminate(self)
                    default:
                        break
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
