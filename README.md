# TalentAI n8n Contact Ingestion Workflow

## 📋 Project Overview

This project implements a robust n8n workflow that automatically ingests contacts from a CRM API, cleanses the data, and stores it in PostgreSQL with comprehensive error handling and monitoring.

### 🎯 Mission Accomplished
✅ Fetches new contacts from CRM API (HubSpot-compatible or mock API)  
✅ Transforms and cleanses data (phone normalization, email validation, name formatting)  
✅ Stores contacts in PostgreSQL with proper indexing  
✅ Sends notifications and logs all operations  
✅ Handles errors with automatic logging and alerting  
✅ Implements idempotent operations (duplicate prevention)  

## 🚀 Quick Start

```bash
# 1. Start the infrastructure
./setup.sh

# 2. Access n8n UI
open http://localhost:5678
# Login: admin / talentai_admin_123

# 3. Import workflow
# File → Import → n8n-workflows/contact-ingestion-workflow.json

# 4. Test with mock data
curl -X POST http://localhost:5678/webhook/contacts-webhook
```

## 🏗️ Architecture Overview

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐
│  CRM API    │───▶│  n8n Engine  │───▶│  PostgreSQL     │───▶│ Notifications│
│ (HubSpot)   │    │              │    │  - contacts     │    │ (Teams/Email)│
│             │    │ Workflow:    │    │  - audit_logs   │    │              │
│ - Webhooks  │    │ • Normalize  │    │  - error_logs   │    │ - Success    │
│ - REST API  │    │ • Validate   │    │                 │    │ - Alerts     │
│ - Polling   │    │ • Dedupe     │    └─────────────────┘    └──────────────┘
└─────────────┘    └──────────────┘
```

## 📊 Data Flow

### 1. Data Ingestion
- **Source**: CRM API (HubSpot, Salesforce, or mock API)
- **Trigger**: Webhook push or scheduled polling (every 5 minutes)
- **Format**: JSON payload with contact information

### 2. Data Transformation
- **Phone Numbers**: Various formats → E.164 international format
  ```
  "06 12 34 56 78" → "+33612345678"
  "+33 1 23 45 67 89" → "+33123456789" 
  "01.23.45.67.89" → "+33123456789"
  ```
- **Email Addresses**: Normalization and validation
  ```
  "Jean.Dupont@EXAMPLE.COM" → "jean.dupont@example.com"
  ```
- **Names**: Consistent uppercase formatting
  ```
  "jean dupont" → "JEAN DUPONT"
  ```

### 3. Database Storage
**contacts** table:
```sql
CREATE TABLE contacts (
    id                  BIGSERIAL PRIMARY KEY,
    uuid                UUID DEFAULT uuid_generate_v4(),
    crm_id              VARCHAR(64) UNIQUE NOT NULL,
    first_name          TEXT,
    last_name           TEXT,
    full_name           TEXT GENERATED ALWAYS AS (...) STORED,
    email               CITEXT,
    phone_e164          VARCHAR(20),
    phone_raw           TEXT,
    company             TEXT,
    job_title           TEXT,
    tags                TEXT[],
    raw_payload         JSONB,
    source              VARCHAR(50) DEFAULT 'n8n_workflow',
    status              VARCHAR(20) DEFAULT 'active',
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    processed_at        TIMESTAMPTZ DEFAULT NOW()
);
```

## 🛡️ Security & Best Practices

### ✅ Applied Best Practices
1. **Security**
   - Environment variables for sensitive data
   - Parameterized SQL queries (no injection risks)
   - Basic authentication for n8n UI
   - Database user with limited privileges

2. **Performance**
   - Database indexes on key fields (crm_id, email, phone)
   - Generated computed fields for optimized queries
   - Batch processing capability
   - Connection pooling via Docker networking

3. **Reliability**
   - Idempotent operations (duplicate prevention)
   - Comprehensive error logging
   - Transaction-safe database operations
   - Health checks for all services

4. **Observability**
   - Structured logging in PostgreSQL
   - Processing metrics and status tracking
   - Execution correlation with workflow IDs
   - Raw payload preservation for debugging

## 🔍 Monitoring & Alerts

### Key Performance Indicators
```sql
-- Success rate monitoring
SELECT 
  status,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as percentage
FROM contact_processing_log 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY status;

