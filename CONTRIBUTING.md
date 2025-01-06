# Contributing Guide

Thank you for your interest in contributing to this repository! We appreciate your help in improving and expanding our bash scripts for Proxmox management and automation. Below are the guidelines and best practices we ask all contributors to follow.

---

## 1. Project Scope

This repository contains Bash scripts (`.sh` files) that help automate and manage Proxmox tasks. The goal is to maintain a clean, consistent, and secure set of scripts that are easy to understand and extend.

---

## 2. Getting Started

1. **Fork and Clone**  
   - Fork the repository to your own GitHub account.  
   - Clone your fork locally.

2. **Make Your Changes**
   - Follow the coding guidelines below.
   - Test your changes thoroughly in a development/test environment.

3. **Submit a Pull Request**
   - Open a pull request (PR) against the repository’s `main` branch.
   - Provide a clear title and description, referencing any related issues.

---

## 3. Script Structure and Style

### 3.1 Shebang

- All scripts **must** start with:
```bash
#!/bin/bash
```

### 3.2 Usage and Description

- The **first line** (or first few lines) in the script, after the `#!/bin/bash`, must be commented with **usage instructions** and a brief **description**. For example:

```bash
#!/bin/bash
#
# AddNode.sh
#
# A script to join a new Proxmox node to an existing cluster, with optional multi-ring support.
#
# Usage:
#   ./AddNode.sh <cluster-IP> [<ring0-addr>] [<ring1-addr>]
#
# [Further explanation, examples, etc...]
```

- If you need to add multiple examples, list them under the usage section, preceded by a brief comment. Ensure each example is easy to understand.

### 3.3 Code Readability and Commenting

- **Comment your code** where it’s not self-explanatory.  
- Use section splits with a clear header for readability, for example:
```bash
# --- Preliminary Checks -----------------------------------------------------
```
- Keep sections logically grouped (e.g., argument parsing, validations, main script logic, cleanup).
- Use functions when applicable.

### 3.4 Avoid Code Duplication

- If a script can call another script instead of repeating code, please **call the other script**.
- Keep common functionality modular if possible (e.g., in a shared script or function library).

### 3.5 Error Handling

- Always include:
```bash
set -e
```
  at or near the top of the script to exit immediately on any non-zero command return.

- Provide clear error messages when exiting, for example:
```bash
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi
```

- Test for required commands using `command -v` or similar checks:
```bash
if ! command -v pvecm &>/dev/null; then
  echo "Error: 'pvecm' not found. Are you sure this is a Proxmox node?"
  exit 2
fi
```

### 3.6 Variable Naming

- Use **descriptive variable names** in uppercase for environment-dependent or widely-used variables (e.g., `CLUSTER_IP`, `RING0_ADDR`).  
- Temporary or local variables can be lowercase or mixed case if it improves readability.

### 3.7 Quoting and Expansion

- Always **quote variables** when they might contain spaces or special characters:
```bash
echo "CLUSTER_IP is: $CLUSTER_IP"
```

### 3.8 ShellCheck and Linting

- We recommend running [ShellCheck](https://www.shellcheck.net/) on your scripts to catch common issues.  
- Fix any warnings or errors surfaced by ShellCheck or other linters before submitting your contribution.

---

## 4. Submitting Changes

1. **Commit Messages**  
   - Use clear, concise commit messages.  
   - Reference any related issues (e.g., `Fixes #123`) in your commit or PR description.

2. **Pull Request Description**  
   - Use the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md)
   - Provide a summary of what the PR does and why.  
   - Include screenshots, logs, or references if it helps the reviewer.

3. **Code Review**  
   - All pull requests undergo review from maintainers or other contributors.  
   - Address feedback promptly and be open to revising your approach.

4. **Testing**  
   - Test your script in a test or sandbox environment (especially for Proxmox clusters).  
   - Document any steps to reproduce your tests.

---

## 5. Good Practices

- **Small, Focused Changes**: Submit small, atomic pull requests to keep reviews manageable.  
- **Security Considerations**: Avoid storing or echoing sensitive data (tokens, passwords) in logs, follow the [Security Policy](SECURITY.md)
- **Documentation**: Update or create documentation relevant to your changes (e.g., script headers and comments).  
- **Respect the Code of Conduct**: Please be courteous and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 6. Thank You

By following these guidelines, you help us maintain a clean, consistent codebase and an effective workflow. If you have any questions or suggestions for improving these guidelines, feel free to open an issue or drop a comment in a pull request.
