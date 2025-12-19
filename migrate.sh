#!/bin/bash

# ============================================
# AWS S3 CROSS-ACCOUNT MIGRATION SCRIPT
# ============================================
# Migrates all S3 buckets from one AWS account to another
#
# How it works:
# 1. Creates new bucket in destination account
# 2. Applies bucket policy allowing source account to write
# 3. Syncs data from source to destination
# 4. New buckets have "Bucket owner enforced" by default (since April 2023)
#    so all objects are automatically owned by destination account
#
# Requirements:
# - AWS CLI installed
# - Configured profiles for both accounts
# - Admin/S3 permissions on both accounts
# ============================================

# --- CONFIGURATION ---
SOURCE_PROFILE="old-account"
DEST_PROFILE="new-account"
BUCKET_PREFIX="migrated-"    # Prefix for new buckets (required for global uniqueness)
LOG_FILE="migration_$(date +%Y%m%d_%H%M%S).log"
# ---------------------

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging function
log() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "$timestamp $1"
    echo "$timestamp $1" >> "$LOG_FILE"
}

echo ""
echo "============================================"
echo "  AWS S3 CROSS-ACCOUNT MIGRATION"
echo "============================================"
echo ""

# Initialize log file
echo "Migration started at $(date)" > "$LOG_FILE"
log "Log file: $LOG_FILE"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log "${RED}ERROR: AWS CLI is not installed${NC}"
    log "Install with: brew install awscli"
    exit 1
fi

# Verify source account credentials
log "Verifying source account credentials..."
SOURCE_IDENTITY=$(aws sts get-caller-identity --profile "$SOURCE_PROFILE" 2>&1)
if [[ $? -ne 0 ]]; then
    log "${RED}ERROR: Cannot authenticate with source profile '$SOURCE_PROFILE'${NC}"
    log "Error: $SOURCE_IDENTITY"
    log "Run: aws configure --profile $SOURCE_PROFILE"
    exit 1
fi
SOURCE_ACCOUNT_ID=$(echo "$SOURCE_IDENTITY" | grep -o '"Account": "[0-9]*"' | grep -o '[0-9]*')
log "${GREEN}Source Account ID: $SOURCE_ACCOUNT_ID${NC}"

# Verify destination account credentials
log "Verifying destination account credentials..."
DEST_IDENTITY=$(aws sts get-caller-identity --profile "$DEST_PROFILE" 2>&1)
if [[ $? -ne 0 ]]; then
    log "${RED}ERROR: Cannot authenticate with destination profile '$DEST_PROFILE'${NC}"
    log "Error: $DEST_IDENTITY"
    log "Run: aws configure --profile $DEST_PROFILE"
    exit 1
fi
DEST_ACCOUNT_ID=$(echo "$DEST_IDENTITY" | grep -o '"Account": "[0-9]*"' | grep -o '[0-9]*')
log "${GREEN}Destination Account ID: $DEST_ACCOUNT_ID${NC}"

# Safety check: ensure accounts are different
if [ "$SOURCE_ACCOUNT_ID" == "$DEST_ACCOUNT_ID" ]; then
    log "${RED}SAFETY STOP: Both profiles point to the same AWS account!${NC}"
    log "Source profile '$SOURCE_PROFILE' and destination profile '$DEST_PROFILE' both resolve to account $SOURCE_ACCOUNT_ID"
    log "This would cause data conflicts. Please check your AWS profiles."
    exit 1
fi

echo ""
log "Scanning for buckets in source account..."

# Get list of all buckets
BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text --profile "$SOURCE_PROFILE" 2>&1)
if [[ $? -ne 0 ]]; then
    log "${RED}ERROR: Failed to list buckets: $BUCKETS${NC}"
    exit 1
fi

if [ -z "$BUCKETS" ]; then
    log "${YELLOW}No buckets found in source account.${NC}"
    exit 0
fi

# Count buckets
BUCKET_COUNT=$(echo $BUCKETS | wc -w | tr -d ' ')
log "${BLUE}Found $BUCKET_COUNT bucket(s) to migrate${NC}"

# Show migration plan
echo ""
echo "Migration Plan:"
echo "==============="
for BUCKET in $BUCKETS; do
    echo "  $BUCKET  -->  ${BUCKET_PREFIX}${BUCKET}"
done
echo ""

# Counters for summary
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIPPED_COUNT=0
FAILED_BUCKETS=""

