################################################################################
# EC2 App Module - Application Server
# Installs Flask application with Oracle XE connectivity via user_data
################################################################################

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x

    echo "=== Starting App Server Setup (Oracle XE Client) ==="
    echo "Start time: $(date)"

    # Update system
    yum update -y

    #---------------------------------------------------------------------------
    # Install Python 3 and Development Tools
    #---------------------------------------------------------------------------
    echo "=== Installing Python 3 and Dependencies ==="
    yum install -y python3 python3-pip python3-devel gcc wget unzip libaio

    #---------------------------------------------------------------------------
    # Install Oracle Instant Client (Required for oracledb Python library)
    #---------------------------------------------------------------------------
    echo "=== Installing Oracle Instant Client ==="
    
    cd /tmp
    
    # Download Oracle Instant Client Basic and SQL*Plus packages
    # Note: These are the official Oracle download URLs
    ORACLE_VERSION="21_14"
    
    # Install from Oracle Linux repo (recommended method)
    yum install -y oracle-release-el7 2>/dev/null || true
    yum install -y oracle-instantclient-release-el7 2>/dev/null || true
    yum install -y oracle-instantclient-basic oracle-instantclient-sqlplus 2>/dev/null
    
    # If yum install fails, download directly
    if [ $? -ne 0 ]; then
      echo "Downloading Oracle Instant Client directly..."
      
      # Create directory
      mkdir -p /opt/oracle
      cd /opt/oracle
      
      # Download instant client basic lite (smaller footprint)
      wget -q https://download.oracle.com/otn_software/linux/instantclient/2114000/instantclient-basiclite-linux.x64-21.14.0.0.0dbru.zip \
        -O instantclient-basic.zip || \
      wget -q https://download.oracle.com/otn_software/linux/instantclient/219000/instantclient-basiclite-linux.x64-21.9.0.0.0dbru.zip \
        -O instantclient-basic.zip
      
      unzip -o instantclient-basic.zip
      rm -f instantclient-basic.zip
      
      # Find and set up the instant client directory
      INSTANT_CLIENT_DIR=$(find /opt/oracle -maxdepth 1 -type d -name "instantclient*" | head -1)
      
      if [ -n "$INSTANT_CLIENT_DIR" ]; then
        ln -sf $INSTANT_CLIENT_DIR /opt/oracle/instantclient
        
        # Configure library path
        echo "$INSTANT_CLIENT_DIR" > /etc/ld.so.conf.d/oracle-instantclient.conf
        ldconfig
      fi
    fi

    # Set Oracle environment variables
    cat > /etc/profile.d/oracle-client.sh <<'ORAENV'
export ORACLE_HOME=/usr/lib/oracle/21/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export PATH=$ORACLE_HOME/bin:$PATH
# For Python oracledb in thin mode, these aren't strictly required
# but helpful for debugging with sqlplus
ORAENV

    source /etc/profile.d/oracle-client.sh 2>/dev/null || true

    #---------------------------------------------------------------------------
    # Install Python Oracle Database Driver (oracledb - thin mode)
    #---------------------------------------------------------------------------
    echo "=== Installing Python Oracle DB Driver ==="
    
    # Install oracledb (successor to cx_Oracle, supports thin mode - no instant client needed!)
    pip3 install oracledb flask gunicorn

    #---------------------------------------------------------------------------
    # Create Flask Application
    #---------------------------------------------------------------------------
    echo "=== Creating Flask Application ==="
    
    mkdir -p /opt/flask-app

    cat > /opt/flask-app/app.py <<'FLASKAPP'
#!/usr/bin/env python3
"""
Flask Application - Connected to Oracle XE 21c
Displays Users and Orders from database
Uses python-oracledb in thin mode (no Oracle Client required!)
"""
from flask import Flask, jsonify, render_template_string
import oracledb
import os

app = Flask(__name__)

