//
//  Contact.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import Foundation

/// A lightweight model representing a contact summary for list display
struct Contact: Identifiable {
    let id: String // CNContact.identifier
    let givenName: String
    let familyName: String
    let organizationName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let thumbnailImageData: Data?
    
    var displayName: String {
        let fullName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
        if !fullName.isEmpty {
            return fullName
        }
        if !organizationName.isEmpty {
            return organizationName
        }
        return "No Name"
    }
    
    var initials: String {
        var initials = ""
        if !givenName.isEmpty {
            initials += String(givenName.prefix(1))
        }
        if !familyName.isEmpty {
            initials += String(familyName.prefix(1))
        }
        if initials.isEmpty && !organizationName.isEmpty {
            initials = String(organizationName.prefix(1))
        }
        return initials.uppercased()
    }
}

