import { Component, ComponentStructure, PlayerControlsProps } from '../../types/components';
import { Socket } from 'socket.io';

interface PlayerControlsState extends PlayerControlsProps {
  isDragging: boolean;
  isMuted: boolean;
}

export const PlayerControls: Component<PlayerControlsProps, PlayerControlsState> = {
  name: 'PlayerControls',
  
  structure: {
    type: 'div',
    props: {
      className: 'player-controls',
    },
    children: [
      {
        type: 'div',
        props: { className: 'playback-controls' }
      },
      {
        type: 'div',
        props: { className: 'progress-bar' }
      },
      {
        type: 'div',
        props: { className: 'volume-control' }
      }
    ]
  },

  propsToState: (props) => ({
    ...props,
    isDragging: false,
    isMuted: false
  }),

  render: (state, socket) => ({
    type: 'div',
    props: {
      className: 'player-controls'
    },
    children: [
      {
        type: 'div',
        props: {
          className: 'playback-controls'
        },
        children: [
          {
            type: 'button',
            props: {
              className: `play-pause-btn ${state.isPlaying ? 'playing' : ''}`,
              onClick: () => {
                socket.emit('player:togglePlayback');
              }
            }
          }
        ]
      },
      {
        type: 'div',
        props: {
          className: 'progress-bar'
        },
        children: [
          {
            type: 'div',
            props: {
              className: 'progress',
              style: {
                width: `${(state.currentTime / state.duration) * 100}%`
              }
            }
          },
          {
            type: 'input',
            props: {
              type: 'range',
              min: 0,
              max: state.duration,
              value: state.currentTime,
              onChange: (e) => {
                socket.emit('player:seek', { time: Number(e.target.value) });
              }
            }
          }
        ]
      },
      {
        type: 'div',
        props: {
          className: 'volume-control'
        },
        children: [
          {
            type: 'button',
            props: {
              className: `volume-btn ${state.isMuted ? 'muted' : ''}`,
              onClick: () => {
                socket.emit('player:toggleMute');
              }
            }
          },
          {
            type: 'input',
            props: {
              type: 'range',
              min: 0,
              max: 1,
              step: 0.01,
              value: state.volume,
              onChange: (e) => {
                socket.emit('player:volume', { level: Number(e.target.value) });
              }
            }
          }
        ]
      }
    ]
  })
};
