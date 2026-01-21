# AWS EC2 Web Application with Oracle XE 21c Database

This Terraform configuration deploys a Flask web application connected to Oracle XE 21c database on AWS EC2 instances.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                          VPC                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Public Subnet                      │    │
│  │                                                      │    │
│  │   ┌─────────────┐          ┌─────────────────────┐  │    │
│  │   │  App Server │          │  Oracle XE Server   │  │    │
│  │   │  (Flask)    │──────────│  (Oracle 21c XE)    │  │    │
│  │   │  Port 5000  │  Port    │  Port 1521          │  │    │
│  │   │  t2.micro   │  1521    │  t3.medium          │  │    │
│  │   └─────────────┘          └─────────────────────┘  │    │
│  │                                                      │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Key Differences from MariaDB Version

| Feature | MariaDB Version | Oracle XE Version |
|---------|-----------------|-------------------|
| Database Port | 3306 | 1521 |
| Min Instance Type | t2.micro | t3.medium |
| Min Storage | 8GB | 20GB |
| Python Library | mysql-connector-python | oracledb (thin mode) |
| Service Name | N/A | XEPDB1 |
| EM Web Console | N/A | Port 5500 |
| Recommended AMI | Amazon Linux 2 | Oracle Linux 8 |

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0.0
3. **Terraform Cloud** account (or modify backend configuration)
4. **SSH Key Pair** created in AWS
5. **Oracle XE Requirements**:
   - Minimum t3.medium instance (2 vCPU, 4GB RAM)
   - Minimum 20GB storage
   - Oracle XE 21c is FREE but has limits:
     - 2 CPUs
     - 2GB RAM for database
     - 12GB user data storage

## Quick Start

### 1. Configure Terraform Cloud Backend

Edit `main.tf` and update:
```hcl
cloud {
  organization = "YOUR_ORG_NAME"
  workspaces {
    name = "aws-app-oracle-db"
  }
}
```

### 2. Create Variables File

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
key_name    = "your-ssh-key-name"
db_password = "YourSecurePassword123"
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply configuration
terraform apply
```

### 4. Access Application

After deployment completes (~10-15 minutes for Oracle XE setup):

```bash
# Get outputs
terraform output

# Open application
open http://<app_public_ip>:5000

# SSH to servers
ssh -i ~/.ssh/your-key.pem ec2-user@<app_public_ip>
ssh -i ~/.ssh/your-key.pem ec2-user@<db_public_ip>
```

## Oracle XE Connection Details

| Parameter | Value |
|-----------|-------|
| Host | DB Server Private IP |
| Port | 1521 |
| Service Name | XEPDB1 |
| Username | appuser (configurable) |

### Connection Strings

**Python (oracledb)**:
```python
import oracledb
conn = oracledb.connect(
    user="appuser",
    password="your_password",
    dsn="<db_private_ip>:1521/XEPDB1"
)
```

**JDBC**:
```
jdbc:oracle:thin:@<db_private_ip>:1521/XEPDB1
```

**SQL*Plus**:
```bash
sqlplus appuser/your_password@<db_private_ip>:1521/XEPDB1
```

## Sample Data

The deployment automatically creates and seeds these tables:

### Users Table
| Column | Type | Description |
|--------|------|-------------|
| user_id | NUMBER (PK) | Auto-increment ID |
| name | VARCHAR2(100) | User's full name |
| email | VARCHAR2(100) | Unique email |
| created_at | TIMESTAMP | Creation timestamp |

### Orders Table
| Column | Type | Description |
|--------|------|-------------|
| order_id | NUMBER (PK) | Auto-increment ID |
| user_id | NUMBER (FK) | Reference to users |
| product | VARCHAR2(200) | Product name |
| amount | NUMBER(10,2) | Order amount |
| order_date | TIMESTAMP | Order timestamp |

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | Web UI showing users and orders |
| `GET /api/users` | JSON list of all users |
| `GET /api/orders` | JSON list of all orders |
| `GET /api/db-info` | Oracle database information |
| `GET /health` | Health check endpoint |

## Troubleshooting

### Check Setup Logs
```bash
# App server
ssh -i key.pem ec2-user@<app_ip> "sudo cat /var/log/user-data.log"

# DB server
ssh -i key.pem ec2-user@<db_ip> "sudo cat /var/log/user-data.log"
```

### Check Oracle Status
```bash
ssh -i key.pem ec2-user@<db_ip>

# Check service
sudo systemctl status oracle-xe-21c

# Check listener
sudo su - oracle -c "lsnrctl status"

# Test connection
sudo su - oracle -c "sqlplus / as sysdba <<< 'SELECT status FROM v\$instance;'"
```

### Check Flask App
```bash
ssh -i key.pem ec2-user@<app_ip>

# Check service
sudo systemctl status flask-app

# View logs
sudo journalctl -u flask-app -f
```

### Common Issues

1. **Oracle XE installation takes too long**: Oracle XE setup can take 10-15 minutes. Check user-data.log for progress.

2. **Connection refused on port 1521**: Listener might not be started. Run:
   ```bash
   sudo su - oracle -c "lsnrctl start"
   ```

3. **ORA-01017: invalid username/password**: Verify password meets Oracle requirements (8+ chars, uppercase, lowercase, number).

4. **Instance type too small**: Oracle XE requires minimum t3.medium. t2.micro will fail.

## Security Considerations

1. **Restrict SSH Access**: Update `ssh_allowed_cidr` to your IP
2. **Use Private Subnet**: For production, place DB in private subnet
3. **Rotate Passwords**: Change default passwords after deployment
4. **Enable Encryption**: EBS volumes are encrypted by default
5. **Update Security Groups**: Limit DB access to app server only

## Cost Estimation

| Resource | Instance Type | Monthly Cost (approx) |
|----------|--------------|----------------------|
| App Server | t2.micro | ~$8.50 |
| DB Server | t3.medium | ~$30.00 |
| EBS Storage | 38GB gp3 | ~$3.00 |
| **Total** | | **~$41.50/month** |

*Costs vary by region. Oracle XE license is FREE.*

## Clean Up

```bash
terraform destroy
```

## Module Structure

```
terraform-service-catalog/
├── modules/
│   ├── ec2-app/        # Flask application server
│   ├── ec2-db/         # Oracle XE database server
│   ├── iam/            # IAM roles and policies
│   ├── security/       # Security groups
│   └── vpc/            # VPC and networking
└── services/
    └── aws-app-db-oracle/  # Main service configuration
```

## License

MIT License - See LICENSE file for details.

Oracle XE is free to use under Oracle's license terms.

