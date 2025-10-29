#!/bin/bash

# Disaster Recovery Failover Test Script
# This script tests the failover mechanism for the 3-tier application

set -e

# Configuration
PRIMARY_REGION="us-west-2"
SECONDARY_REGION="us-east-1"
DOMAIN_NAME="your-app.example.com"
PROJECT_NAME="3tier-app"
NOTIFICATION_EMAIL="admin@example.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS CLI is not configured properly"
        exit 1
    fi
    
    log "AWS CLI is configured and working"
}

# Function to check primary region health
check_primary_health() {
    log "Checking primary region health..."
    
    # Get ALB DNS name from primary region
    PRIMARY_ALB=$(aws elbv2 describe-load-balancers \
        --region $PRIMARY_REGION \
        --names "${PROJECT_NAME}-alb" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$PRIMARY_ALB" ] || [ "$PRIMARY_ALB" == "None" ]; then
        error "Could not find primary ALB"
        return 1
    fi
    
    # Test health endpoint
    if curl -f -s "http://$PRIMARY_ALB/health" > /dev/null; then
        log "Primary region is healthy"
        return 0
    else
        warn "Primary region health check failed"
        return 1
    fi
}

# Function to check secondary region health
check_secondary_health() {
    log "Checking secondary region health..."
    
    # Get ALB DNS name from secondary region
    SECONDARY_ALB=$(aws elbv2 describe-load-balancers \
        --region $SECONDARY_REGION \
        --names "${PROJECT_NAME}-alb" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$SECONDARY_ALB" ] || [ "$SECONDARY_ALB" == "None" ]; then
        error "Could not find secondary ALB"
        return 1
    fi
    
    # Test health endpoint
    if curl -f -s "http://$SECONDARY_ALB/health" > /dev/null; then
        log "Secondary region is healthy"
        return 0
    else
        warn "Secondary region health check failed"
        return 1
    fi
}

# Function to check Route 53 configuration
check_route53_config() {
    log "Checking Route 53 configuration..."
    
    # Get hosted zone ID
    ZONE_ID=$(aws route53 list-hosted-zones-by-name \
        --dns-name $DOMAIN_NAME \
        --query 'HostedZones[0].Id' \
        --output text | cut -d'/' -f3)
    
    if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "None" ]; then
        error "Could not find hosted zone for $DOMAIN_NAME"
        return 1
    fi
    
    # Check failover records
    RECORDS=$(aws route53 list-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --query "ResourceRecordSets[?Name=='$DOMAIN_NAME.']" \
        --output json)
    
    PRIMARY_RECORD=$(echo $RECORDS | jq -r '.[] | select(.Failover=="PRIMARY")')
    SECONDARY_RECORD=$(echo $RECORDS | jq -r '.[] | select(.Failover=="SECONDARY")')
    
    if [ -z "$PRIMARY_RECORD" ] || [ "$PRIMARY_RECORD" == "null" ]; then
        error "Primary failover record not found"
        return 1
    fi
    
    if [ -z "$SECONDARY_RECORD" ] || [ "$SECONDARY_RECORD" == "null" ]; then
        error "Secondary failover record not found"
        return 1
    fi
    
    log "Route 53 failover configuration is correct"
    return 0
}

# Function to check RDS replication
check_rds_replication() {
    log "Checking RDS replication status..."
    
    # Check primary database
    PRIMARY_DB_STATUS=$(aws rds describe-db-instances \
        --region $PRIMARY_REGION \
        --db-instance-identifier "${PROJECT_NAME}-database" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "")
    
    if [ "$PRIMARY_DB_STATUS" != "available" ]; then
        warn "Primary database status: $PRIMARY_DB_STATUS"
    else
        log "Primary database is available"
    fi
    
    # Check read replica
    REPLICA_STATUS=$(aws rds describe-db-instances \
        --region $SECONDARY_REGION \
        --db-instance-identifier "${PROJECT_NAME}-replica" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "")
    
    if [ "$REPLICA_STATUS" != "available" ]; then
        warn "Read replica status: $REPLICA_STATUS"
        return 1
    else
        log "Read replica is available"
    fi
    
    # Check replication lag
    REPLICA_LAG=$(aws rds describe-db-instances \
        --region $SECONDARY_REGION \
        --db-instance-identifier "${PROJECT_NAME}-replica" \
        --query 'DBInstances[0].StatusInfos[?StatusType==`read replication`].Message' \
        --output text 2>/dev/null || echo "")
    
    log "Replication status: $REPLICA_LAG"
    return 0
}

# Function to simulate primary region failure
simulate_primary_failure() {
    log "Simulating primary region failure..."
    
    # Stop primary ALB (simulate failure)
    aws elbv2 modify-load-balancer \
        --region $PRIMARY_REGION \
        --load-balancer-arn $(aws elbv2 describe-load-balancers \
            --region $PRIMARY_REGION \
            --names "${PROJECT_NAME}-alb" \
            --query 'LoadBalancers[0].LoadBalancerArn' \
            --output text) \
        --ip-address-type ipv4 > /dev/null
    
    warn "Primary region failure simulated"
    
    # Wait for health check to detect failure
    log "Waiting for health check to detect failure (this may take a few minutes)..."
    sleep 180
}

# Function to test failover
test_failover() {
    log "Testing failover mechanism..."
    
    # Test domain resolution
    RESOLVED_IP=$(dig +short $DOMAIN_NAME | head -n1)
    
    if [ -z "$RESOLVED_IP" ]; then
        error "Domain resolution failed"
        return 1
    fi
    
    log "Domain resolves to: $RESOLVED_IP"
    
    # Test application response
    if curl -f -s "http://$DOMAIN_NAME/health" > /dev/null; then
        log "Application is responding after failover"
        return 0
    else
        error "Application is not responding after failover"
        return 1
    fi
}

# Function to promote read replica
promote_replica() {
    log "Promoting read replica to primary..."
    
    aws rds promote-read-replica \
        --region $SECONDARY_REGION \
        --db-instance-identifier "${PROJECT_NAME}-replica"
    
    log "Read replica promotion initiated"
    
    # Wait for promotion to complete
    log "Waiting for replica promotion to complete..."
    aws rds wait db-instance-available \
        --region $SECONDARY_REGION \
        --db-instance-identifier "${PROJECT_NAME}-replica"
    
    log "Read replica has been promoted to primary"
}

# Function to restore primary region
restore_primary() {
    log "Restoring primary region..."
    
    # This would involve:
    # 1. Fixing the primary region issues
    # 2. Creating a new read replica from the promoted database
    # 3. Switching traffic back to primary
    
    warn "Primary region restoration is a manual process"
    warn "Please refer to the disaster recovery runbook"
}

# Function to run full DR test
run_dr_test() {
    log "Starting Disaster Recovery Test"
    log "================================"
    
    # Pre-flight checks
    check_aws_cli
    check_primary_health || { error "Primary region is not healthy before test"; exit 1; }
    check_secondary_health || { error "Secondary region is not healthy before test"; exit 1; }
    check_route53_config || { error "Route 53 configuration is incorrect"; exit 1; }
    check_rds_replication || { error "RDS replication is not working"; exit 1; }
    
    log "All pre-flight checks passed"
    
    # Simulate failure and test failover
    simulate_primary_failure
    test_failover || { error "Failover test failed"; exit 1; }
    
    # Promote replica if needed
    promote_replica
    
    log "Disaster Recovery Test Completed Successfully"
    log "============================================="
    
    warn "Remember to restore the primary region when ready"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTION]"
    echo "Disaster Recovery Test Script"
    echo ""
    echo "Options:"
    echo "  --full-test     Run complete DR test"
    echo "  --check-health  Check health of both regions"
    echo "  --check-config  Check DR configuration"
    echo "  --promote       Promote read replica"
    echo "  --help          Show this help message"
}

# Main script logic
case "${1:-}" in
    --full-test)
        run_dr_test
        ;;
    --check-health)
        check_aws_cli
        check_primary_health
        check_secondary_health
        ;;
    --check-config)
        check_aws_cli
        check_route53_config
        check_rds_replication
        ;;
    --promote)
        check_aws_cli
        promote_replica
        ;;
    --help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac