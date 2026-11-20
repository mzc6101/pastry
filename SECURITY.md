# Security Policy

## Supported versions
Only the latest release of Pastry receives security fixes.

## Reporting a vulnerability
Please report security issues privately through GitHub's
[private vulnerability reporting](https://github.com/mzc6101/pastry/security/advisories/new)
rather than opening a public issue. Include steps to reproduce and the macOS and Pastry versions.
You'll get a response within 7 days.

## Scope
Pastry stores clipboard history locally in `~/Library/Application Support/Pastry/history.sqlite`,
makes no network requests, and skips clipboard items marked concealed (password managers).
Reports about history being exposed to other apps or users, or about the paste/Accessibility path, are especially welcome.
