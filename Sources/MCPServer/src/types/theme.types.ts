export interface ThemeType {
    primary: string;
    secondary: string;
    accent: string;
    background: string;
    text: string;
    spacing: {
        small: number;
        medium: number;
        large: number;
        extraLarge: number;
    };
    cornerRadius: {
        small: number;
        medium: number;
        large: number;
        extraLarge: number;
    };
}

export interface MoodType {
    name: string;
    color: string;
    icon: string;
    intensity: number;
    energy: number;
}