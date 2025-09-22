# Pre-Deployment Security Checklist

Before pushing to GitHub or deploying to production, verify all sensitive information has been removed.

## ✅ Checklist

### AWS Credentials & Secrets
- [ ] No AWS Access Keys in source code
- [ ] No JWT secrets in samconfig.toml 
- [ ] No hardcoded API Gateway URLs
- [ ] No hardcoded account IDs or ARNs
- [ ] No sensitive environment variables in code

### Configuration Files
- [ ] .env files are in .gitignore
- [ ] samconfig.toml contains only template values
- [ ] API endpoints use placeholder URLs
- [ ] Database names use variable substitution

### Flutter Frontend
- [ ] API base URL uses placeholder: `YOUR-API-GATEWAY-ID`
- [ ] No hardcoded AWS regions in production code
- [ ] Environment configuration uses templates

### Security Settings
- [ ] TLS 1.3 certificate fingerprints are generic/commented
- [ ] CORS origins set to placeholder values
- [ ] No production passwords or tokens

### Files to Review
- [ ] `meddevice-app-flutter-main/lib/core/constants/app_constants.dart`
- [ ] `meddevice-backend-rust/samconfig.toml`
- [ ] `meddevice-backend-rust/.env.example`
- [ ] `meddevice-app-flutter-main/.env.example`

### CI/CD Pipelines
- [ ] GitHub Actions workflows disabled/renamed (.backup)
- [ ] No secrets in workflow files
- [ ] No hardcoded AWS account references

## 🚫 What Should NOT Be in Git

```bash
# These should never be committed:
.env                    # Environment variables
samconfig.toml.local   # Local SAM configuration
*.pem                  # Certificate files
*.key                  # Private keys
aws-exports.js         # AWS configuration exports
```

## ✅ What SHOULD Be in Git

```bash
# These templates are safe to commit:
.env.example           # Environment templates
samconfig.toml         # Template configuration
README.md              # Documentation
CONFIGURATION.md       # Setup guide
```

## Quick Security Scan

Run this command to check for potential secrets:

```bash
# Check for potential AWS secrets
grep -r "AKIA\|aws_access_key\|aws_secret" . --exclude-dir=.git

# Check for hardcoded URLs
grep -r "amazonaws.com" . --exclude-dir=.git --exclude="*.md"

# Check for JWT secrets
grep -r "jwt.*secret\|JWT.*SECRET" . --exclude-dir=.git --exclude="*.md"
```

## Post-Deployment Steps

After successful deployment:

1. Update frontend API configuration with real URL
2. Test all functionality with deployed backend
3. Verify CORS configuration works
4. Test user registration and authentication
5. Confirm audit logging is working

## Emergency Procedures

If sensitive data was accidentally committed:

1. **Immediate Actions:**
   ```bash
   # Remove from git history
   git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch path/to/sensitive/file' --prune-empty --tag-name-filter cat -- --all
   
   # Force push (CAUTION: Destructive)
   git push origin --force --all
   ```

2. **Rotate Compromised Secrets:**
   - Generate new JWT secrets
   - Rotate AWS access keys if exposed
   - Update all affected environments

3. **Update Security:**
   - Review and strengthen gitignore rules
   - Add pre-commit hooks for secret scanning
   - Update team security procedures

## Verification Commands

Before git push, run:

```bash
# Verify no AWS credentials
git log --all -S "AKIA" -S "aws_access_key" --source --all

# Check current changes
git diff --cached

# Verify gitignore is working
git status --ignored
```

---

**Remember**: Medical device software requires strict security compliance. When in doubt, err on the side of caution and keep sensitive information secure.