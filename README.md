# AWS S3 Cross-Account Migration Tool

> **Migrate all S3 buckets from one AWS account to another with a single command**

A bash script to automatically migrate all Amazon S3 buckets between AWS accounts. Perfect for AWS account consolidation, organization transfers, or moving to a new AWS account.

## Features

- **One-command migration** - Automatically discovers and migrates all buckets
- **Cross-account transfer** - Securely moves data between different AWS accounts
- **Preserves data integrity** - Verifies object counts after migration
- **Handles permissions** - Automatically configures cross-account bucket policies
- **Resumable** - Safe to re-run if interrupted (uses `aws s3 sync`)
- **Detailed logging** - Creates timestamped log files for audit trails
- **Multi-region support** - Works with buckets in any AWS region

## Use Cases

- Migrating from personal AWS account to company account
- Consolidating multiple AWS accounts into one
- Transferring ownership during acquisitions
- Moving workloads between AWS Organizations
- Creating production account from development account

## Prerequisites

- **AWS CLI v2** installed ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Two AWS CLI profiles** configured (source and destination accounts)
- **IAM permissions** on both accounts:
  - Source account: `s3:ListAllMyBuckets`, `s3:GetBucketLocation`, `s3:ListBucket`, `s3:GetObject`
  - Destination account: `s3:CreateBucket`, `s3:PutBucketPolicy`, `s3:ListBucket`, `s3:PutObject`

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/lmotwani/aws-s3-cross-account-migration.git
cd aws-s3-cross-account-migration
```

### 2. Configure AWS CLI profiles

```bash
# Configure source account (the account you're migrating FROM)
aws configure --profile old-account

# Configure destination account (the account you're migrating TO)
aws configure --profile new-account
```

### 3. Edit the script configuration

Open `migrate.sh` and update these variables:

```bash
SOURCE_PROFILE="old-account"      # Your source AWS CLI profile name
DEST_PROFILE="new-account"        # Your destination AWS CLI profile name
BUCKET_PREFIX="migrated-"         # Prefix for new bucket names (for global uniqueness)
```

### 4. Run the migration

```bash
chmod +x migrate.sh
./migrate.sh
```

## How It Works

1. **Discovery** - Lists all S3 buckets in the source account
2. **Creation** - Creates corresponding buckets in the destination account (with prefix)
3. **Permissions** - Applies bucket policy allowing cross-account writes
4. **Sync** - Copies all objects from source to destination
5. **Verification** - Compares object counts to ensure complete migration

```
Source Account                    Destination Account
┌─────────────────┐              ┌─────────────────────┐
│  my-bucket-1    │  ────────>   │  migrated-my-bucket-1│
│  my-bucket-2    │  ────────>   │  migrated-my-bucket-2│
│  my-bucket-3    │  ────────>   │  migrated-my-bucket-3│
└─────────────────┘              └─────────────────────────┘
```

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `SOURCE_PROFILE` | AWS CLI profile for source account | `old-account` |
| `DEST_PROFILE` | AWS CLI profile for destination account | `new-account` |
| `BUCKET_PREFIX` | Prefix added to new bucket names | `migrated-` |

## Sample Output

```
============================================
  AWS S3 CROSS-ACCOUNT MIGRATION
============================================

[2024-01-15 10:30:00] Verifying source account credentials...
[2024-01-15 10:30:01] Source Account ID: 123456789012
[2024-01-15 10:30:02] Destination Account ID: 987654321098
[2024-01-15 10:30:03] Found 3 bucket(s) to migrate

Migration Plan:
===============
  my-website  -->  migrated-my-website
  my-backups  -->  migrated-my-backups
  my-logs     -->  migrated-my-logs

================================================
[1/3] Processing: my-website
[2024-01-15 10:30:10] Bucket created successfully
[2024-01-15 10:30:12] Permissions configured
[2024-01-15 10:35:00] SUCCESS: All 1523 objects synced
```

## Troubleshooting

### "BucketAlreadyExists" error
S3 bucket names are globally unique. Change the `BUCKET_PREFIX` to something unique like your company name.

### "Access Denied" error
Ensure both AWS profiles have the required IAM permissions listed in Prerequisites.

### Partial migration
The script is resumable. Simply run it again to retry failed buckets.

## Important Notes

- **Bucket naming**: New buckets will have the prefix you configure (e.g., `migrated-original-name`)
- **Object ownership**: Since April 2023, new buckets use "Bucket owner enforced" by default, so all migrated objects are automatically owned by the destination account
- **Costs**: Standard S3 data transfer and request charges apply
- **Time**: Migration time depends on data volume and network speed

## Post-Migration Steps

1. **Verify data**: Check object counts and spot-check important files
2. **Update applications**: Point your apps to the new bucket names
3. **Update IAM policies**: Grant access to the new buckets
4. **DNS/CloudFront**: Update any static website hosting or CDN configurations
5. **Keep backups**: Retain source buckets for 30 days before deletion

## License

MIT License - feel free to use, modify, and distribute.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Related Tools

- [aws-s3-local-backup](https://github.com/lmotwani/aws-s3-local-backup) - Download all S3 buckets to your local machine

## Keywords

AWS S3 migration, cross-account S3 transfer, migrate S3 buckets, AWS account migration, S3 bucket copy, AWS S3 sync between accounts, move S3 data, AWS organization migration, S3 bucket transfer tool, AWS CLI S3 migration
