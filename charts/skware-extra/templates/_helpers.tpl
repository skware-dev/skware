{{/* Expand the name of the chart. */}}
{{- define "skware.name" }}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}



{{/* Create chart name and version as used by the chart label. */}}
{{- define "skware.chart" }}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}



{{/* Common labels */}}
{{- define "skware.labels" -}}
app.kubernetes.io/managed-by: {{ include "skware.name" . }}
{{ include "skware.selectorLabels" . }}
{{- end }}

{{/* Selector labels */}}
{{- define "skware.selectorLabels" -}}
skware.io/version: {{ .Chart.AppVersion | quote }}
skware.io/instance: {{ .Release.Name }}
{{- end }}





