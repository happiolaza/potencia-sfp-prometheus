{{- define "potencia-sfp-barracas.name" -}}
{{- if .Values.nameOverride -}}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "potencia-sfp-barracas.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "potencia-sfp-barracas.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "potencia-sfp-barracas.labels" -}}
helm.sh/chart: {{ include "potencia-sfp-barracas.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "potencia-sfp-barracas.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: "{{ .Chart.AppVersion }}"
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "potencia-sfp-barracas.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- include "potencia-sfp-barracas.fullname" . -}}
{{- end -}}
{{- end -}}
