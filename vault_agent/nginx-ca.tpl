{{- /* ca-a.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=example.test" "ttl=10h" }}
{{ .Data.issuing_ca }}{{ end }}
