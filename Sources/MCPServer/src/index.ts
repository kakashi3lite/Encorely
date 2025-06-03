import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { PersonalityCard } from './components/PersonalityCard';
import { MoodCard } from './components/MoodCard';
import { AudioVisualization } from './components/AudioVisualization';
import { PlayerControls } from './components/PlayerControls';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const components = {
  PersonalityCard,
  MoodCard,
  AudioVisualization,
  PlayerControls
};

io.on('connection', (socket) => {
  console.log('Client connected');

  // Send initial component states
  socket.emit('components:register', components);

  // Handle component events
  socket.on('personality:hover', (data) => {
    socket.broadcast.emit('personality:stateUpdate', data);
  });

  socket.on('personality:select', (data) => {
    socket.broadcast.emit('personality:stateUpdate', { ...data, active: true });
  });

  socket.on('mood:select', (data) => {
    socket.broadcast.emit('mood:stateUpdate', { ...data, active: true });
  });

  socket.on('player:togglePlayback', () => {
    socket.broadcast.emit('player:stateUpdate', { type: 'togglePlayback' });
  });

  socket.on('player:seek', (data) => {
    socket.broadcast.emit('player:stateUpdate', { type: 'seek', ...data });
  });

  socket.on('player:volume', (data) => {
    socket.broadcast.emit('player:stateUpdate', { type: 'volume', ...data });
  });

  socket.on('player:toggleMute', () => {
    socket.broadcast.emit('player:stateUpdate', { type: 'toggleMute' });
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
});

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`MCP Server running on port ${PORT}`);
});