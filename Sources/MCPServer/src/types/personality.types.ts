export interface PersonalityType {
    id: string;
    name: string;
    description: string;
    icon: string;
    themeColor: string;
    uiPreferences: {
        listStyle: 'list' | 'grid' | 'carousel';
        navigationStyle: 'hierarchical' | 'tabbed' | 'contextual';
        interactionStyle: 'direct' | 'gestural' | 'progressive';
    };
}

export enum PersonalityTrait {
    Analyzer = 'analyzer',
    Explorer = 'explorer',
    Planner = 'planner',
    Creative = 'creative',
    Balanced = 'balanced'
}