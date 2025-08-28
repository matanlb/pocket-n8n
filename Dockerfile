# Use the official n8n image as base
FROM n8nio/n8n:latest

# Set environment variables for production
ENV NODE_ENV=production
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=https
ENV N8N_LOG_LEVEL=info

# Use existing node user for security (UID/GID 1000)
USER root

# Create necessary directories and set permissions for node user
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node/.n8n && \
    chmod 755 /home/node/.n8n

# Install curl for health checks
RUN apk add --no-cache curl

# Switch to non-root user
USER node

# Set working directory
WORKDIR /home/node

# Expose the port n8n runs on
EXPOSE 5678

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:5678/ || exit 1

# Use the original entrypoint and command from base image