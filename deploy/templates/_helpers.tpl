{{- define "potencia-site.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "potencia-site.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "potencia-%s" .Values.site.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "potencia-site.labels" -}}
helm.sh/chart: {{ include "potencia-site.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "potencia-site.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: "{{ .Chart.AppVersion }}"
app.kubernetes.io/managed-by: Helm
site: {{ .Values.site.name }}
environment: {{ .Values.site.environment }}
{{- end }}

{{- define "potencia-site.selectorLabels" -}}
app.kubernetes.io/name: {{ include "potencia-site.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
site: {{ .Values.site.name }}
{{- end }}

{{- define "potencia-site.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- include "potencia-site.fullname" . -}}
{{- end -}}
{{- end }}
