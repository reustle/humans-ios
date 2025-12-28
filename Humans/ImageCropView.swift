//
//  ImageCropView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI

/// A view that allows users to move and scale an image for circular cropping
/// Similar to the native Contacts app's "move and scale" interface
struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    // Crop circle size (matches contact photo size)
    private let cropSize: CGFloat = 300
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Instructions
                Text("Move and Scale")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Image crop area
                ZStack {
                    // Dark overlay with circular cutout
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .mask(
                            ZStack {
                                Rectangle()
                                Circle()
                                    .frame(width: cropSize, height: cropSize)
                                    .blendMode(.destinationOut)
                            }
                        )
                    
                    // Crop circle border
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                    
                    // Image with zoom and pan
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cropSize * scale, height: cropSize * scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    // Pinch to zoom
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                            constrainOffset()
                                        }
                                        .onEnded { _ in
                                            // Constrain scale
                                            scale = max(1.0, min(scale, 3.0))
                                            lastScale = scale
                                            constrainOffset()
                                        },
                                    // Drag to pan
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            constrainOffset()
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                    }
                    .frame(width: cropSize, height: cropSize)
                    .clipped()
                }
                .padding(.vertical, 40)
                
                // Buttons
                HStack(spacing: 20) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                    
                    Button("Choose") {
                        let croppedImage = cropImage()
                        onCrop(croppedImage)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Initialize scale to fill crop area
            let imageAspect = image.size.width / image.size.height
            let cropAspect: CGFloat = 1.0 // Circle is 1:1
            
            // Calculate scale to fill the crop circle
            if imageAspect > cropAspect {
                // Image is wider - scale to fill height
                scale = cropSize / image.size.height
            } else {
                // Image is taller - scale to fill width
                scale = cropSize / image.size.width
            }
            // Ensure minimum scale of 1.0
            scale = max(1.0, scale)
            lastScale = scale
        }
    }
    
    /// Constrains the offset to keep the image within the crop area
    private func constrainOffset() {
        let imageSize = cropSize * scale
        let maxOffsetX = max(0, (imageSize - cropSize) / 2)
        let maxOffsetY = max(0, (imageSize - cropSize) / 2)
        
        offset.width = max(-maxOffsetX, min(maxOffsetX, offset.width))
        offset.height = max(-maxOffsetY, min(maxOffsetY, offset.height))
        lastOffset = offset
    }
    
    /// Crops the image to a circular shape based on current scale and offset
    private func cropImage() -> UIImage {
        // Calculate the visible portion of the image in image coordinates
        let imageSize = image.size
        let displaySize = cropSize * scale
        
        // Calculate the scale factor from display size to image size
        let scaleFactor = imageSize.width / displaySize
        
        // Calculate the center point of the visible area in display coordinates
        // The offset is relative to the center, so we need to account for that
        let displayCenterX = cropSize / 2
        let displayCenterY = cropSize / 2
        
        // The visible center in display coordinates (accounting for offset)
        let visibleCenterX = displayCenterX - offset.width
        let visibleCenterY = displayCenterY - offset.height
        
        // Convert to image coordinates
        let imageCenterX = visibleCenterX * scaleFactor
        let imageCenterY = visibleCenterY * scaleFactor
        
        // Crop size in image coordinates (square for circle)
        let cropSizeInImage = cropSize * scaleFactor
        
        // Calculate crop rect
        let cropRect = CGRect(
            x: max(0, min(imageSize.width - cropSizeInImage, imageCenterX - cropSizeInImage / 2)),
            y: max(0, min(imageSize.height - cropSizeInImage, imageCenterY - cropSizeInImage / 2)),
            width: min(cropSizeInImage, imageSize.width),
            height: min(cropSizeInImage, imageSize.height)
        )
        
        // Crop the image
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        // Resize to a standard size for contact photos (e.g., 400x400) and apply circular mask
        let finalSize: CGFloat = 400
        if let resized = croppedImage.resized(to: CGSize(width: finalSize, height: finalSize)) {
            return resized.circularMasked() ?? resized
        }
        return croppedImage.circularMasked() ?? croppedImage
    }
}

extension UIImage {
    /// Creates a circular version of the image
    func circularMasked() -> UIImage? {
        let size = min(size.width, size.height)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Create circular path
        context.addEllipse(in: rect)
        context.clip()
        
        // Draw image centered
        let imageRect = CGRect(
            x: (size - self.size.width) / 2,
            y: (size - self.size.height) / 2,
            width: self.size.width,
            height: self.size.height
        )
        draw(in: imageRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Resizes the image to the specified size
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

