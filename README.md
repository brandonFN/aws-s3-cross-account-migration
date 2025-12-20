# AWS S3 Cross-Account Migration Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![AWS S3](https://img.shields.io/badge/AWS-S3-orange?logo=amazon-aws)](https://aws.amazon.com/s3/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/lmotwani/aws-s3-cross-account-migration/graphs/commit-activity)

> **Migrate all S3 buckets from one AWS account to another with a single command**

A production-ready bash script to automatically migrate all Amazon S3 buckets between AWS accounts. Perfect for AWS account consolidation, organization transfers, or moving to a new AWS account.

![AWS S3 Cross-Account Migration](https://img.shields.io/badge/AWS%20S3-Cross%20Account%20Migration-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)

---

## Table of Contents

- [Features](#features)
- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Configuration](#configuration)
- [Sample Output](#sample-output)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Contributing](#contributing)
- [Related Projects](#related-projects)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| **One-Command Migration** | Automatically discovers and migrates all buckets |
| **Cross-Account Transfer** | Securely moves data between different AWS accounts |
| **Data Integrity** | Verifies object counts after migration |
| **Auto Permissions** | Configures cross-account bucket policies automatically |
| **Resumable** | Safe to re-run if interrupted (uses `aws s3 sync`) |
| **Detailed Logging** | Creates timestamped log files for audit trails |
| **Multi-Region** | Works with buckets in any AWS region |
| **Zero Downtime** | Source buckets remain accessible during migration |

---

## Use Cases

- **Account Consolidation** - Merge multiple AWS accounts into one
- **Organization Transfer** - Move workloads between AWS Organizations
- **Company Acquisition** - Transfer S3 data during M&A
- **Account Migration** - Move from personal to enterprise account
- **Disaster Recovery** - Create copies in separate AWS accounts
- **Compliance** - Separate production and development data

---

## Prerequisites

### Required Software
- **AWS CLI v2** - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Bash shell** - Linux, macOS, or Windows (WSL/Git Bash)

### AWS Configuration
```bash
# Verify AWS CLI is installed
aws --version

# Configure source account profile
aws configure --profile source-account

# Configure destination account profile
aws configure --profile dest-account
```

### Required IAM Permissions

<details>
<summary><strong>Source Account Permissions (click to expand)</strong></summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:GetObject"
            ],
            "Resource": "*"
        }
    ]
}
```
</details>

<details>
<summary><strong>Destination Account Permissions (click to expand)</strong></summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:PutBucketPolicy",
                "s3:ListBucket",
                "s3:PutObject"
            ],
            "Resource": "*"
        }
    ]
}
```
</details>

---

## Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/lmotwani/aws-s3-cross-account-migration.git
cd aws-s3-cross-account-migration
```

### Step 2: Configure the Script

Edit `migrate.sh` and update these variables:

```bash
SOURCE_PROFILE="old-account"      # AWS CLI profile for source account
DEST_PROFILE="new-account"        # AWS CLI profile for destination account
BUCKET_PREFIX="migrated-"         # Prefix for new bucket names
```

### Step 3: Run the Migration

```bash
# Make executable
chmod +x migrate.sh

# Run migration
./migrate.sh
```

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    MIGRATION WORKFLOW                            │
└─────────────────────────────────────────────────────────────────┘

  SOURCE ACCOUNT                         DESTINATION ACCOUNT
  ══════════════                         ═══════════════════
        │                                        │
        │  1. List all buckets                   │
        ├──────────────────────────────────────> │
        │                                        │
        │  2. Create new bucket                  │
        │     (with prefix)                      │
        │ <──────────────────────────────────────┤
        │                                        │
        │  3. Apply bucket policy                │
        │     (cross-account access)             │
        │ <──────────────────────────────────────┤
        │                                        │
        │  4. Sync all objects ─────────────────>│
        │                                        │
        │  5. Verify object counts               │
        ├──────────────────────────────────────> │
        │                                        │

  ┌─────────────────┐              ┌─────────────────────────┐
  │  my-bucket-1    │  ────────>   │  migrated-my-bucket-1   │
  │  my-bucket-2    │  ────────>   │  migrated-my-bucket-2   │
  │  my-bucket-3    │  ────────>   │  migrated-my-bucket-3   │
  └─────────────────┘              └─────────────────────────┘
```

---

## Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SOURCE_PROFILE` | AWS CLI profile for source account | `old-account` | Yes |
| `DEST_PROFILE` | AWS CLI profile for destination account | `new-account` | Yes |
| `BUCKET_PREFIX` | Prefix added to new bucket names | `migrated-` | Yes |
| `LOG_FILE` | Log file path | Auto-generated | No |

---

## Sample Output

