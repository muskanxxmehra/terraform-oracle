################################################################################
# EC2 DB Module - Oracle XE 21c Database Server
# Installs and configures Oracle XE via user_data
# Placed in PUBLIC subnet for internet access
################################################################################

resource "aws_instance" "db" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x

    echo "=== Starting Oracle XE 21c Database Server Setup ==="
    echo "Start time: $(date)"

    # Update system
    yum update -y

    #---------------------------------------------------------------------------
    # Install Oracle XE 21c Prerequisites
    #---------------------------------------------------------------------------
    echo "=== Installing Oracle XE Prerequisites ==="
    
    # Install required packages
    yum install -y oracle-database-preinstall-21c wget libaio bc flex

    # If preinstall package not available, install manually
    if [ $? -ne 0 ]; then
      echo "Installing prerequisites manually..."
      yum install -y bc binutils compat-openssl10 elfutils-libelf \
        elfutils-libelf-devel fontconfig-devel glibc glibc-devel \
        ksh libaio libaio-devel libgcc libnsl librdmacm libstdc++ \
        libstdc++-devel libX11 libXau libxcb libXi libXrender \
        libXtst make net-tools nfs-utils smartmontools sysstat \
        targetcli unzip
      
      # Create oracle user and groups if not exists
      groupadd -g 54321 oinstall 2>/dev/null || true
      groupadd -g 54322 dba 2>/dev/null || true
      groupadd -g 54323 oper 2>/dev/null || true
      groupadd -g 54324 backupdba 2>/dev/null || true
      groupadd -g 54325 dgdba 2>/dev/null || true
      groupadd -g 54326 kmdba 2>/dev/null || true
      groupadd -g 54327 racdba 2>/dev/null || true
      useradd -u 54321 -g oinstall -G dba,oper,backupdba,dgdba,kmdba,racdba oracle 2>/dev/null || true
    fi

    #---------------------------------------------------------------------------
    # Download and Install Oracle XE 21c
    #---------------------------------------------------------------------------
    echo "=== Downloading Oracle XE 21c ==="
    
    cd /tmp
    
    # Download Oracle XE 21c RPM (using Oracle's official download)
    # Note: For production, you should host this RPM in your own S3 bucket
    wget -q https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm \
      -O oracle-database-xe-21c.rpm || \
    wget -q https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-21c-1.0-1.ol7.x86_64.rpm \
      -O oracle-database-xe-21c.rpm

    # If direct download fails, try alternate method
    if [ ! -f oracle-database-xe-21c.rpm ] || [ ! -s oracle-database-xe-21c.rpm ]; then
      echo "Trying alternate Oracle XE download..."
      # Install from Oracle Linux repo
      yum install -y oracle-database-xe-21c || {
        echo "ERROR: Could not download Oracle XE. Please ensure RPM is available."
        echo "You may need to manually download from Oracle and place in S3."
        exit 1
      }
    else
      # Install the downloaded RPM
      echo "=== Installing Oracle XE 21c RPM ==="
      yum localinstall -y oracle-database-xe-21c.rpm
    fi

    #---------------------------------------------------------------------------
    # Configure Oracle XE
    #---------------------------------------------------------------------------
    echo "=== Configuring Oracle XE 21c ==="
    
    # Create response file for silent configuration
    cat > /etc/sysconfig/oracle-xe-21c.conf <<ORACONF
ORACLE_SID=XE
LISTENER_PORT=1521
EM_EXPRESS_PORT=5500
CHARSET=AL32UTF8
DBFILE_DEST=/opt/oracle/oradata
ORACLE_PASSWORD=${var.db_password}
SKIP_VALIDATIONS=false
ORACONF

    # Run Oracle XE configuration
    /etc/init.d/oracle-xe-21c configure

    # Set Oracle environment variables
    cat >> /etc/profile.d/oracle.sh <<'ORAENV'
export ORACLE_SID=XE
export ORAENV_ASK=NO
export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export TNS_ADMIN=$ORACLE_HOME/network/admin
ORAENV

    # Source environment
    source /etc/profile.d/oracle.sh

    # Also set for root
    echo 'source /etc/profile.d/oracle.sh' >> /root/.bashrc

    #---------------------------------------------------------------------------
    # Configure Oracle Listener for Remote Connections
    #---------------------------------------------------------------------------
    echo "=== Configuring Oracle Listener ==="
    
    # Update listener.ora to listen on all interfaces
    cat > $ORACLE_HOME/network/admin/listener.ora <<LISTENER
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

DEFAULT_SERVICE_LISTENER = XE
LISTENER

    # Update tnsnames.ora
    cat > $ORACLE_HOME/network/admin/tnsnames.ora <<TNS
XE =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = XEPDB1)
    )
  )

XEPDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = XEPDB1)
    )
  )
TNS

    # Restart listener
    su - oracle -c "lsnrctl stop; lsnrctl start"

    #---------------------------------------------------------------------------
    # Create Application User and Schema
    #---------------------------------------------------------------------------
    echo "=== Creating Application User and Schema ==="
    
    # Wait for database to be ready
    sleep 30

    # Create application user and grant privileges
    su - oracle -c "sqlplus / as sysdba" <<SQLCMD