# Process each bucket
CURRENT=0
for SOURCE_BUCKET in $BUCKETS; do
    CURRENT=$((CURRENT + 1))
    DEST_BUCKET="${BUCKET_PREFIX}${SOURCE_BUCKET}"
    
    echo ""
    echo "================================================"
    log "[$CURRENT/$BUCKET_COUNT] Processing: $SOURCE_BUCKET"
    log "Destination: $DEST_BUCKET"

    # Get bucket region
    REGION=$(aws s3api get-bucket-location --bucket "$SOURCE_BUCKET" --profile "$SOURCE_PROFILE" --output text 2>/dev/null)
    
    # AWS returns "None" or empty for us-east-1
    if [ "$REGION" == "None" ] || [ -z "$REGION" ] || [ "$REGION" == "null" ]; then
        REGION="us-east-1"
    fi
    log "Region: $REGION"

    # Count objects in source bucket
    SOURCE_COUNT=$(aws s3 ls "s3://$SOURCE_BUCKET" --recursive --profile "$SOURCE_PROFILE" 2>/dev/null | wc -l | tr -d ' ')
    log "Source objects: $SOURCE_COUNT"

    # Check if destination bucket exists
    BUCKET_EXISTS=false
    if aws s3api head-bucket --bucket "$DEST_BUCKET" --profile "$DEST_PROFILE" 2>/dev/null; then
        BUCKET_EXISTS=true
        log "${YELLOW}Destination bucket already exists. Will sync data.${NC}"
    fi

    # Create destination bucket if needed
    if [ "$BUCKET_EXISTS" = false ]; then
        log "Creating destination bucket..."
        
        if [ "$REGION" == "us-east-1" ]; then
            CREATE_OUTPUT=$(aws s3api create-bucket \
                --bucket "$DEST_BUCKET" \
                --profile "$DEST_PROFILE" 2>&1)
        else
            CREATE_OUTPUT=$(aws s3api create-bucket \
                --bucket "$DEST_BUCKET" \
                --region "$REGION" \
                --create-bucket-configuration LocationConstraint="$REGION" \
                --profile "$DEST_PROFILE" 2>&1)
        fi
        
        if [[ $? -ne 0 ]]; then
            if [[ "$CREATE_OUTPUT" == *"BucketAlreadyOwnedByYou"* ]]; then
                log "${YELLOW}Bucket already exists in your account. Continuing...${NC}"
            elif [[ "$CREATE_OUTPUT" == *"BucketAlreadyExists"* ]]; then
                log "${RED}ERROR: Bucket name '$DEST_BUCKET' is already taken globally by another AWS account.${NC}"
                log "Solution: Edit BUCKET_PREFIX in the script to use a different prefix."
                FAIL_COUNT=$((FAIL_COUNT + 1))
                FAILED_BUCKETS="$FAILED_BUCKETS $SOURCE_BUCKET(name-conflict)"
                continue
            else
                log "${RED}ERROR: Failed to create bucket: $CREATE_OUTPUT${NC}"
                FAIL_COUNT=$((FAIL_COUNT + 1))
                FAILED_BUCKETS="$FAILED_BUCKETS $SOURCE_BUCKET"
                continue
            fi
        else
            log "${GREEN}Bucket created successfully${NC}"
        fi
        
        # Wait for bucket to be ready
        sleep 2
    fi

    # Apply bucket policy for cross-account access
    # Note: New buckets have "Bucket owner enforced" by default (ACLs disabled)
    # This means all uploaded objects are automatically owned by bucket owner
    # We just need a policy to allow the source account to write
    log "Applying cross-account permissions..."
    
    POLICY_JSON=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCrossAccountSync",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${SOURCE_ACCOUNT_ID}:root"
            },
            "Action": [
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${DEST_BUCKET}",
                "arn:aws:s3:::${DEST_BUCKET}/*"
            ]
        }
    ]
}
EOF
)

    echo "$POLICY_JSON" > /tmp/bucket_policy_$$.json
    POLICY_OUTPUT=$(aws s3api put-bucket-policy \
        --bucket "$DEST_BUCKET" \
        --policy file:///tmp/bucket_policy_$$.json \
        --profile "$DEST_PROFILE" 2>&1)
    rm -f /tmp/bucket_policy_$$.json
    
    if [[ $? -ne 0 ]]; then
        log "${RED}WARNING: Could not apply bucket policy: $POLICY_OUTPUT${NC}"
        log "Attempting sync anyway (may fail if permissions are insufficient)..."
    else
        log "${GREEN}Permissions configured${NC}"
    fi

    # Sync data
    log "Starting data sync..."
    log "This may take a while for large buckets..."
    
    SYNC_OUTPUT=$(aws s3 sync "s3://$SOURCE_BUCKET" "s3://$DEST_BUCKET" \
        --profile "$SOURCE_PROFILE" \
        2>&1)
    
    SYNC_EXIT_CODE=$?
    
    if [[ $SYNC_EXIT_CODE -ne 0 ]]; then
        log "${RED}ERROR: Sync failed${NC}"
        log "Error details: $SYNC_OUTPUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_BUCKETS="$FAILED_BUCKETS $SOURCE_BUCKET"
        continue
    fi

    # Verify sync by comparing object counts
    DEST_COUNT=$(aws s3 ls "s3://$DEST_BUCKET" --recursive --profile "$DEST_PROFILE" 2>/dev/null | wc -l | tr -d ' ')
    
    log "Verification: Source=$SOURCE_COUNT, Destination=$DEST_COUNT"
    
    if [ "$SOURCE_COUNT" -eq "$DEST_COUNT" ]; then
        log "${GREEN}SUCCESS: All $SOURCE_COUNT objects synced${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [ "$DEST_COUNT" -gt 0 ]; then
        log "${YELLOW}PARTIAL: $DEST_COUNT of $SOURCE_COUNT objects synced${NC}"
        log "Re-run the script to retry failed objects"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        log "${RED}FAILED: No objects in destination${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_BUCKETS="$FAILED_BUCKETS $SOURCE_BUCKET"
    fi
done

# Summary
echo ""
echo "============================================"
echo "  MIGRATION SUMMARY"
echo "============================================"
log "Total buckets: $BUCKET_COUNT"
log "${GREEN}Successful: $SUCCESS_COUNT${NC}"

if [ $FAIL_COUNT -gt 0 ]; then
    log "${RED}Failed: $FAIL_COUNT${NC}"
    log "${RED}Failed buckets:$FAILED_BUCKETS${NC}"
fi

echo ""
log "Log file saved to: $LOG_FILE"
log "Migration completed at $(date)"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All buckets migrated successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Verify data: aws s3 ls --profile new-account"
    echo "2. Update your applications to use new bucket names"
    echo "3. Keep old buckets as backup for 30 days"
else
    echo -e "${YELLOW}Migration completed with some errors.${NC}"
    echo "Check $LOG_FILE for details."
    echo "Re-run this script to retry failed buckets."
fi
