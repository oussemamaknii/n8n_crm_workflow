#!/bin/bash

# TalentAI n8n Contact Workflow Setup Script
# Ensures all preconditions are met before starting the workflow

set -e

echo "🚀 TalentAI Contact Workflow Setup"
echo "=================================="

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running. Please start Docker."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

echo "✅ Docker and Docker Compose are available"

# Check if required directories exist
if [ ! -d "init-db" ]; then
    echo "📁 Creating init-db directory..."
    mkdir -p init-db
fi

if [ ! -d "n8n-workflows" ]; then
    echo "📁 Creating n8n-workflows directory..."
    mkdir -p n8n-workflows
fi

echo "✅ Required directories exist"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found. Using default configuration."
    echo "   Please configure your CRM API keys and webhook URLs in .env file"
fi

echo "✅ Environment configuration checked"

# Start the infrastructure
echo "🐳 Starting Docker containers..."
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    docker compose up -d
fi

echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check service health
echo "🔍 Checking service health..."

# Check PostgreSQL
if docker exec talentai_postgres pg_isready -U n8n_user -d talentai &> /dev/null; then
    echo "✅ PostgreSQL is ready"
else
    echo "❌ PostgreSQL is not ready. Check logs: docker logs talentai_postgres"
    exit 1
fi

# Check n8n
if curl -s http://localhost:5678/healthz &> /dev/null; then
    echo "✅ n8n is ready"
else
    echo "❌ n8n is not ready. Check logs: docker logs talentai_n8n"
    exit 1
fi

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Next Steps:"
echo "   1. Access n8n UI: http://localhost:5678"
echo "      Username: admin"
echo "      Password: talentai_admin_123"
echo ""
echo "   2. Configure your CRM API credentials in n8n"
echo ""
echo "   3. Import the contacts workflow from n8n-workflows/"
echo ""
echo "   4. Update .env file with your actual API keys and webhook URLs"
echo ""
echo "🔧 Useful Commands:"
echo "   - View logs: docker-compose logs -f"
echo "   - Stop services: docker-compose down"
echo "   - Database console: docker exec -it talentai_postgres psql -U n8n_user -d talentai"
echo ""