-- Unlock and set password for HR demo schema (optional)
-- ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;

-- Connect to pluggable database
ALTER SESSION SET CONTAINER = XEPDB1;

-- Create application user
CREATE USER ${var.db_user} IDENTIFIED BY "${var.db_password}"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- Grant privileges
GRANT CONNECT, RESOURCE TO ${var.db_user};
GRANT CREATE SESSION TO ${var.db_user};
GRANT CREATE TABLE TO ${var.db_user};
GRANT CREATE SEQUENCE TO ${var.db_user};
GRANT CREATE VIEW TO ${var.db_user};
GRANT CREATE PROCEDURE TO ${var.db_user};

EXIT;
SQLCMD

    #---------------------------------------------------------------------------
    # Create Tables and Seed Data
    #---------------------------------------------------------------------------
    echo "=== Creating Tables and Seeding Data ==="

    su - oracle -c "sqlplus ${var.db_user}/\"${var.db_password}\"@XEPDB1" <<SQLCMD
-- Create USERS table (Oracle syntax)
CREATE TABLE users (
  user_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name VARCHAR2(100) NOT NULL,
  email VARCHAR2(100) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create ORDERS table (Oracle syntax)
CREATE TABLE orders (
  order_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id NUMBER NOT NULL,
  product VARCHAR2(200) NOT NULL,
  amount NUMBER(10,2) NOT NULL,
  order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Create indexes
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_users_email ON users(email);

-- Seed sample data - USERS
INSERT INTO users (user_id, name, email) VALUES (1, 'Alice Johnson', 'alice@example.com');
INSERT INTO users (user_id, name, email) VALUES (2, 'Bob Smith', 'bob@example.com');
INSERT INTO users (user_id, name, email) VALUES (3, 'Carol Williams', 'carol@example.com');
INSERT INTO users (user_id, name, email) VALUES (4, 'David Brown', 'david@example.com');
INSERT INTO users (user_id, name, email) VALUES (5, 'Eva Martinez', 'eva@example.com');
INSERT INTO users (user_id, name, email) VALUES (6, 'Frank Lee', 'frank@example.com');
INSERT INTO users (user_id, name, email) VALUES (7, 'Grace Kim', 'grace@example.com');
INSERT INTO users (user_id, name, email) VALUES (8, 'Henry Wilson', 'henry@example.com');
INSERT INTO users (user_id, name, email) VALUES (9, 'Iris Chen', 'iris@example.com');
INSERT INTO users (user_id, name, email) VALUES (10, 'Jack Taylor', 'jack@example.com');

-- Seed sample data - ORDERS
INSERT INTO orders (order_id, user_id, product, amount) VALUES (1, 1, 'Laptop Pro 15', 1299.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (2, 1, 'Wireless Mouse', 49.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (3, 2, 'Mechanical Keyboard', 159.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (4, 2, 'Monitor 27 inch', 399.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (5, 3, 'USB-C Hub', 79.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (6, 3, 'Webcam HD', 129.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (7, 4, 'Headphones Wireless', 249.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (8, 5, 'SSD 1TB', 109.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (9, 5, 'RAM 32GB Kit', 149.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (10, 6, 'Graphics Card RTX', 599.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (11, 7, 'Power Supply 750W', 89.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (12, 7, 'PC Case ATX', 119.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (13, 8, 'CPU Cooler', 69.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (14, 9, 'Motherboard Gaming', 289.99);
INSERT INTO orders (order_id, user_id, product, amount) VALUES (15, 10, 'NVMe SSD 2TB', 199.99);

COMMIT;

-- Verify data
SELECT 'Users count: ' || COUNT(*) FROM users;
SELECT 'Orders count: ' || COUNT(*) FROM orders;

EXIT;
SQLCMD

    #---------------------------------------------------------------------------
    # Configure Firewall (if enabled)
    #---------------------------------------------------------------------------
    echo "=== Configuring Firewall ==="
    
    # Open Oracle ports
    firewall-cmd --permanent --add-port=1521/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=5500/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true

    #---------------------------------------------------------------------------
    # Enable Oracle to Start on Boot
    #---------------------------------------------------------------------------
    echo "=== Enabling Oracle Auto-Start ==="
    
    systemctl enable oracle-xe-21c
    systemctl start oracle-xe-21c

    # Clean up
    rm -f /tmp/oracle-database-xe-21c.rpm

    echo "=== Oracle XE 21c Database Server Setup Complete ==="
    echo "End time: $(date)"
    echo ""
    echo "Connection Info:"
    echo "  Host: $(hostname -I | awk '{print $1}')"
    echo "  Port: 1521"
    echo "  Service: XEPDB1"
    echo "  User: ${var.db_user}"
    echo ""
    echo "Connect string: ${var.db_user}/${var.db_password}@$(hostname -I | awk '{print $1}'):1521/XEPDB1"
  EOF

  tags = merge(var.tags, {
    Name     = "${var.environment}-oracle-db-server"
    Role     = "Database"
    Database = "Oracle XE 21c"
  })

  lifecycle {
    create_before_destroy = true
  }
}

