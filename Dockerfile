# Use the official n8n image as base
FROM n8nio/n8n:latest

# Set environment variables for production
ENV NODE_ENV=production
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=https
ENV N8N_LOG_LEVEL=info

# Create non-root user for security
USER root
RUN addgroup -g 1000 n8nuser && \
    adduser -D -s /bin/sh -u 1000 -G n8nuser n8nuser

# Create necessary directories and set permissions
RUN mkdir -p /home/n8nuser/.n8n && \
    chown -R n8nuser:n8nuser /home/n8nuser/.n8n && \
    chmod 755 /home/n8nuser/.n8n

# Install curl for health checks
RUN apk add --no-cache curl

# Switch to non-root user
USER n8nuser

# Set working directory
WORKDIR /home/n8nuser

# Expose the port n8n runs on
EXPOSE 5678

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:5678/ || exit 1

# Start n8n
CMD ["n8n"]