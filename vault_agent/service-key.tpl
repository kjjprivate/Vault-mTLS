{{- /* key-a.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=example.test" "ttl=2m" }}
{{ .Data.private_key }}{{ end }}
