# Security Vulnerabilities in Dependencies (Automated Trivy Scan)

**Scan date:** {{ now | date "2006-01-02 15:04 UTC" }}
**Total vulnerabilities found:** {{ len . }}

{{ if not . }}
**No vulnerabilities detected. Great job!**
{{ else }}
{{ range . }}
## {{ .VulnerabilityID }} – {{ .PkgName }} (Severity: **{{ .Severity }}**)

- **Installed version:** {{ .InstalledVersion }}
{{ if .FixedVersion }}- **Fixed in version:** {{ .FixedVersion }}{{ else }}- **No fixed version available**{{ end }}
- **Type:** {{ .VulnerabilityType }}
- **Location:** `{{ .Target }}`

{{ .Description }}

**Recommended fix**
{{ if .FixedVersion }}→ Upgrade `{{ .PkgName }}` to **≥ {{ .FixedVersion }}**{{ else }}Manual review/mitigation required{{ end }}

{{ if .PrimaryURL }}**More info:** {{ .PrimaryURL }}{{ end }}

{{ if .References }}
**References**
{{ range .References }}- {{ . }}
{{ end }}{{ end }}
---
{{ end }}
*This issue is automatically kept up-to-date on every push to main and nightly.*
{{ end }}
