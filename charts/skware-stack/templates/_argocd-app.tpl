
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

{{- if $skware.debug }}
---
{{ $app.id }}: ### DEBUG ###
  {{- toYaml $app | nindent 2 }}
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
    {{- include "skware.labels" $helm | nindent 4 }}
    {{- if and $app.values $app.values.version }}
    {{ $app.id }}/values-version: {{ $app.values.version | quote }}
    {{- end }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ $app.wave | quote }}
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
  syncPolicy:
    {{- /* Setting ArgoCD managed metadata if "CreateNamespace=true" in syncOptions */}}
    {{- if has "CreateNamespace=true" $app.argocd.syncOptions }}
    managedNamespaceMetadata:
      labels:
        app.kubernetes.io/managed-by: argocd
        app.kubernetes.io/instance: {{ $appName }}
    {{- end }}
    {{- with $app.argocd.syncOptions }}
    syncOptions: {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if $app.argocd.automated }}
    automated: {{- toYaml $app.argocd.automated | nindent 6 }}
    {{- end }}
  {{- with $app.argocd.ignoreDifferences }}
  ignoreDifferences: {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
