{{- /* key-a.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=example.test" "ttl=5m" }}
{{ .Data.private_key }}{{ end }}
