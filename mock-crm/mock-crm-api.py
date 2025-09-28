#!/usr/bin/env python3
"""
Mock CRM API Server for Testing TalentAI Contact Workflow
Simulates HubSpot-like REST API with realistic contact data
"""

import json
import random
import time
from datetime import datetime, timedelta
from flask import Flask, jsonify, request
from faker import Faker

app = Flask(__name__)
fake = Faker('fr_FR')  # French locale for realistic French names/phones

# In-memory storage for demo
contacts_db = []
contact_counter = 1000

def generate_mock_contact():
    """Generate realistic contact data"""
    global contact_counter
    contact_counter += 1
    
    # Realistic phone formats (mix of French formats)
    phone_formats = [
        lambda: f"+33{fake.random_int(min=100000000, max=799999999)}",
        lambda: fake.phone_number(),
        lambda: f"0{fake.random_int(min=100000000, max=799999999)}",
        lambda: f"0{fake.random_int(min=1, max=9)}.{fake.random_int(min=10, max=99)}.{fake.random_int(min=10, max=99)}.{fake.random_int(min=10, max=99)}.{fake.random_int(min=10, max=99)}",
        lambda: f"0{fake.random_int(min=1, max=9)} {fake.random_int(min=10, max=99)} {fake.random_int(min=10, max=99)} {fake.random_int(min=10, max=99)} {fake.random_int(min=10, max=99)}"
    ]
    
    # Company names
    companies = [
        "TechCorp", "DataInc", "InnovateSAS", "DigitalPro", "CloudSystems",
        "AI Solutions", "WebDev Studio", "Analytics Plus", "StartupLab",
        "Enterprise Solutions", "Digital Agency", "Tech Consulting"
    ]
    
    # Job titles
    job_titles = [
        "Développeur Full Stack", "Chef de Projet", "Directeur Marketing",
        "Analyste de Données", "Consultant IT", "Responsable Commercial",
        "Product Owner", "UX Designer", "DevOps Engineer", "Data Scientist"
    ]
    
    # Tags
    tag_options = ["prospect", "client", "lead", "enterprise", "startup", "premium"]
    
    contact = {
        "id": f"mock_crm_{contact_counter}",
        "firstName": fake.first_name(),
        "lastName": fake.last_name().upper(),
        "email": fake.email(),
        "phone": random.choice(phone_formats)(),
        "company": random.choice(companies),
        "jobTitle": random.choice(job_titles),
        "tags": random.sample(tag_options, k=random.randint(1, 3)),
        "createdAt": fake.date_time_between(start_date='-30d', end_date='now').isoformat(),
        "lastModified": datetime.now().isoformat(),
        "source": "website_form",
        "leadScore": random.randint(10, 100),
        "notes": fake.text(max_nb_chars=100)
    }
    
    return contact

# Initialize with some sample data
for _ in range(50):
    contacts_db.append(generate_mock_contact())

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})

@app.route('/api/contacts', methods=['GET'])
def get_contacts():
    """Get contacts with pagination and filtering"""
    # Query parameters
    limit = min(int(request.args.get('limit', 20)), 100)
    offset = int(request.args.get('offset', 0))
    since = request.args.get('since')  # ISO datetime string
    
    # Filter by modification date if provided
    filtered_contacts = contacts_db
    if since:
        try:
            since_dt = datetime.fromisoformat(since.replace('Z', '+00:00'))
            filtered_contacts = [
                c for c in contacts_db 
                if datetime.fromisoformat(c['lastModified']) > since_dt
            ]
        except ValueError:
            return jsonify({"error": "Invalid 'since' date format. Use ISO format."}), 400
    
    # Pagination
    total = len(filtered_contacts)
    contacts = filtered_contacts[offset:offset + limit]
    
    # Response with pagination info
    response = {
        "contacts": contacts,
        "pagination": {
            "total": total,
            "limit": limit,
            "offset": offset,
            "hasMore": offset + limit < total
        },
        "timestamp": datetime.now().isoformat()
    }
    
    return jsonify(response)

@app.route('/api/contacts/<contact_id>', methods=['GET'])
def get_contact(contact_id):
    """Get specific contact by ID"""
    contact = next((c for c in contacts_db if c['id'] == contact_id), None)
    if not contact:
        return jsonify({"error": "Contact not found"}), 404
    
    return jsonify(contact)

@app.route('/api/contacts', methods=['POST'])
def create_contact():
    """Create new contact"""
    data = request.json
    
    # Generate new contact with provided data
    contact = generate_mock_contact()
    if data:
        contact.update({k: v for k, v in data.items() if k != 'id'})
    
    contacts_db.append(contact)
    
    return jsonify(contact), 201


@app.route('/api/contacts/simulate', methods=['POST'])
def simulate_new_contacts():
    """Simulate creation of new contacts for testing"""
    count = int(request.args.get('count', 5))
    
    new_contacts = []
    for _ in range(min(count, 20)):  # Max 20 at once
        contact = generate_mock_contact()
        contacts_db.append(contact)
        new_contacts.append(contact)
    
    return jsonify({
        "message": f"Created {len(new_contacts)} new contacts",
        "contacts": new_contacts
    })

@app.route('/webhook/test', methods=['POST'])
def webhook_endpoint():
    """Test webhook endpoint that could trigger n8n workflow"""
    data = request.json
    
    # Log the webhook payload
    print(f"📨 Webhook received: {json.dumps(data, indent=2)}")
    
    # Simulate webhook response
    response = {
        "received": True,
        "timestamp": datetime.now().isoformat(),
        "payload": data
    }
    
    return jsonify(response)

if __name__ == '__main__':
    print("Starting Mock CRM API Server")
    print("Access at: http://localhost:3000")
    app.run(host='0.0.0.0', port=3000, debug=True)
