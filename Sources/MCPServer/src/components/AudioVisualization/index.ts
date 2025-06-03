import { Component, ComponentStructure, AudioVisualizationProps } from '../../types/components';
import { Socket } from 'socket.io';

interface AudioVisualizationState extends AudioVisualizationProps {
  animationFrame: number;
}

export const AudioVisualization: Component<AudioVisualizationProps, AudioVisualizationState> = {
  name: 'AudioVisualization',
  
  structure: {
    type: 'canvas',
    props: {
      className: 'audio-visualization',
      width: 800,
      height: 200
    }
  },

  propsToState: (props) => ({
    ...props,
    animationFrame: 0
  }),

  render: (state, socket) => {
    const { energy, tempo, valence, frequencies } = state.audioFeatures;
    
    return {
      type: 'canvas',
      props: {
        className: 'audio-visualization',
        width: 800,
        height: 200,
        onMount: (canvas: HTMLCanvasElement) => {
          const ctx = canvas.getContext('2d');
          if (!ctx) return;

          const renderFrame = () => {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            
            // Draw frequency bars
            const barWidth = canvas.width / frequencies.length;
            frequencies.forEach((freq, i) => {
              const height = freq * canvas.height;
              ctx.fillStyle = `hsl(${(i / frequencies.length) * 360}, ${valence * 100}%, ${50 + (energy * 25)}%)`;
              ctx.fillRect(i * barWidth, canvas.height - height, barWidth, height);
            });

            // Animate based on tempo
            state.animationFrame = requestAnimationFrame(renderFrame);
          };

          renderFrame();
        },
        onUnmount: () => {
          cancelAnimationFrame(state.animationFrame);
        }
      }
    };
  }
};
