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
    
    /// Formats modification date to "time ago" format (e.g., "2d ago", "4hr ago", "5m ago", "3mo ago", "1yr ago")
    var timeAgoString: String? {
        guard let modificationDate = modificationDate else {
            return nil
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: modificationDate, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)yr ago"
        } else if let months = components.month, months > 0 {
            return "\(months)mo ago"
        } else if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)hr ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}

