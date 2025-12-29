//
//  RichTextEditor.swift
//  Humans
//
//  Created for rich text editing in notes
//

import SwiftUI
import UIKit

// MARK: - Rich Text Editor with Toolbar
struct RichTextEditorWithToolbar: View {
    @Binding var markdownText: String
    var placeholder: String
    var onTextChange: ((String) -> Void)?
    
    @State private var textView: UITextView?
    @State private var isFocused = false
    @State private var isLinkInputPresented = false
    @State private var linkURL = ""
    @State private var linkText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Formatting toolbar - only show when focused
            if isFocused && textView != nil {
                FormattingToolbar(
                    textView: $textView,
                    isLinkInputPresented: $isLinkInputPresented,
                    linkURL: $linkURL,
                    linkText: $linkText
                )
            }
            
            // Rich text editor
            RichTextEditor(
                markdownText: $markdownText,
                placeholder: placeholder,
                onTextChange: onTextChange,
                textViewBinding: $textView,
                isFocused: $isFocused
            )
        }
    }
}

// MARK: - Rich Text Editor Component
struct RichTextEditor: UIViewRepresentable {
    @Binding var markdownText: String
    var placeholder: String
    var onTextChange: ((String) -> Void)?
    var textViewBinding: Binding<UITextView?>?
    var isFocused: Binding<Bool>?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 17)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.isScrollEnabled = true
        
        // Enable rich text editing
        textView.allowsEditingTextAttributes = false
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label
        ]
        
        // Convert markdown to attributed string for display
        if !markdownText.isEmpty {
            textView.attributedText = MarkdownConverter.markdownToAttributedString(markdownText)
        } else {
            textView.text = ""
        }
        
        // Set up placeholder
        context.coordinator.placeholderLabel.text = placeholder
        context.coordinator.placeholderLabel.font = .systemFont(ofSize: 17)
        context.coordinator.placeholderLabel.textColor = .placeholderText
        textView.addSubview(context.coordinator.placeholderLabel)
        context.coordinator.updatePlaceholder(textView: textView)
        
        // Store reference (defer to avoid modifying state during view update)
        context.coordinator.textView = textView
        DispatchQueue.main.async {
            textViewBinding?.wrappedValue = textView
        }
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if the text actually changed (to avoid cursor jumping)
        let currentMarkdown = MarkdownConverter.attributedStringToMarkdown(textView.attributedText)
        if currentMarkdown != markdownText {
            if !markdownText.isEmpty {
                textView.attributedText = MarkdownConverter.markdownToAttributedString(markdownText)
            } else {
                textView.attributedText = NSAttributedString()
            }
            context.coordinator.updatePlaceholder(textView: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        let placeholderLabel = UILabel()
        weak var textView: UITextView?
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            // Update focus state when editing begins
            DispatchQueue.main.async {
                self.parent.isFocused?.wrappedValue = true
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            // Update focus state when editing ends
            DispatchQueue.main.async {
                self.parent.isFocused?.wrappedValue = false
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Convert attributed text to markdown
            let markdown = MarkdownConverter.attributedStringToMarkdown(textView.attributedText)
            parent.markdownText = markdown
            updatePlaceholder(textView: textView)
            parent.onTextChange?(markdown)
        }
        
        func updatePlaceholder(textView: UITextView) {
            placeholderLabel.isHidden = !textView.attributedText.string.isEmpty
            placeholderLabel.frame = CGRect(x: 8, y: 8, width: max(textView.bounds.width - 16, 0), height: 20)
        }
        
        func textViewDidLayoutSubviews() {
            if let textView = textView {
                updatePlaceholder(textView: textView)
            }
        }
    }
}

// MARK: - Formatting Toolbar
struct FormattingToolbar: View {
    @Binding var textView: UITextView?
    @Binding var isLinkInputPresented: Bool
    @Binding var linkURL: String
    @Binding var linkText: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                formatButton(icon: "bold", action: applyBold)
                formatButton(icon: "italic", action: applyItalic)
                formatButton(icon: "link", action: showLinkInput)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGray6))
            
            if isLinkInputPresented {
                linkInputView
            }
        }
    }
    
    private var linkInputView: some View {
        VStack(spacing: 8) {
            TextField("Link text", text: $linkText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("URL", text: $linkURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    isLinkInputPresented = false
                    linkURL = ""
                    linkText = ""
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Add Link") {
                    applyLink(text: linkText.isEmpty ? linkURL : linkText, url: linkURL)
                    isLinkInputPresented = false
                    linkURL = ""
                    linkText = ""
                }
                .foregroundColor(.blue)
                .disabled(linkURL.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemGray5))
    }
    
    private func formatButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Color(uiColor: .systemGray5))
                .clipShape(Circle())
        }
        .disabled(textView == nil)
    }
    
    private func applyBold() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        guard selectedRange.length > 0 else { return }
        
        let attributedText = textView.attributedText.mutableCopy() as! NSMutableAttributedString
        let range = NSRange(location: selectedRange.location, length: selectedRange.length)
        
        // Check if already bold
        var isBold = false
        attributedText.enumerateAttributes(in: range, options: []) { attributes, _, _ in
            if let font = attributes[.font] as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                isBold = true
            }
        }
        
        // Toggle bold
        if isBold {
            // Remove bold
            attributedText.enumerateAttributes(in: range, options: []) { _, subRange, _ in
                attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: subRange)
            }
        } else {
            // Add bold
            let boldFont = UIFont.boldSystemFont(ofSize: 17)
            attributedText.addAttribute(.font, value: boldFont, range: range)
        }
        
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
        textView.delegate?.textViewDidChange?(textView)
    }
    
    private func applyItalic() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        guard selectedRange.length > 0 else { return }
        
        let attributedText = textView.attributedText.mutableCopy() as! NSMutableAttributedString
        let range = NSRange(location: selectedRange.location, length: selectedRange.length)
        
        // Check if already italic
        var isItalic = false
        attributedText.enumerateAttributes(in: range, options: []) { attributes, _, _ in
            if let font = attributes[.font] as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                isItalic = true
            }
        }
        
        // Toggle italic
        if isItalic {
            // Remove italic
            attributedText.enumerateAttributes(in: range, options: []) { _, subRange, _ in
                attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: subRange)
            }
        } else {
            // Add italic
            let italicFont = UIFont.italicSystemFont(ofSize: 17)
            attributedText.addAttribute(.font, value: italicFont, range: range)
        }
        
        textView.attributedText = attributedText
        textView.selectedRange = selectedRange
        textView.delegate?.textViewDidChange?(textView)
    }
    
    private func showLinkInput() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        // Pre-fill link text with selected text if any
        if selectedRange.length > 0 {
            linkText = textView.attributedText.attributedSubstring(from: selectedRange).string
        } else {
            linkText = ""
        }
        
        isLinkInputPresented = true
    }
    
    private func applyLink(text: String, url: String) {
        guard let textView = textView, let url = URL(string: url) else { return }
        let selectedRange = textView.selectedRange
        
        let attributedText = textView.attributedText.mutableCopy() as! NSMutableAttributedString
        
        if selectedRange.length > 0 {
            // Replace selected text with link
            let linkAttributes: [NSAttributedString.Key: Any] = [
                .link: url,
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.systemBlue
            ]
            attributedText.replaceCharacters(in: selectedRange, with: NSAttributedString(string: text, attributes: linkAttributes))
        } else {
            // Insert link at cursor
            let linkAttributes: [NSAttributedString.Key: Any] = [
                .link: url,
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.systemBlue
            ]
            attributedText.insert(NSAttributedString(string: text, attributes: linkAttributes), at: selectedRange.location)
        }
        
        textView.attributedText = attributedText
        textView.delegate?.textViewDidChange?(textView)
    }
}

