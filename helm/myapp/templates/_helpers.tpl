{{/*
helm/myapp/templates/_helpers.tpl
Named templates shared across all chart resources.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.global.projectName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "myapp.fullname" -}}
{{- printf "%s-%s" .Values.global.projectName .Values.global.environment | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Chart label — includes chart name and version.
*/}}
{{- define "myapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource — used for grouping and
Helm upgrade tracking.
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
project: {{ .Values.global.projectName }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels — used in matchLabels and Service selectors.
Must be stable (never change after first install, or rolling updates break).
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
App component selector — for the Django/Gunicorn pods.
*/}}
{{- define "myapp.appSelectorLabels" -}}
{{ include "myapp.selectorLabels" . }}
component: app
{{- end }}

{{/*
Redis component selector.
*/}}
{{- define "myapp.redisSelectorLabels" -}}
{{ include "myapp.selectorLabels" . }}
component: redis
{{- end }}

{{/*
Namespace — either the chart value or the release namespace.
*/}}
{{- define "myapp.namespace" -}}
{{- if .Values.namespace.create -}}
{{ .Values.namespace.name }}
{{- else -}}
{{ .Release.Namespace }}
{{- end }}
{{- end }}