# Database configuration
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', '${var.db_host}'),
    'port': int(os.environ.get('DB_PORT', '1521')),
    'service_name': os.environ.get('DB_SERVICE', 'XEPDB1'),
    'user': os.environ.get('DB_USER', '${var.db_user}'),
    'password': os.environ.get('DB_PASSWORD', '${var.db_password}')
}

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Flask App - AWS + Oracle XE</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; }
        h1 { color: #333; border-bottom: 2px solid #c74634; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .status { padding: 15px; border-radius: 5px; margin: 20px 0; }
        .success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; background: white; }
        th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
        th { background: #c74634; color: white; }
        tr:nth-child(even) { background: #f9f9f9; }
        .info { background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #c74634; }
        .oracle-logo { color: #c74634; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Flask Application on AWS with <span class="oracle-logo">Oracle XE</span></h1>
        
        <div class="info">
            <strong>Database Connection:</strong> {{ db_host }}:1521/{{ db_service }}<br>
            <strong>Database Type:</strong> Oracle XE 21c (Express Edition)
        </div>
        
        {% if error %}
        <div class="status error">
            <strong>Error:</strong> {{ error }}
        </div>
        {% else %}
        <div class="status success">
            <strong>✓ Connected to Oracle XE successfully!</strong>
        </div>
        {% endif %}

        <h2>👥 Users ({{ users|length }} records)</h2>
        {% if users %}
        <table>
            <tr><th>ID</th><th>Name</th><th>Email</th><th>Created</th></tr>
            {% for user in users %}
            <tr>
                <td>{{ user[0] }}</td>
                <td>{{ user[1] }}</td>
                <td>{{ user[2] }}</td>
                <td>{{ user[3] }}</td>
            </tr>
            {% endfor %}
        </table>
        {% else %}
        <p>No users found.</p>
        {% endif %}

        <h2>📦 Orders ({{ orders|length }} records)</h2>
        {% if orders %}
        <table>
            <tr><th>Order ID</th><th>User ID</th><th>Product</th><th>Amount</th><th>Date</th></tr>
            {% for order in orders %}
            <tr>
                <td>{{ order[0] }}</td>
                <td>{{ order[1] }}</td>
                <td>{{ order[2] }}</td>
                <td>${{ "%.2f"|format(order[3]) }}</td>
                <td>{{ order[4] }}</td>
            </tr>
            {% endfor %}
        </table>
        {% else %}
        <p>No orders found.</p>
        {% endif %}
    </div>
</body>
</html>
"""

def get_db_connection():
    """Create Oracle database connection using thin mode (no Oracle Client needed)"""
    dsn = f"{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['service_name']}"
    return oracledb.connect(
        user=DB_CONFIG['user'],
        password=DB_CONFIG['password'],
        dsn=dsn
    )

@app.route('/')
def index():
    users = []
    orders = []
    error = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM users ORDER BY user_id")
        users = cursor.fetchall()
        
        cursor.execute("SELECT * FROM orders ORDER BY order_id")
        orders = cursor.fetchall()
        
        cursor.close()
        conn.close()
    except Exception as e:
        error = str(e)
    
    return render_template_string(
        HTML_TEMPLATE,
        users=users,
        orders=orders,
        error=error,
        db_host=DB_CONFIG['host'],
        db_service=DB_CONFIG['service_name']
    )

@app.route('/api/users')
def api_users():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT user_id, name, email, created_at FROM users")
        columns = [col[0].lower() for col in cursor.description]
        users = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return jsonify(users)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/orders')
def api_orders():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT order_id, user_id, product, amount, order_date FROM orders")
        columns = [col[0].lower() for col in cursor.description]
        orders = [dict(zip(columns, row)) for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return jsonify(orders)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1 FROM DUAL")
        cursor.close()
        conn.close()
        return jsonify({'status': 'healthy', 'database': 'Oracle XE connected'})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

@app.route('/api/db-info')
def db_info():
    """Return Oracle database information"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get Oracle version
        cursor.execute("SELECT banner FROM v$version WHERE ROWNUM = 1")
        version = cursor.fetchone()[0]
        
        # Get current user
        cursor.execute("SELECT USER FROM DUAL")
        current_user = cursor.fetchone()[0]
        
        # Get database name
        cursor.execute("SELECT ora_database_name FROM DUAL")
        db_name = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'database_type': 'Oracle XE',
            'version': version,
            'current_user': current_user,
            'database_name': db_name,
            'host': DB_CONFIG['host'],
            'port': DB_CONFIG['port'],
            'service': DB_CONFIG['service_name']
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=${var.app_port}, debug=True)
FLASKAPP

    #---------------------------------------------------------------------------
    # Create Systemd Service
    #---------------------------------------------------------------------------
    echo "=== Creating Systemd Service ==="
    
    cat > /etc/systemd/system/flask-app.service <<SYSTEMD
[Unit]
Description=Flask Application with Oracle XE
After=network.target

[Service]
User=root
WorkingDirectory=/opt/flask-app
Environment="DB_HOST=${var.db_host}"
Environment="DB_PORT=1521"
Environment="DB_SERVICE=XEPDB1"
Environment="DB_USER=${var.db_user}"
Environment="DB_PASSWORD=${var.db_password}"
ExecStart=/usr/local/bin/gunicorn -w 2 -b 0.0.0.0:${var.app_port} app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD

    # Reload systemd and start service
    systemctl daemon-reload
    systemctl enable flask-app
    systemctl start flask-app

    echo "=== App Server Setup Complete ==="
    echo "End time: $(date)"
    echo ""
    echo "Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):${var.app_port}"
  EOF

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.app_name}"
    Role = "Application"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "app" {
  count    = var.create_eip ? 1 : 0
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.app_name}-eip"
  })
}

