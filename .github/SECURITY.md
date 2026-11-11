# Security Policy

## Supported Versions

We actively support the following versions of this project with security updates:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of ConnectWiseControlAPI seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### Where to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via one of the following methods:

1. **GitHub Security Advisories** (Preferred)
   - Navigate to the repository's Security tab
   - Click "Report a vulnerability"
   - Fill out the security advisory form with details

2. **Direct Email**
   - Send an email to: **security@christaylor.codes**
   - Use the subject line: `[SECURITY] ConnectWiseControlAPI - Brief Description`

3. **Private Message on Slack**
   - Contact **@CTaylor** on [MSPGeek Slack](https://join.mspgeek.com/)
   - Clearly mark the message as security-related

### What to Include

Please include the following information in your report to help us better understand and resolve the issue:

- **Type of issue** (e.g., credential exposure, injection, privilege escalation)
- **Full paths of source file(s)** related to the manifestation of the issue
- **Location of the affected source code** (tag/branch/commit or direct URL)
- **Step-by-step instructions to reproduce the issue**
- **Proof-of-concept or exploit code** (if possible)
- **Impact of the issue**, including how an attacker might exploit it
- **Your assessment of severity** (Critical, High, Medium, Low)

### What to Expect

After you submit a vulnerability report:

1. **Acknowledgment** - We will acknowledge receipt of your vulnerability report within **48 hours**
2. **Initial Assessment** - We will provide an initial assessment of the vulnerability within **5 business days**
3. **Updates** - We will keep you informed of the progress toward a fix and full announcement
4. **Verification** - We may ask you to verify that our fix resolves the vulnerability
5. **Public Disclosure** - We will coordinate with you on the timing of public disclosure
6. **Credit** - We will credit you in the security advisory (unless you prefer to remain anonymous)

### Severity Levels

We use the [CVSS v3.1](https://www.first.org/cvss/calculator/3.1) scoring system to assess vulnerability severity:

- **Critical (9.0-10.0)** - Fix within 24-48 hours
- **High (7.0-8.9)** - Fix within 1 week
- **Medium (4.0-6.9)** - Fix within 2-4 weeks
- **Low (0.1-3.9)** - Fix in next regular release

## Security Best Practices for Users

When using this module, please:

1. **Secure Your Credentials**
   - Never commit API credentials or passwords to source control
   - Use PowerShell `[PSCredential]` objects, not plaintext passwords
   - Use a complex username and password; accounts that require MFA sign in with `-Mfa`,
     `-OneTimeCode` or `-TotpSecret`
   - A TOTP secret for unattended logins (`-TotpSecret`) is a second password: keep it in a secret
     store, apart from the account password where you can, and replace it if the computer is compromised

2. **Use HTTPS**
   - The module requires your ScreenConnect server to use HTTPS
   - TLS 1.2 is enforced by the module

3. **Keep Updated**
   - Regularly update the module from the PowerShell Gallery
   - Review the CHANGELOG for security-related fixes

4. **PowerShell Execution Policy**
   - Be cautious when using `-ExecutionPolicy Bypass`
   - Prefer signed scripts in production environments

## Security Hall of Fame

We appreciate security researchers who responsibly disclose vulnerabilities. Contributors will be listed here (with permission):

_No vulnerabilities reported yet._

## Additional Resources

- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/security/overview)