-- Processing throughput
SELECT 
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(*) as contacts_processed
FROM contact_processing_log 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;
```

### Alerting Strategy
- **Error Rate**: Alert if >5% of contacts fail processing
- **Duplicate Rate**: Monitor for unusual duplicate patterns
- **Processing Lag**: Alert if queue backlog exceeds 1 hour
- **Database Health**: Monitor connection pool and query performance

## ⚡ Scalability Roadmap

### Current Capacity: ~1,000 contacts/day
- Single n8n instance
- PostgreSQL on single container
- Synchronous processing

### Scaling to 100,000 contacts/day

#### 1. Horizontal Scaling
```yaml
# docker-compose.scale.yml
services:
  n8n-worker:
    image: n8nio/n8n:latest
    replicas: 3
    environment:
      - N8N_EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
```

#### 2. Database Optimization
- **Partitioning**: Partition contacts table by date
- **Read Replicas**: Separate read/write workloads
- **Connection Pooling**: PgBouncer for connection management
- **Batch Processing**: Process 100+ contacts per workflow run

#### 3. Infrastructure Architecture
```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐
│  Load       │    │  n8n Workers │    │  PostgreSQL     │
│  Balancer   │────┤  (3 replicas)│────│  Primary +      │
│  (nginx)    │    │              │    │  Read Replicas  │
└─────────────┘    │  Redis Queue │    └─────────────────┘
                   └──────────────┘
```

#### 4. Cost Estimation (100k/day)
- **Kubernetes Cluster**: 3 nodes × $50/month = $150/month
- **Managed PostgreSQL**: $80/month
- **Redis Cache**: $30/month
- **Monitoring Stack**: $40/month
- **Total**: ~$300/month

## 🧪 Testing

### Unit Tests
```bash
# Test phone normalization
echo '{"phone": "06 12 34 56 78"}' | curl -X POST http://localhost:3000/test/normalize

# Test duplicate detection
docker exec talentai_postgres psql -U n8n_user -d talentai -c \
  "SELECT COUNT(*) FROM contacts WHERE crm_id = 'test_duplicate';"
```

### Integration Tests
```bash
# End-to-end workflow test
curl -X POST http://localhost:5678/webhook/contacts-webhook \
  -H "Content-Type: application/json" \
  -d '{"test_data": true, "contacts": [{"id": "test_123", "firstName": "Test", "email": "test@example.com"}]}'
```

## 📁 Project Structure

```
talentai_homework/
├── 📄 README.md                          # This file
├── 📄 aplan.txt                          # Step-by-step project plan
├── 📄 requirements.txt                   # Original project requirements
├── 🐳 docker-compose.yml                 # Infrastructure definition
├── 📄 .env                              # Environment variables
├── 🚀 setup.sh                          # One-click setup script
├── 🐍 mock-crm-api.py                   # Test CRM API server
├── 📄 preconditions-checklist.md        # Environment requirements
├── 📁 init-db/
│   └── 📄 01-create-schema.sql          # Database schema
├── 📁 n8n-workflows/
│   └── 📄 contact-ingestion-workflow.json # Main n8n workflow
├── 📄 n8n-workflow-setup.md             # Workflow setup guide
└── 📄 improvements.md                    # Scaling recommendations
```

## 🤝 Contributing

### Development Setup
1. Clone repository
2. Run `./setup.sh`
3. Import workflow into n8n
4. Configure credentials
5. Test with mock data

### Workflow Modifications
1. Export changes from n8n UI
2. Save to `n8n-workflows/` directory
3. Update documentation
4. Test thoroughly

## 🔧 Troubleshooting

### Common Issues

**n8n not accessible**
```bash
docker logs talentai_n8n
curl http://localhost:5678/healthz
```

**Database connection fails**
```bash
docker exec talentai_postgres pg_isready -U n8n_user -d talentai
```

**Workflow execution errors**
```sql
SELECT * FROM contact_processing_log WHERE status = 'error' ORDER BY created_at DESC LIMIT 5;
```

**Mock API not responding**
```bash
curl http://localhost:3000/health
# Restart if needed: python3 mock-crm-api.py
```

## 📞 Support

For questions or issues:
1. Check the troubleshooting section above
2. Review logs in `contact_processing_log` table
3. Verify all services are healthy: `docker ps`
4. Test individual components separately

---

**🎯 Project Status**: ✅ **COMPLETE**  
**📊 Test Coverage**: Functional workflow with comprehensive error handling  
**🚀 Production Ready**: With scaling recommendations for 100k+ contacts/day  
**📈 Monitoring**: Database-driven metrics and alerting ready  