```
============================================
  AWS S3 CROSS-ACCOUNT MIGRATION
============================================

[2024-01-15 10:30:00] Log file: migration_20240115_103000.log
[2024-01-15 10:30:01] Verifying source account credentials...
[2024-01-15 10:30:01] Source Account ID: 123456789012
[2024-01-15 10:30:02] Verifying destination account credentials...
[2024-01-15 10:30:02] Destination Account ID: 987654321098
[2024-01-15 10:30:03] Found 3 bucket(s) to migrate

Migration Plan:
===============
  my-website  -->  migrated-my-website
  my-backups  -->  migrated-my-backups
  my-logs     -->  migrated-my-logs

================================================
[1/3] Processing: my-website
Destination: migrated-my-website
[2024-01-15 10:30:05] Region: us-east-1
[2024-01-15 10:30:06] Source objects: 1523
[2024-01-15 10:30:10] Bucket created successfully
[2024-01-15 10:30:12] Permissions configured
[2024-01-15 10:30:12] Starting data sync...
[2024-01-15 10:35:00] Verification: Source=1523, Destination=1523
[2024-01-15 10:35:00] SUCCESS: All 1523 objects synced

============================================
  MIGRATION SUMMARY
============================================
Total buckets: 3
Successful: 3

All buckets migrated successfully!
```

---

## Troubleshooting

<details>
<summary><strong>"BucketAlreadyExists" error</strong></summary>

S3 bucket names are globally unique across all AWS accounts. Solution:
```bash
# Change BUCKET_PREFIX to something unique
BUCKET_PREFIX="mycompany-migrated-"
```
</details>

<details>
<summary><strong>"Access Denied" error</strong></summary>

Ensure both AWS profiles have the required IAM permissions:
```bash
# Test source account access
aws s3 ls --profile source-account

# Test destination account access
aws sts get-caller-identity --profile dest-account
```
</details>

<details>
<summary><strong>Partial migration / Timeout</strong></summary>

The script is resumable. Simply run it again:
```bash
./migrate.sh
```
Only missing objects will be transferred.
</details>

<details>
<summary><strong>"Same account" safety error</strong></summary>

Both profiles point to the same AWS account. Verify your credentials:
```bash
aws sts get-caller-identity --profile source-account
aws sts get-caller-identity --profile dest-account
```
</details>

---

## FAQ

<details>
<summary><strong>How long does migration take?</strong></summary>

Migration time depends on:
- Total data volume
- Number of objects
- Network speed between AWS regions

As a reference: ~1TB typically takes 2-4 hours within the same region.
</details>

<details>
<summary><strong>Is the source data affected?</strong></summary>

No. The script uses `aws s3 sync` which copies data without modifying the source. Your original buckets remain unchanged.
</details>

<details>
<summary><strong>What about bucket versioning and lifecycle policies?</strong></summary>

This script migrates objects only. Bucket configurations (versioning, lifecycle, CORS, etc.) need to be configured separately on destination buckets.
</details>

<details>
<summary><strong>Can I migrate specific buckets only?</strong></summary>

Currently, the script migrates all buckets. To migrate specific buckets, you can modify the `BUCKETS` variable in the script or comment out unwanted buckets from the migration plan.
</details>

---

## Post-Migration Checklist

- [ ] Verify object counts in destination buckets
- [ ] Spot-check important files
- [ ] Update application configurations to use new bucket names
- [ ] Update IAM policies to grant access to new buckets
- [ ] Update CloudFront distributions if applicable
- [ ] Configure bucket versioning on new buckets
- [ ] Set up lifecycle policies on new buckets
- [ ] Keep source buckets for 30 days before deletion
- [ ] Update DNS records for static website hosting

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## Related Projects

| Project | Description |
|---------|-------------|
| [aws-s3-local-backup](https://github.com/lmotwani/aws-s3-local-backup) | Download all S3 buckets to your local machine |

---

## Support the Project

If you find this tool helpful, consider supporting its development:

<a href="https://buymeacoffee.com/lokeshmotwani" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60">
</a>

Your support helps maintain and improve this project!

---

## Star History

If this project helped you, please consider giving it a star!

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Author

**Lokesh Motwani** - [GitHub](https://github.com/lmotwani)

---

<p align="center">
  <strong>Found this useful? Give it a ⭐ on GitHub!</strong>
  <br><br>
  <a href="https://buymeacoffee.com/lokeshmotwani" target="_blank">
    <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-yellow?style=for-the-badge&logo=buy-me-a-coffee&logoColor=white" alt="Buy Me A Coffee">
  </a>
</p>

---

## Keywords

`aws s3 migration` `cross-account s3 transfer` `migrate s3 buckets` `aws account migration` `s3 bucket copy` `aws s3 sync between accounts` `move s3 data` `aws organization migration` `s3 bucket transfer tool` `aws cli s3 migration` `s3 cross account copy` `aws s3 bucket migration script` `transfer s3 bucket to another account` `aws s3 data migration` `s3 account transfer`
