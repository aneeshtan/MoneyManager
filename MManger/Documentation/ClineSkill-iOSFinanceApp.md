# Cline Skill: iOS Finance App Development

## Overview
This skill guides Cline in developing and maintaining the MoneyManager iOS finance application with a focus on compact SwiftUI UI, proper confirmation dialogs, clean transaction editor patterns, and smooth UI/UX.

## Core Principles

### 1. Compact SwiftUI UI
- Use appropriate font sizing hierarchies (.caption, .footnote, .body, .callout)
- Implement efficient layouts with proper spacing and padding
- Utilize SF Symbols consistently for iconography
- Apply rounded rectangle shapes (18pt corner radius) for cards and buttons
- Use glass morphism effects with subtle shadows and borders
- Implement proper truncation with `.lineLimit()` and `.truncationMode()`

### 2. Confirmation Dialogs for Destructive Actions
- Always use confirmation dialogs before destructive operations
- Place destructive actions at the bottom of forms or in context menus
- Use appropriate `.alert()` modifiers for centered popups
- Apply `role: .destructive` for proper styling
- Include clear, descriptive messages explaining consequences

### 3. Clean Transaction Editor Patterns
- Separate creation and editing modes clearly
- Use toolbar items appropriately (Cancel/Save in toolbar, Delete in form)
- Implement proper form validation with disabled states
- Handle keyboard types appropriately (.decimalPad for amounts)
- Use segmented pickers for transaction types
- Provide sensible defaults for new transactions

### 4. Smooth Transitions & Animations
- Apply consistent animation curves (`.spring(response: 0.24, dampingFraction: 0.82)`)
- Use scale and offset effects for button press states
- Implement proper sheet presentations for editors
- Ensure smooth scrolling with LazyVStack
- Add subtle shadow animations on interaction

### 5. Color & Typography System
- Follow established theme colors (AppTheme enum)
- Use appropriate font weights (.semibold, .bold) for hierarchy
- Apply proper color semantics (teal for income, coral for expenses)
- Maintain consistent padding and spacing (12-18pt ranges)
- Use opacity variations for secondary text and disabled states

## Implementation Patterns

### Transaction Row
```swift
HStack {
    // Icon
    TransactionIcon(kind: transaction.kind)
    
    // Content
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.caption.weight(.semibold))  // Compact but readable
            .lineLimit(2)                      // Allow wrapping
            .truncationMode(.tail)
        
        // Supporting details
        HStack {
            Text(detail)
            // ...
        }
        .font(.caption.weight(.medium))
    }
    
    // Amount
    Text(amount)
        .font(.callout.weight(.bold))
}
.padding()  // Consistent padding
.background()  // Card styling
```

### Destructive Action Flow
```swift
Section {
    Button("Delete Transaction", role: .destructive) {
        showingConfirmation = true
    }
    .alert("Confirm Deletion", isPresented: $showingConfirmation) {
        Button("Delete", role: .destructive) { deleteAction() }
        Button("Cancel", role: .cancel) { }
    } message: {
        Text("This action cannot be undone.")
    }
}
```

### Editor Validation
```swift
.toolbar {
    ToolbarItem(placement: .confirmationAction) {
        Button("Save") { save() }
            .disabled(!isValid)  // Proper validation
    }
}
```

## Best Practices

### Layout & Spacing
- Use 18pt horizontal padding for main content
- Apply 12-14pt vertical spacing between elements
- Maintain 14pt corner radius for cards
- Use 12pt minimum tap targets

### Performance
- Use LazyVStack for scrollable content
- Implement proper @Query sorting
- Cache expensive calculations
- Use @StateObject for view models when needed

### Accessibility
- Provide accessibility labels for custom controls
- Use semantic colors and fonts
- Support dynamic type sizing
- Ensure proper contrast ratios

## Common Components

### AppBackground
- Gradient background with light, airy feel
- Subtle color transitions

### GlassSurface
- White background with opacity
- Subtle shadow
- Border stroke for definition

### TransactionIcon
- Circular icons with kind-appropriate colors
- Consistent sizing (36x36)
- Symbol weights and opacities

This skill ensures consistent, high-quality development aligned with modern iOS design principles and the specific needs of the finance application.