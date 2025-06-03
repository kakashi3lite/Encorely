import { Socket } from 'socket.io';

export interface ComponentStructure {
  type: string;
  children?: ComponentStructure[];
  props?: Record<string, any>;
  id?: string;
}

export interface Component<Props = any, State = any> {
  name: string;
  structure: ComponentStructure;
  propsToState: (props: Props) => State;
  render: (state: State, socket: Socket) => ComponentStructure;
}

export interface PersonalityCardProps {
  type: string;
  traits: string[];
  strength: number;
  active: boolean;
}

export interface MoodCardProps {
  type: string;
  intensity: number;
  color: string;
  active: boolean;
}

export interface AudioVisualizationProps {
  audioFeatures: {
    energy: number;
    tempo: number;
    valence: number;
    frequencies: number[];
  };
}

export interface PlayerControlsProps {
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
}