// MARK: - Markdown Conversion Utilities
struct MarkdownConverter {
    /// Converts NSAttributedString to markdown string
    static func attributedStringToMarkdown(_ attributedString: NSAttributedString) -> String {
        guard attributedString.length > 0 else { return "" }
        
        var result = ""
        var i = 0
        
        while i < attributedString.length {
            // Find the effective range for these attributes
            var effectiveRange = NSRange()
            let attributes = attributedString.attributes(at: i, effectiveRange: &effectiveRange)
            
            let segmentRange = NSRange(location: i, length: effectiveRange.length)
            let segmentText = attributedString.attributedSubstring(from: segmentRange).string
            
            // Format this segment
            result += formatSegment(segmentText, attributes: attributes)
            
            i = segmentRange.location + segmentRange.length
        }
        
        return result
    }
    
    private static func formatSegment(_ text: String, attributes: [NSAttributedString.Key: Any]) -> String {
        // Check for link first (links take precedence)
        if let url = attributes[.link] as? URL {
            let urlString = url.absoluteString
            return "[\(text)](\(urlString))"
        }
        
        // Check font attributes for bold/italic
        var isBold = false
        var isItalic = false
        
        if let font = attributes[.font] as? UIFont {
            let traits = font.fontDescriptor.symbolicTraits
            isBold = traits.contains(.traitBold)
            isItalic = traits.contains(.traitItalic)
        }
        
        // Apply formatting
        if isBold && isItalic {
            // Both: bold with italic inside (markdown doesn't have a standard for this, so we'll use bold)
            return "**\(text)**"
        } else if isBold {
            return "**\(text)**"
        } else if isItalic {
            return "*\(text)*"
        }
        
        return text
    }
    
