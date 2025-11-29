# Security Vulnerabilities in Dependencies (Automated Trivy Scan)

**Scan date:** {{ now | date "2006-01-02 15:04 UTC" }}

{{- $vulnCount := 0 -}}
{{- range .Results -}}
  {{- if .Vulnerabilities -}}
    {{- $vulnCount = add $vulnCount (len .Vulnerabilities) -}}
  {{- end -}}
{{- end }}

**Total vulnerabilities found:** {{ $vulnCount }}

{{- if eq $vulnCount 0 }}

**No vulnerabilities detected. Great job!**

{{- else }}
{{- range .Results }}
{{- if .Vulnerabilities }}

### Target: `{{ .Target }}`
{{- if .Type }}
**Type:** {{ .Type }}
{{- end }}

{{- range .Vulnerabilities }}

## {{ .VulnerabilityID }} - {{ .PkgName }} (Severity: **{{ .Severity }}**)

- **Installed version:** {{ .InstalledVersion }}
{{- if .FixedVersion }}
- **Fixed in version:** {{ .FixedVersion }}
{{- else }}
- **No fixed version available**
{{- end }}
{{- if .PkgID }}
- **Package ID:** `{{ .PkgID }}`
{{- end }}

{{ .Description }}

**Recommended fix**
{{- if .FixedVersion }}
Upgrade `{{ .PkgName }}` to **>= {{ .FixedVersion }}**
{{- else }}
Manual review/mitigation required
{{- end }}

{{- if .PrimaryURL }}

**More info:** {{ .PrimaryURL }}
{{- end }}

{{- if .References }}

**References**
{{- range .References }}
- {{ . }}
{{- end }}
{{- end }}

---
{{- end }}
{{- end }}
{{- end }}

*This issue is automatically kept up-to-date on every push to main and nightly.*
{{- end }}
