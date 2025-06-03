import { Component } from '../../types/component';

export interface WireframeContainerProps {
    title: string;
    children?: any;
}

export const WireframeContainer: Component<WireframeContainerProps> = {
    name: 'WireframeContainer',
    
    // Define the component structure
    structure: {
        container: {
            type: 'View',
            style: {
                spacing: 0,
                flexDirection: 'column'
            },
            children: ['header', 'content']
        },
        header: {
            type: 'View',
            style: {
                backgroundColor: 'systemBackground',
                padding: 16,
                borderBottomWidth: 0.5,
                borderBottomColor: 'separator'
            },
            children: ['title']
        },
        title: {
            type: 'Text',
            style: {
                fontSize: 17,
                fontWeight: 'semibold',
                textAlign: 'center'
            }
        },
        content: {
            type: 'View',
            style: {
                flex: 1,
                backgroundColor: 'systemGroupedBackground'
            }
        }
    },

    // Map props to the structure
    propsToState: (props: WireframeContainerProps) => ({
        title: {
            text: props.title
        },
        content: {
            children: props.children
        }
    })
};