import { MCPServer } from '@model-context-protocol/server';
import { WireframeContainer } from './WireframeContainer';
import { MoodCard } from './MoodCard';
import { PersonalityCard } from './PersonalityCard';
import { AudioVisualization } from './AudioVisualization';
import { PlayerControls } from './PlayerControls';

export function registerComponents(server: MCPServer) {
    server.registerComponent('WireframeContainer', WireframeContainer);
    server.registerComponent('MoodCard', MoodCard);
    server.registerComponent('PersonalityCard', PersonalityCard);
    server.registerComponent('AudioVisualization', AudioVisualization);
    server.registerComponent('PlayerControls', PlayerControls);
}