    /// Converts markdown string to NSAttributedString
    static func markdownToAttributedString(_ markdown: String) -> NSAttributedString {
        guard !markdown.isEmpty else {
            return NSAttributedString(string: "", attributes: [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ])
        }
        
        let result = NSMutableAttributedString(string: "")
        var remaining = markdown
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label
        ]
        
        while !remaining.isEmpty {
            let nsString = remaining as NSString
            
            // Find earliest match
            var earliestMatch: (range: NSRange, content: String, attributes: [NSAttributedString.Key: Any])?
            var earliestLocation = Int.max
            
            // Check for links: [text](url) - process first to avoid conflicts
            let linkPattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
            if let regex = try? NSRegularExpression(pattern: linkPattern, options: []),
               let match = regex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 3,
               match.range.location < earliestLocation {
                let text = nsString.substring(with: match.range(at: 1))
                let urlString = nsString.substring(with: match.range(at: 2))
                if let url = URL(string: urlString) {
                    var attributes = defaultAttributes
                    attributes[.link] = url
                    attributes[.foregroundColor] = UIColor.systemBlue
                    earliestLocation = match.range.location
                    earliestMatch = (match.range, text, attributes)
                }
            }
            
            // Check for bold: **text** (but not if it's part of a link)
            let boldPattern = #"(?<!\*)\*\*([^*]+?)\*\*(?!\*)"#
            if let regex = try? NSRegularExpression(pattern: boldPattern, options: []),
               let match = regex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2,
               match.range.location < earliestLocation {
                let text = nsString.substring(with: match.range(at: 1))
                var attributes = defaultAttributes
                attributes[.font] = UIFont.boldSystemFont(ofSize: 17)
                earliestLocation = match.range.location
                earliestMatch = (match.range, text, attributes)
            }
            
            // Check for italic: *text* (single asterisk, not double)
            let italicPattern = #"(?<!\*)\*([^*\n]+?)\*(?!\*)"#
            if let regex = try? NSRegularExpression(pattern: italicPattern, options: []),
               let match = regex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2,
               match.range.location < earliestLocation {
                let text = nsString.substring(with: match.range(at: 1))
                var attributes = defaultAttributes
                attributes[.font] = UIFont.italicSystemFont(ofSize: 17)
                earliestLocation = match.range.location
                earliestMatch = (match.range, text, attributes)
            }
            
            if let match = earliestMatch {
                // Add text before match
                if match.range.location > 0 {
                    let beforeText = nsString.substring(to: match.range.location)
                    result.append(NSAttributedString(string: beforeText, attributes: defaultAttributes))
                }
                
                // Add formatted content (recursively parse for nested formatting)
                let formatted = markdownToAttributedString(match.content)
                let mutableFormatted = formatted.mutableCopy() as! NSMutableAttributedString
                mutableFormatted.addAttributes(match.attributes, range: NSRange(location: 0, length: mutableFormatted.length))
                result.append(mutableFormatted)
                
                // Continue with remaining text
                let afterStart = match.range.location + match.range.length
                remaining = nsString.substring(from: afterStart)
            } else {
                // No more matches, append remaining text
                result.append(NSAttributedString(string: remaining, attributes: defaultAttributes))
                break
            }
        }
        
        return result
    }
}
