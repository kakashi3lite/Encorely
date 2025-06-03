export interface Component<Props = any> {
    name: string;
    structure: ComponentStructure;
    propsToState: (props: Props) => any;
}

export interface ComponentStructure {
    [key: string]: {
        type: string;
        style?: any;
        children?: string[] | string;
        props?: any;
    };
}

export interface ComponentState {
    [key: string]: any;
}

export interface ComponentInstance {
    id: string;
    name: string;
    props: any;
    state: ComponentState;
}