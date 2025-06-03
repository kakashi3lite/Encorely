import express from 'express';
import { Server } from 'socket.io';
import { createServer } from 'http';

export class MCPServer {
    private app = express();
    private server = createServer(this.app);
    private io = new Server(this.server, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST']
        }
    });

    private components = new Map();
    private types = new Map();

    constructor(private config: { port: number }) {
        this.setupMiddleware();
        this.setupSocketHandlers();
    }

    private setupMiddleware() {
        this.app.use(express.json());
        this.app.use(express.static('public'));
    }

    private setupSocketHandlers() {
        this.io.on('connection', (socket) => {
            console.log('Client connected');

            socket.on('requestComponent', (name: string) => {
                const component = this.components.get(name);
                if (component) {
                    socket.emit('component', { name, component });
                }
            });

            socket.on('disconnect', () => {
                console.log('Client disconnected');
            });
        });
    }

    registerComponent(name: string, component: any) {
        this.components.set(name, component);
    }

    registerType(name: string, type: any) {
        this.types.set(name, type);
    }

    async start() {
        return new Promise<void>((resolve) => {
            this.server.listen(this.config.port, () => {
                console.log(`Server running on port ${this.config.port}`);
                resolve();
            });
        });
    }
}