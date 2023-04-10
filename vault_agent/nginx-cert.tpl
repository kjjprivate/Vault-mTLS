{{- /* cert-a.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=example.test" "ttl=5m" }}
{{ .Data.certificate }}{{ end }}
