# Caption Stable - Docker Deployment

This document provides instructions for running the Caption Stable application in a Docker container based on Ubuntu 20.04.

## Prerequisites

- Docker installed on your system
- Docker Compose installed
- Azure Speech Services API key

## Quick Start

1. **Clone or download the application files**

2. **Set up environment variables**
   ```bash
   # Create .env file (or run the docker-run.sh script which will create it for you)
   cp .env.example .env
   # Edit .env and add your Azure Speech Services key
   ```

3. **Run the application**
   ```bash
   # Option 1: Use the convenience script
   ./docker-run.sh
   
   # Option 2: Use docker-compose directly
   docker-compose up --build -d
   ```

4. **Access the application**
   - Main application: http://localhost:8000
   - Dashboard: http://localhost:8000/dashboard
   - User view: http://localhost:8000/user

## Configuration

### Environment Variables

Create a `.env` file in the project root with the following variables:

```env
# Azure Speech Services Configuration
AZURE_SPEECH_KEY=your_azure_speech_key_here
AZURE_SPEECH_REGION=eastus

# Application Configuration
DEBUG_MODE=false
```

### Azure Speech Services Setup

1. Go to [Azure Portal](https://portal.azure.com)
2. Create a Speech Services resource
3. Copy the key and region from the resource
4. Add them to your `.env` file

## Docker Commands

### Build and Run
```bash
# Build and start in background
docker-compose up --build -d

# Build and start in foreground (see logs)
docker-compose up --build

# Start without rebuilding
docker-compose up -d
```

### Management
```bash
# View logs
docker-compose logs -f

# Stop the application
docker-compose down

# Restart the application
docker-compose restart

# View running containers
docker-compose ps
```

### Individual Docker Commands
```bash
# Build the image
docker build -t caption-stable .

# Run the container
docker run -d \
  --name caption-stable \
  -p 8000:8000 \
  -e AZURE_SPEECH_KEY=your_key \
  -e AZURE_SPEECH_REGION=eastus \
  -v $(pwd)/config.json:/app/config.json \
  -v $(pwd)/dictionary.json:/app/dictionary.json \
  -v $(pwd)/schedule.json:/app/schedule.json \
  -v $(pwd)/user_settings.json:/app/user_settings.json \
  -v $(pwd)/logs:/app/logs \
  caption-stable
```

## File Structure

The Docker setup includes the following files:

- `Dockerfile` - Container definition based on Ubuntu 20.04
- `docker-compose.yml` - Multi-container orchestration
- `docker-run.sh` - Convenience script for easy deployment
- `.dockerignore` - Files to exclude from Docker build
- `.env` - Environment variables (create this file)

## Volumes

The following files are mounted as volumes for persistence:

- `config.json` - Application configuration
- `dictionary.json` - Dictionary and language settings
- `schedule.json` - Scheduled events
- `user_settings.json` - User preferences
- `logs/` - Application logs

## Troubleshooting

### Port Already in Use
If port 8000 is already in use, modify the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "8001:8000"  # Use port 8001 on host
```

### Permission Issues
If you encounter permission issues:
```bash
# Fix file permissions
chmod +x docker-run.sh
chmod 644 config.json dictionary.json schedule.json user_settings.json
```

### Audio Issues
The container includes audio libraries, but for full audio support, you may need to:
1. Run with `--privileged` flag
2. Mount audio devices: `-v /dev/snd:/dev/snd`
3. Use host networking: `--network host`

### Health Check Failures
If health checks fail:
```bash
# Check container logs
docker-compose logs caption-app

# Check if the application is responding
curl http://localhost:8000/health
```

## Development

### Building for Development
```bash
# Build with development dependencies
docker build -t caption-stable:dev --target development .

# Run with volume mounts for live code changes
docker-compose -f docker-compose.dev.yml up
```

### Debugging
```bash
# Run in interactive mode
docker run -it --rm caption-stable /bin/bash

# Execute commands in running container
docker exec -it caption-stable /bin/bash
```

## Security Considerations

1. **Never commit your `.env` file** - it contains sensitive API keys
2. **Use secrets management** in production environments
3. **Regularly update the base image** for security patches
4. **Run as non-root user** in production (modify Dockerfile)

## Production Deployment

For production deployment:

1. Use a reverse proxy (nginx, traefik)
2. Set up SSL/TLS certificates
3. Configure proper logging
4. Use Docker secrets for sensitive data
5. Set up monitoring and alerting

Example production docker-compose:
```yaml
version: '3.8'
services:
  caption-app:
    build: .
    restart: unless-stopped
    secrets:
      - azure_speech_key
    environment:
      - AZURE_SPEECH_KEY_FILE=/run/secrets/azure_speech_key
    networks:
      - internal

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - caption-app
    networks:
      - internal
      - external

secrets:
  azure_speech_key:
    external: true

networks:
  internal:
    driver: bridge
  external:
    driver: bridge
```

## Support

For issues and questions:
1. Check the application logs: `docker-compose logs -f`
2. Verify your Azure Speech Services configuration
3. Ensure all required files are present and properly configured 