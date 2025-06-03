import { Component, ComponentStructure, PersonalityCardProps } from '../../types/components';
import { Socket } from 'socket.io';

interface PersonalityCardState extends PersonalityCardProps {
  isHovered: boolean;
}

export const PersonalityCard: Component<PersonalityCardProps, PersonalityCardState> = {
  name: 'PersonalityCard',
  
  structure: {
    type: 'div',
    props: {
      className: 'personality-card',
    },
    children: [
      {
        type: 'h3',
        props: { className: 'personality-type' }
      },
      {
        type: 'div',
        props: { className: 'personality-traits' }
      },
      {
        type: 'div',
        props: { className: 'personality-strength' }
      }
    ]
  },

  propsToState: (props) => ({
    ...props,
    isHovered: false
  }),

  render: (state, socket) => ({
    type: 'div',
    props: {
      className: `personality-card ${state.active ? 'active' : ''} ${state.isHovered ? 'hovered' : ''}`,
      onMouseEnter: () => {
        socket.emit('personality:hover', { type: state.type, hovered: true });
      },
      onMouseLeave: () => {
        socket.emit('personality:hover', { type: state.type, hovered: false });
      },
      onClick: () => {
        socket.emit('personality:select', { type: state.type });
      }
    },
    children: [
      {
        type: 'h3',
        props: { 
          className: 'personality-type',
          textContent: state.type
        }
      },
      {
        type: 'div',
        props: { 
          className: 'personality-traits'
        },
        children: state.traits.map(trait => ({
          type: 'span',
          props: {
            className: 'trait',
            textContent: trait
          }
        }))
      },
      {
        type: 'div',
        props: {
          className: 'personality-strength',
          style: {
            width: `${state.strength * 100}%`
          }
        }
      }
    ]
  })
};
