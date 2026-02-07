# MeDUSA Backend Dockerfile
#
# Multi-stage build for optimized production image with security best practices.
#
# Build:
#   docker build -t medusa-backend:latest .
#
# Run:
#   docker run -p 8000:8000 -e JWT_SECRET=your-secret medusa-backend:latest

# =============================================================================
# Stage 1: Builder
# =============================================================================
FROM python:3.12-slim as builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# =============================================================================
# Stage 2: Production
# =============================================================================
FROM python:3.12-slim as production

# Labels
LABEL maintainer="MeDUSA Team" \
      version="1.0" \
      description="MeDUSA Medical Device Security Assessment Platform - Backend API" \
      org.opencontainers.image.source="https://github.com/EM0V0/MeDUSA"

# Security: Create non-root user
RUN groupadd --gid 1000 medusa && \
    useradd --uid 1000 --gid 1000 --shell /bin/bash --create-home medusa

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    # Default to secure mode
    SECURITY_MODE=secure \
    EDUCATIONAL_LOGGING=false

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=medusa:medusa . .

# Security: Remove unnecessary files
RUN rm -rf \
    __pycache__ \
    *.pyc \
    .git \
    .env* \
    tests/ \
    *.md \
    Dockerfile \
    .dockerignore

# Switch to non-root user
USER medusa

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
# Using uvicorn directly for production (Mangum is for Lambda)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]

# =============================================================================
# Security Notes
# =============================================================================
#
# This Dockerfile follows security best practices:
#
# 1. Multi-stage build: Reduces final image size, excludes build tools
# 2. Non-root user: Application runs as 'medusa' user, not root
# 3. Minimal base image: python:3.12-slim has fewer packages/vulnerabilities
# 4. No cache: PIP_NO_CACHE_DIR reduces image size and attack surface
# 5. Health check: Enables container orchestration health monitoring
# 6. Clean build: Removes unnecessary files from final image
#
# Environment variables required:
# - JWT_SECRET: 256-bit secret for JWT signing (REQUIRED)
# - HMAC_SECRET: Secret for nonce HMAC (defaults to JWT_SECRET)
# - SECURITY_MODE: secure|insecure|educational (default: secure)
#
# =============================================================================
