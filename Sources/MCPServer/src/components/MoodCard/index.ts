import { Component } from '../../types/component';
import { MoodType } from '../../types/theme.types';

export interface MoodCardProps {
    mood: MoodType;
    isSelected?: boolean;
    onSelect?: () => void;
}

export const MoodCard: Component<MoodCardProps> = {
    name: 'MoodCard',
    
    structure: {
        container: {
            type: 'View',
            style: {
                padding: 16,
                borderRadius: 16,
                backgroundColor: 'systemBackground',
                shadowColor: 'black',
                shadowOpacity: 0.1,
                shadowRadius: 10
            },
            children: ['content']
        },
        content: {
            type: 'View',
            style: {
                flexDirection: 'row',
                alignItems: 'center',
                justifyContent: 'space-between'
            },
            children: ['leftContent', 'icon']
        },
        leftContent: {
            type: 'View',
            style: {
                gap: 8
            },
            children: ['label', 'name']
        },
        label: {
            type: 'Text',
            style: {
                fontSize: 14,
                color: 'secondary'
            }
        },
        name: {
            type: 'Text',
            style: {
                fontSize: 20,
                fontWeight: 'semibold'
            }
        },
        icon: {
            type: 'View',
            style: {
                width: 48,
                height: 48,
                borderRadius: 24,
                alignItems: 'center',
                justifyContent: 'center'
            },
            children: ['iconImage']
        },
        iconImage: {
            type: 'Image',
            style: {
                width: 24,
                height: 24
            }
        }
    },

    propsToState: (props: MoodCardProps) => ({
        container: {
            style: {
                shadowColor: props.mood.color,
                shadowOpacity: props.isSelected ? 0.2 : 0.1
            }
        },
        label: {
            text: 'Current Mood'
        },
        name: {
            text: props.mood.name
        },
        icon: {
            style: {
                backgroundColor: `${props.mood.color}20`
            }
        },
        iconImage: {
            source: props.mood.icon,
            tintColor: props.mood.color
        }
    })
};