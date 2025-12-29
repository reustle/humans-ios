//
//  ContactDetailView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - Contact Detail View
struct ContactDetailView: View {
    let contact: Contact
    @State private var contactWithNotes: Contact?
    @State private var isLoadingNotes = false
    @State private var newCommentText = ""
    @State private var isSavingNote = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSavingImage = false
    @State private var showPhotoPicker = false
    @State private var editingNoteTimestamp: String? = nil // Timestamp of the note being edited
    
    private var displayContact: Contact {
        contactWithNotes ?? contact
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                actionButtonsView
                notesSectionView
            }
            .padding(.bottom)
        }
        .navigationTitle(displayContact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContactWithNotes()
        }
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let newValue = newValue {
                    await loadAndSaveImage(from: newValue)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            avatarView
            nameView
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var avatarView: some View {
        Button(action: {
            showPhotoPicker = true
        }) {
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
        }
        .buttonStyle(PlainButtonStyle())
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
    }
    
    private var nameView: some View {
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
    }
    
    @ViewBuilder
    private var actionButtonsView: some View {
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
    }
    
    private var notesSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(.secondary)
            
            newNoteView
            
            if !displayContact.note.isEmpty {
                notesView(from: displayContact.note)
            }
        }
        .padding(.horizontal)
    }
    
    private var newNoteView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(editingNoteTimestamp != nil ? "Edit note" : "New note", text: $newCommentText, axis: .vertical)
                .lineLimit(3...10)
                .padding(12)
                .font(.body)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 12) {
                    Button(action: {
                        cancelEditing()
                    }) {
                        Text("Cancel")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .disabled(isSavingNote)
                    
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
        
        let repository = ContactsRepository()
        do {
            if let editingTimestamp = editingNoteTimestamp {
                // Editing an existing note - update only that segment
                try await updateNoteSegment(timestamp: editingTimestamp, newContent: trimmedText)
            } else {
                // Creating a new note
                // Format datetime in ISO 8601 UTC format
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
                let timestamp = formatter.string(from: Date())
                let prefixedComment = "[\(timestamp)]\n\(trimmedText)"
                
                try await repository.updateContactNote(identifier: contact.id, newNote: prefixedComment, prepend: true)
            }
            
            // Clear the text field and editing state immediately after successful save
            newCommentText = ""
            editingNoteTimestamp = nil
            
            // Reload the contact to show the updated notes
            await loadContactWithNotes()
        } catch {
            print("Error saving note: \(error)")
            // Could show an error alert here in the future
        }
    }
    
    /// Updates a specific note segment by replacing only that segment's content
    private func updateNoteSegment(timestamp: String, newContent: String) async throws {
        let repository = ContactsRepository()
        
        // Fetch current notes
        guard let currentContact = try await repository.fetchContactWithNotes(identifier: contact.id) else {
            throw NSError(domain: "ContactDetailView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Contact not found"])
        }
        
        let currentNotes = currentContact.note
        let segments = parseNotesSegments(from: currentNotes)
        
        // Find the segment with matching timestamp and update it
        var updatedSegments: [NoteSegment] = []
        var found = false
        
        for segment in segments {
            if segment.timestamp == timestamp {
                // Replace this segment's content
                updatedSegments.append(NoteSegment(timestamp: timestamp, content: newContent))
                found = true
            } else {
                updatedSegments.append(segment)
            }
        }
        
        guard found else {
            throw NSError(domain: "ContactDetailView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Note segment not found"])
        }
        
        // Reconstruct the notes string
        var updatedNotes = ""
        for (index, segment) in updatedSegments.enumerated() {
            if index > 0 {
                updatedNotes += "\n\n"
            }
            if let ts = segment.timestamp {
                updatedNotes += "\(ts)\n\(segment.content)"
            } else {
                updatedNotes += segment.content
            }
        }
        
        // Save the updated notes (replace entire notes field)
        try await repository.updateContactNote(identifier: contact.id, newNote: updatedNotes, prepend: false)
    }
    
    /// Cancels editing and clears the text field
    private func cancelEditing() {
        newCommentText = ""
        editingNoteTimestamp = nil
    }
    
    /// Structure to hold a note segment with its timestamp
    private struct NoteSegment {
        let timestamp: String?
        let content: String
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
                
                VStack(alignment: .leading, spacing: 4) {
                    // Timestamp (right-aligned, softer, smaller)
                    if let timestamp = segment.timestamp, let timeAgo = formatTimeAgo(from: timestamp) {
                        HStack {
                            Spacer()
                            Text(timeAgo)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Note content
                    if !segment.content.isEmpty {
                        Text(attributedString(from: segment.content))
                            .font(.body)
                            .foregroundColor(.primary)
                            .onTapGesture(count: 2) {
                                // Double tap to edit
                                if let timestamp = segment.timestamp {
                                    editingNoteTimestamp = timestamp
                                    newCommentText = segment.content
                                }
                            }
                    }
                }
            }
        }
    }
    
    /// Formats an ISO 8601 timestamp string to "time ago" format
    private func formatTimeAgo(from timestampString: String) -> String? {
        // Remove brackets if present
        let cleanedTimestamp = timestampString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        guard let date = formatter.date(from: cleanedTimestamp) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: cleanedTimestamp) else {
                return nil
            }
            return formatTimeAgo(from: date)
        }
        
        return formatTimeAgo(from: date)
    }
    
    /// Formats a Date to "time ago" format
    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
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
    
    /// Converts markdown text to AttributedString with formatting
    private func attributedString(from markdown: String) -> AttributedString {
        // Process line by line to handle headings
        let lines = markdown.components(separatedBy: .newlines)
        var result = AttributedString()
        
        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 {
                result.append(AttributedString("\n"))
            }
            
            // Handle headings: # text -> bold (remove # and make text bold)
            if line.hasPrefix("#") {
                let headingContent = String(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                if !headingContent.isEmpty {
                    var headingAttributed = parseMarkdownInText(headingContent)
                    // Make the entire heading bold
                    headingAttributed.font = .system(size: 17, weight: .bold)
                    result.append(headingAttributed)
                }
            } else {
                // Process regular line with markdown
                result.append(parseMarkdownInText(line))
            }
        }
        
        return result
    }
    
    /// Parses markdown formatting in a string and returns an AttributedString with formatting applied
    private func parseMarkdownInText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text
        
        while !remaining.isEmpty {
            // Find the earliest markdown pattern
            var earliestMatch: (range: NSRange, content: String, format: (AttributedString) -> AttributedString)?
            var earliestLocation = Int.max
            
            let nsString = remaining as NSString
            
            // Check for links: [text](url)
            if let linkMatch = findLink(in: remaining, nsString: nsString) {
                if linkMatch.range.location < earliestLocation {
                    earliestLocation = linkMatch.range.location
                    earliestMatch = linkMatch
                }
            }
            
            // Check for strikeout: ~~text~~
            if let strikeoutMatch = findStrikeout(in: remaining, nsString: nsString) {
                if strikeoutMatch.range.location < earliestLocation {
                    earliestLocation = strikeoutMatch.range.location
                    earliestMatch = strikeoutMatch
                }
            }
            
            // Check for bold: **text** or __text__
            if let boldMatch = findBold(in: remaining, nsString: nsString) {
                if boldMatch.range.location < earliestLocation {
                    earliestLocation = boldMatch.range.location
                    earliestMatch = boldMatch
                }
            }
            
            // Check for underline: _text_ (single underscore, not double)
            if let underlineMatch = findUnderline(in: remaining, nsString: nsString) {
                if underlineMatch.range.location < earliestLocation {
                    earliestLocation = underlineMatch.range.location
                    earliestMatch = underlineMatch
                }
            }
            
            // Check for italic: *text* (single asterisk, not double)
            if let italicMatch = findItalic(in: remaining, nsString: nsString) {
                if italicMatch.range.location < earliestLocation {
                    earliestLocation = italicMatch.range.location
                    earliestMatch = italicMatch
                }
            }
            
            if let match = earliestMatch {
                // Add text before the match
                if match.range.location > 0 {
                    let beforeText = nsString.substring(to: match.range.location)
                    result.append(AttributedString(beforeText))
                }
                
                // Add the formatted content (recursively parse for nested formatting)
                var formatted = parseMarkdownInText(match.content)
                formatted = match.format(formatted)
                result.append(formatted)
                
                // Continue with remaining text after the match
                let afterStart = match.range.location + match.range.length
                remaining = nsString.substring(from: afterStart)
            } else {
                // No more matches, append remaining text
                result.append(AttributedString(remaining))
                break
            }
        }
        
        return result
    }
    
    private func findLink(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        let pattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 3 else {
            return nil
        }
        
        let linkText = nsString.substring(with: match.range(at: 1))
        let url = nsString.substring(with: match.range(at: 2))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            result.link = URL(string: url)
            return result
        }
        
        return (match.range, linkText, format)
    }
    
    private func findStrikeout(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        let pattern = #"~~([^~]+)~~"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let content = nsString.substring(with: match.range(at: 1))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            result.strikethroughStyle = .single
            return result
        }
        
        return (match.range, content, format)
    }
    
    private func findBold(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        // Try **text** first, then __text__
        let patterns = [(#"(\*\*)([^*]+)\1"#, 2), (#"(__)([^_]+)\1"#, 2)]
        
        for (pattern, groupIndex) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
                  match.numberOfRanges >= groupIndex + 1 else {
                continue
            }
            
            let content = nsString.substring(with: match.range(at: groupIndex))
            
            let format: (AttributedString) -> AttributedString = { formatted in
                var result = formatted
                result.font = .system(size: 17, weight: .bold)
                return result
            }
            
            return (match.range, content, format)
        }
        
        return nil
    }
    
    private func findUnderline(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        // Single underscore _text_, but not __text__ (that's bold)
        let pattern = #"(?<!_)_([^_\n]+?)_(?!_)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let content = nsString.substring(with: match.range(at: 1))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            result.underlineStyle = .single
            return result
        }
        
        return (match.range, content, format)
    }
    
    private func findItalic(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        // Single asterisk *text*, but not **text** (that's bold)
        let pattern = #"(?<!\*)\*([^*\n]+?)\*(?!\*)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let content = nsString.substring(with: match.range(at: 1))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            // Apply italic font using UIFont descriptor
            let baseFont = UIFont.systemFont(ofSize: 17)
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                let italicFont = UIFont(descriptor: descriptor, size: 17)
                result.font = Font(italicFont)
            } else {
                // Fallback to italic system font
                result.font = Font(UIFont.italicSystemFont(ofSize: 17))
            }
            return result
        }
        
        return (match.range, content, format)
    }
    
    /// Parses notes text into segments, splitting by date tags
    private func parseNotesSegments(from text: String) -> [NoteSegment] {
        // Pattern for ISO 8601 date tags: [YYYY-MM-DDTHH:MM:SS(.SSS)?Z]
        // Handles both with and without fractional seconds
        let dateTagPattern = #"\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\]"#
        guard let regex = try? NSRegularExpression(pattern: dateTagPattern, options: []) else {
            // If regex fails, return the whole text as a single segment without timestamp
            return text.isEmpty ? [] : [NoteSegment(timestamp: nil, content: text)]
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if matches.isEmpty {
            return text.isEmpty ? [] : [NoteSegment(timestamp: nil, content: text)]
        }
        
        var segments: [NoteSegment] = []
        var currentIndex = 0
        
        for match in matches {
            let matchRange = match.range
            
            // If there's text before this match, add it as a segment (shouldn't happen with our format, but handle it)
            if matchRange.location > currentIndex {
                let beforeText = nsString.substring(with: NSRange(location: currentIndex, length: matchRange.location - currentIndex))
                if !beforeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(NoteSegment(timestamp: nil, content: beforeText.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            
            // Extract the timestamp string
            let timestampString = nsString.substring(with: matchRange)
            
            // Find the end of this segment (start of next date tag or end of text)
            let segmentEnd: Int
            if let nextMatchIndex = matches.firstIndex(where: { $0.range.location > matchRange.location }) {
                segmentEnd = matches[nextMatchIndex].range.location
            } else {
                segmentEnd = nsString.length
            }
            
            // Extract content after the timestamp (skip the timestamp and any newline/whitespace)
            let contentStart = matchRange.location + matchRange.length
            let contentLength = segmentEnd - contentStart
            let contentRange = NSRange(location: contentStart, length: contentLength)
            let contentText = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
            
            segments.append(NoteSegment(timestamp: timestampString, content: contentText))
            
            currentIndex = segmentEnd
        }
        
        return segments
    }
    
    /// Loads an image from a PhotosPickerItem, crops it to center square, and saves it
    private func loadAndSaveImage(from item: PhotosPickerItem) async {
        guard !isSavingImage else { return }
        
        isSavingImage = true
        defer { isSavingImage = false }
        
        do {
            // Load image data
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }
            
            // Crop to center square
            let croppedImage = image.croppedToCenterSquare()
            
            // Convert to JPEG
            guard let imageData = croppedImage.jpegData(compressionQuality: 0.8) else {
                return
            }
            
            // Save to contact
            let repository = ContactsRepository()
            try await repository.updateContactImage(identifier: contact.id, imageData: imageData)
            
            // Reload the contact to show the updated image
            await loadContactWithNotes()
        } catch {
            print("Error loading/saving contact image: \(error)")
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    /// Crops the image to a square from the center
    func croppedToCenterSquare() -> UIImage {
        let imageSize = size
        let squareSize = min(imageSize.width, imageSize.height)
        let x = (imageSize.width - squareSize) / 2
        let y = (imageSize.height - squareSize) / 2
        let cropRect = CGRect(x: x, y: y, width: squareSize, height: squareSize)
        
        // Use CGImage cropping which works in image coordinates
        guard let cgImage = cgImage?.cropping(to: cropRect) else {
            return self
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}

