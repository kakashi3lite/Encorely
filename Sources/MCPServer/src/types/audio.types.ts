export interface AudioFeaturesType {
    tempo: number;
    energy: number;
    intensity: number;
    moodScore: number;
    frequency: {
        low: number;
        mid: number;
        high: number;
    };
    dynamics: {
        peak: number;
        rms: number;
        crest: number;
    };
    spectral: {
        centroid: number;
        rolloff: number;
        flux: number;
    };
}