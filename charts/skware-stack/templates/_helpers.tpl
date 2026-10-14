
{{/* Create chart name and version as used by the chart label. */}}
{{- define "skware.chart" }}
{{- printf "%s-%s" $.Chart.Name $.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Label Domain */}}
{{- define "skware.package" -}}
skware.app
{{- end }}

{{/* Common labels */}}
{{- define "skware.labels" -}}
helm.sh/chart: {{ include "skware.chart" $ }}
{{- /*- app.kubernetes.io/managed-by: {{ $.Chart.Name }} */}}
{{ include "skware.package" $ }}/version: {{ $.Chart.AppVersion | quote }}
{{ include "skware.package" $ }}/type: skware-app
{{ include "skware.package" $ }}/stack: {{ $.Release.Name }}
{{- end }}

