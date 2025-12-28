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
    let note: String
    let modificationDate: Date?
    
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
    
    var subtitle: String? {
        if !organizationName.isEmpty && !displayName.contains(organizationName) {
            return organizationName
        }
        if let firstPhone = phoneNumbers.first {
            return firstPhone
        }
        if let firstEmail = emailAddresses.first {
            return firstEmail
        }
        return nil
    }
    
    /// Formats modification date to "time ago" format (e.g., "2d ago", "4hr ago", "5m ago")
    var timeAgoString: String? {
        guard let modificationDate = modificationDate else {
            return nil
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(modificationDate)
        
        let seconds = Int(timeInterval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)hr ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}

