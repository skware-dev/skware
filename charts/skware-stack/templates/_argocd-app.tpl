
{{- define "skware.app" -}}
{{- $helm := .helm }}
{{- $skware := .helm.Values.skware }}
{{- $app := .app }}

{{- /* Required app fiels */}}
{{- if not $app.repo }}
  {{- fail (printf "Application repository required for %s" $app.id) }}
{{- else if not (or $app.chart $app.path) }}
  {{- fail (printf "Application \"%s\" requires either \"chart\" or \"path\" to be set for repo \"%s\"" $app.id $app.repo) }}
{{- end }}

{{- /* Setting app name */}}
{{- $appName := $app.name | default $app.id }}
{{- /* Prefixing the app group release name to the app name if requested */}}
{{- if (index $skware "use-release-name") }}
  {{- $appName = printf "%s-%s" $helm.Release.Name $appName }}
{{- end }}

{{- /* Setting app ns */}}
{{- $appNS := (and (hasKey $app "namespace") (eq $app.namespace nil)) | ternary nil ($app.namespace | default $appName) }}

{{- /* Building app syncOptions from sync flags */}}
{{- $appSyncOpts := $app.argocd.syncOptions }}
{{- if not $appSyncOpts }}
  {{- $appSyncOpts = list }}
  {{- range $opt, $flag := $app.argocd.sync }}
  {{- $syncOpt := index $skware._argocd_sync $opt | default $opt }}
  {{- $appSyncOpts = mustAppend $appSyncOpts (printf "%s=%s" $syncOpt (toString $flag)) }}
  {{- end }}
{{- end }}

{{- if $skware.debug }}
---
########## DEBUG ##########
{{ $app.id }}: {{- toYaml $app | nindent 2 }}
syncOpts: {{- toYaml $appSyncOpts | nindent 2 }}
{{- end }}

---
# ArgoCD App:
#   App ID:   {{ $app.id }}
#   Name:     {{ $appName }}
#   NS:       {{ $appNS }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $appName }}
  namespace: argocd
  labels:
    {{- /* Stack & component */}}
    {{ $skware.package }}/component: {{ $appName | quote }}
    {{ $skware.package }}/part-of-stack: {{ $helm.Release.Name | quote }}
    {{- /* Custom Stack+app labels */}}
    {{- range $key, $val := mergeOverwrite (deepCopy $skware.labels) $app.labels }}
    {{ $skware.package }}/{{ $key }}: {{ $val | quote }}
    {{- end }}
    {{- if and $app.values $app.values.version }}
    {{- /* Handling versions of style "refs/heads/<branch>" */}}
    {{ $skware.package }}/values: {{ $app.values.version | splitList "/" | last | quote }}
    {{- end }}
    helm.sh/chart: {{ include "skware.chart" $helm }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ $app.wave | quote }}
    {{- with mergeOverwrite (deepCopy $skware.annotations) $app.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  finalizers:
    - argocd.argoproj.io/resources-finalizer
# https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/
spec:
  project: {{ $app.argocd.project }}
  sources:
    {{- if $app.sourcesSpec }}
    {{- toYaml $app.sourcesSpec | nindent 4 }}
    {{- else }}
    # Main application repo
    - repoURL: {{ $app.repo }}
      {{- /* Setting chart or path */}}
      {{ empty $app.chart | ternary "path" "chart" }}: {{ $app.chart | default $app.path }}
      {{- if $app.version }}
      targetRevision: {{ $app.version | quote }}
      {{- end }}
      {{- if or $app.include $app.exclude }}
      directory:
        {{- if $app.include }}
        include: {{ $app.include | quote }}
        {{- end }}
        {{- if $app.exclude }}
        exclude: {{ $app.exclude | quote }}
        {{- end }}
      {{- end }}
      {{- if or $app.releaseName $app.values $app.valuesObject }}
      helm:
        {{- if $app.releaseName }}
        releaseName: {{ $app.releaseName }}
        {{- end }}
        {{- if $app.values }}
        # User values files
        valueFiles:
          {{- range $file := $app.values.files }}
          - $values/{{ $file }}
          {{- end }}
        {{- end }}
        {{- if $app.valuesObject }}
        # User values object
        valuesObject: {{ toYaml $app.valuesObject | nindent 10 }}
        {{- end }}
      {{- end }}
    {{- if $app.values }}
    # User values repo
    - repoURL: {{ $app.values.repo }}
      {{- if $app.values.version }}
      targetRevision: {{ $app.values.version | quote }}
      {{- end }}
      ref: values
    {{- end }}
    {{- if $app.extra }}
    # Custom extra repo
    - repoURL: {{ required (printf "\"%s.extra.repo\" required" $app.id) $app.extra.repo }}
      {{- if $app.extra.version }}
      targetRevision: {{ $app.extra.version | quote }}
      {{- end }}
      {{- if $app.extra.path }}
      path: {{ $app.extra.path }}
      {{- end }}
      {{- if or $app.extra.include $app.extra.exclude }}
      directory:
        {{- if $app.extra.include }}
        include: {{ $app.extra.include | quote }}
        {{- end }}
        {{- if $app.extra.exclude }}
        exclude: {{ $app.extra.exclude | quote }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- end }}
  destination:
    server: {{ $app.argocd.cluster }}
    {{- if not (eq $appNS nil) }}
    namespace: {{ $appNS }}
    {{- end }}
  {{- with $app.argocd.syncPolicy }}
  syncPolicy: {{- . | toYaml |  nindent 4 }}
  {{- else }}
  syncPolicy:
    {{- /* Setting ArgoCD managed metadata if "CreateNamespace=true" in syncOptions */}}
    {{- if has "CreateNamespace=true" $appSyncOpts }}
    managedNamespaceMetadata:
      labels:
        app.kubernetes.io/managed-by: argocd
        app.kubernetes.io/instance: {{ $appName }}
        {{- with $app.argocd.nsLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- if $app.argocd.nsAnnotations }}
      annotations: {{- toYaml $app.argocd.nsAnnotations | nindent 8 }}
      {{- end }}
    {{- end }}
    {{- if $appSyncOpts }}
    syncOptions: {{- toYaml $appSyncOpts | nindent 6 }}
    {{- end }}
    {{- if $app.argocd.automated }}
    automated: {{- toYaml $app.argocd.automated | nindent 6 }}
    {{- end }}
  # retry:
  {{- with $app.argocd.ignoreDifferences }}
  ignoreDifferences: {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
{{- end }}
