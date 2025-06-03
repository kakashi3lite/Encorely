export const DesignSystem = {
    spacing: {
        small: 8,
        medium: 16,
        large: 24,
        extraLarge: 32
    },
    
    cornerRadius: {
        small: 8,
        medium: 12,
        large: 16,
        extraLarge: 32
    },
    
    shadow: {
        small: {
            color: 'rgba(0, 0, 0, 0.05)',
            offset: { width: 0, height: 2 },
            radius: 4
        },
        medium: {
            color: 'rgba(0, 0, 0, 0.1)',
            offset: { width: 0, height: 4 },
            radius: 8
        },
        large: {
            color: 'rgba(0, 0, 0, 0.15)',
            offset: { width: 0, height: 8 },
            radius: 16
        }
    },
    
    fontSize: {
        caption: 12,
        subheadline: 14,
        body: 16,
        headline: 17,
        title: 24,
        largeTitle: 28
    },
    
    fontWeight: {
        regular: '400',
        medium: '500',
        semibold: '600',
        bold: '700'
    },
    
    animation: {
        duration: {
            short: 0.2,
            medium: 0.3,
            long: 0.5
        },
        curve: {
            easeInOut: 'cubic-bezier(0.4, 0, 0.2, 1)',
            spring: 'spring(1, 0.5, 0.3)'
        }
    }
} as const;