//
//  ContactDetailView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import UIKit

// MARK: - Contact Detail View
struct ContactDetailView: View {
    let contact: Contact
    @State private var contactWithNotes: Contact?
    @State private var isLoadingNotes = false
    @State private var newCommentText = ""
    @State private var isSavingNote = false
    
    private var displayContact: Contact {
        contactWithNotes ?? contact
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with avatar (left) and name (right)
                HStack(alignment: .center, spacing: 16) {
                    // Avatar
                    Group {
                        if let imageData = displayContact.thumbnailImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                Text(displayContact.initials)
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Name and organization
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayContact.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !displayContact.organizationName.isEmpty {
                            Text(displayContact.organizationName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Circle button icons row (phone and email)
                if !displayContact.phoneNumbers.isEmpty || !displayContact.emailAddresses.isEmpty {
                    HStack(spacing: 12) {
                        if !displayContact.phoneNumbers.isEmpty, let firstPhone = displayContact.phoneNumbers.first {
                            Button(action: {
                                let cleanedPhone = firstPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                if let url = URL(string: "tel://\(cleanedPhone)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .frame(width: 25, height: 25)
                                    .background(Color.gray)
                                    .clipShape(Circle())
                            }
                        }
                        
                        if !displayContact.emailAddresses.isEmpty, let firstEmail = displayContact.emailAddresses.first {
                            Button(action: {
                                if let url = URL(string: "mailto:\(firstEmail)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .frame(width: 25, height: 25)
                                    .background(Color.gray)
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // Notes section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // New comment textarea
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $newCommentText)
                                .frame(height: newCommentText.isEmpty ? 40 : 80)
                                .padding(4)
                                .font(.body)
                            
                            if newCommentText.isEmpty {
                                Text("New note")
                                    .foregroundColor(Color(white: 0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        
                        if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                Task {
                                    await saveNewComment()
                                }
                            }) {
                                Text("Save")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .disabled(isSavingNote)
                        }
                    }
                    
                    // Existing notes with dividers above date tags
                    if !displayContact.note.isEmpty {
                        notesView(from: displayContact.note)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .navigationTitle(displayContact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Fetch contact with notes when view appears
            await loadContactWithNotes()
        }
    }
    
    private func loadContactWithNotes() async {
        guard !isLoadingNotes else { return }
        isLoadingNotes = true
        defer { isLoadingNotes = false }
        
        let repository = ContactsRepository()
        do {
            if let contactWithNotes = try await repository.fetchContactWithNotes(identifier: contact.id) {
                await MainActor.run {
                    self.contactWithNotes = contactWithNotes
                }
            }
        } catch {
            print("Error fetching contact with notes: \(error)")
            // Silently fail - use original contact without notes
        }
    }
    
    private func saveNewComment() async {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        isSavingNote = true
        defer { isSavingNote = false }
        
        // Format datetime in ISO 8601 UTC format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        let timestamp = formatter.string(from: Date())
        let prefixedComment = "[\(timestamp)]\n\(trimmedText)"
        
        let repository = ContactsRepository()
        do {
            try await repository.updateContactNote(identifier: contact.id, newNote: prefixedComment, prepend: true)
            
            // Clear the text field
            await MainActor.run {
                newCommentText = ""
            }
            
            // Reload the contact to show the updated notes
            await loadContactWithNotes()
        } catch {
            print("Error saving note: \(error)")
            // Could show an error alert here in the future
        }
    }
    
    /// Renders notes text with horizontal rules above date tags
    private func notesView(from text: String) -> some View {
        let segments = parseNotesSegments(from: text)
        
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                Text(segment)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }
    
    /// Parses notes text into segments, splitting by date tags
    private func parseNotesSegments(from text: String) -> [String] {
        // Pattern for ISO 8601 date tags: [YYYY-MM-DDTHH:MM:SS(.SSS)?Z]
        // Handles both with and without fractional seconds
        let dateTagPattern = #"\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\]"#
        guard let regex = try? NSRegularExpression(pattern: dateTagPattern, options: []) else {
            // If regex fails, return the whole text as a single segment
            return text.isEmpty ? [] : [text]
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if matches.isEmpty {
            return text.isEmpty ? [] : [text]
        }
        
        var segments: [String] = []
        var currentIndex = 0
        
        for match in matches {
            let matchRange = match.range
            
            // If there's text before this match, add it as a segment (shouldn't happen with our format, but handle it)
            if matchRange.location > currentIndex {
                let beforeText = nsString.substring(with: NSRange(location: currentIndex, length: matchRange.location - currentIndex))
                if !beforeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(beforeText.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            
            // Find the end of this segment (start of next date tag or end of text)
            let segmentEnd: Int
            if let nextMatchIndex = matches.firstIndex(where: { $0.range.location > matchRange.location }) {
                segmentEnd = matches[nextMatchIndex].range.location
            } else {
                segmentEnd = nsString.length
            }
            
            // Extract segment (date tag + content until next date tag or end)
            let segmentRange = NSRange(location: matchRange.location, length: segmentEnd - matchRange.location)
            let segmentText = nsString.substring(with: segmentRange).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !segmentText.isEmpty {
                segments.append(segmentText)
            }
            
            currentIndex = segmentEnd
        }
        
        return segments
    }
}

