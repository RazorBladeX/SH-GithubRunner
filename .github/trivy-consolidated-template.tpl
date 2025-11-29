# Security Vulnerabilities (Trivy Scan – ${{ github.sha }})

Found **{{ len . }}** vulnerabilities in the filesystem scan.

{{ range . }}
## {{ .VulnerabilityID }} – {{ .PkgName }} ({{ .Severity }})

- **Installed version**: {{ .InstalledVersion }}
{{ if .FixedVersion }}- **Fixed in**: {{ .FixedVersion }}{{ end }}
{{ if not .FixedVersion }}- **No fixed version available**{{ end }}
- **Type**: {{ .VulnerabilityType }}
- **Location**: `{{ .Target }}`

{{ .Description }}

**Recommended fix**:
{{ if .FixedVersion }}Upgrade `{{ .PkgName }}` to **≥ {{ .FixedVersion }}**{{ else }}{{ if .PrimaryURL }}See {{ .PrimaryURL }}{{ else }}Manual mitigation required{{ end }}{{ end }}

{{ if .References }}
**References**:
{{ range .References }}- {{ . }}{{ end }}
{{ end }}

---
{{ end }}

*This issue is automatically updated on every push to main and nightly. Last run: {{ now }} UTC*
