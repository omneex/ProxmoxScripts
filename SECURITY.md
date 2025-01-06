# Security Policy

This repository contains Bash scripts used for Proxmox management and automation. We take security issues seriously and appreciate any reports that help us maintain a secure and reliable environment.

## Supported Versions

We make every effort to support all recent versions of these scripts. Specifically:
- **Main Branch (latest)**: Actively maintained, security updates are provided promptly.
- **Release Tags**: Critical security patches may be backported to recent versions, but users should keep current for the best support.

## Reporting a Vulnerability

If you discover any security vulnerabilities:
1. **Do not create a public issue.** Instead, please email the maintainers directly:
   - [Maintainer’s Email] (coelacannot@gmail.com)
2. Provide as much detail as possible, including:
   - Steps to reproduce or proof of concept (if available).
   - Potential impact of the vulnerability.
   - Any suggested fixes or patches (if you have them).

We will make every effort to:
- Respond to security-related messages as fast as possible.
- Provide an initial resolution or mitigation as fast as possible, depending on the severity and complexity of the issue.

## Scope and Expectations

- **Scope**: This policy covers potential security issues within the bash scripts (e.g., command injection, privilege escalation, or insecure storage of credentials).
- **Out of Scope**: Vulnerabilities in external Proxmox environments, third-party dependencies, or issues related to general system administration (outside the repository) are not handled within this policy. However, we may provide guidance or mitigation strategies if they relate to this project.

## Handling Confidential Information

Users should avoid committing or sharing any sensitive data (tokens, passwords, or API keys) in this repository. If you discover such data has been accidentally committed, please report it using the steps above, so it can be removed from history and replaced with a secure alternative.

## Thank You

We appreciate your efforts in responsibly disclosing security issues and helping to keep our Proxmox automation scripts secure. If you have any questions or concerns, please contact us at the email address above.
