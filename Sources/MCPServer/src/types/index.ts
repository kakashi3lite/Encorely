import { MCPServer } from '@model-context-protocol/server';
import { ThemeType, MoodType } from './theme.types';
import { AudioFeaturesType } from './audio.types';
import { PersonalityType } from './personality.types';

export function registerTypes(server: MCPServer) {
    server.registerType('Theme', ThemeType);
    server.registerType('Mood', MoodType);
    server.registerType('AudioFeatures', AudioFeaturesType);
    server.registerType('Personality', PersonalityType);
}

export * from './theme.types';
export * from './audio.types';
export * from './personality.types';