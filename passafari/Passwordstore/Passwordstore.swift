//
//  Passwordstore.swift
//  passafari
//
//  Created by Artur Sterz on 28.10.18.
//  Copyright © 2018 Artur Sterz. All rights reserved.
//

import Foundation
import os.log

import ObjectivePGP

class Passwordstore {
    var passwordStoreUrl: URL
    var pgpKeyRing: Keyring = Keyring()
    
    init(url passwordStoreUrl: URL){
        self.passwordStoreUrl = passwordStoreUrl
    }
    
    func passSearch(password: String) -> [String] {
        var resultPaths = [String]()
        
        if self.passwordStoreUrl.startAccessingSecurityScopedResource() {
            let fileSystem = FileManager.default
            if let fsTree = fileSystem.enumerator(atPath: self.passwordStoreUrl.path) {
                // Iterate over all files and folders in the default store path. Several checks will be done.
                while let fsNodeName = fsTree.nextObject() as? String {
                    let fullPath = "\(String(describing: self.passwordStoreUrl))\(fsNodeName)"
                    var pathComponents = URL(fileURLWithPath: fullPath).pathComponents
                    
                    // To not accidentally exclude a valid encrypted file from the search path, we remove it beforehand from the .git search components.
                    if pathComponents.last!.hasSuffix(".gpg") {
                        pathComponents.removeLast()
                    } else {
                        continue
                    }
                    
                    // If a password store is a git folder, we do not want to iterate over the entire repository, but only the current working copy.
                    // Therefore, we need to exclude all folders containing .git from the search items.
                    if pathComponents.contains(where:
                        { (pathComponent) -> Bool in
                            return pathComponent.contains(".git")
                    }) {
                        continue
                    }

                    if fullPath.localizedCaseInsensitiveContains(password) {
                        resultPaths.append(fsNodeName)
                    }
                }
            }
        }
        
        self.passwordStoreUrl.stopAccessingSecurityScopedResource()
        
        return resultPaths
    }
    
    func decrypt(passphrase: String, encryptedFile: Data) -> String {
        if !passphrase.isEmpty {
            do {
                let decryptedPassword = try ObjectivePGP.decrypt(encryptedFile, andVerifySignature: false, using: self.pgpKeyRing.keys, passphraseForKey: { (key) -> String? in
                    return passphrase
                })
                
                return String(data: decryptedPassword, encoding: .utf8) ?? ""
            } catch {
                os_log(.error, log: logger, "%s", "Could not decrypt password due to error \(error)")
                return ""
            }
        }
        
        do {
            let decryptedPassword = try ObjectivePGP.decrypt(encryptedFile, andVerifySignature: false, using: self.pgpKeyRing.keys)
            
            return String(data: decryptedPassword, encoding: .utf8) ?? ""
        } catch {
            let tmpPassphrase = promptForPassphrase()
            do {
                let decryptedPassword = try ObjectivePGP.decrypt(encryptedFile, andVerifySignature: false, using: self.pgpKeyRing.keys, passphraseForKey: { (key) -> String? in
                    return tmpPassphrase
                })
                
                return String(data: decryptedPassword, encoding: .utf8) ?? ""
            } catch {
                os_log(.error, log: logger, "%s", "Could not decrpyt password due to error \(error)")
                return ""
            }
        }
    }
    
    func passDecrypt(pathToFile: String) -> String {
        var resultPassword = ""
        if self.passwordStoreUrl.startAccessingSecurityScopedResource() {
            let encryptedFileUrl = passwordstore!.passwordStoreUrl.appendingPathComponent(pathToFile)
            
            var passphrase: String = ""
            var encryptedFile: Data?
            
            do {
                passphrase = try searchPassphrase()
            } catch {
                os_log(.error, log: logger, "%s", "Could not find passphrase because \(error)")
            }
            
            do {
                encryptedFile = try Data(contentsOf: encryptedFileUrl)
            } catch {
                os_log(.error, log: logger, "%s", "Could not read password file: \(error)")
                self.passwordStoreUrl.stopAccessingSecurityScopedResource()
                return ""
            }
            
            resultPassword = decrypt(passphrase: passphrase, encryptedFile: encryptedFile!)
            
            self.passwordStoreUrl.stopAccessingSecurityScopedResource()
            
            return resultPassword
        }
        os_log(.error, log: logger, "%s", "Could not access security scoped resource in decryption.")
        
        return ""
    }
    
    func importKeys(keyFilePath: String) throws {
        self.pgpKeyRing.import(keys: try! ObjectivePGP.readKeys(fromPath: keyFilePath))
    }
}