pid_file = "pidfile"

auto_auth {
  method  {
    type = "approle"
    config = {
      role_id_file_path = "role_id"
      secret_id_file_path = "secret_id"
    }
  }

  sink {
    type = "file"
    config = {
      path = "/tmp/vault_agent"
    }
  }
}

vault {
  address = "https://example.test:8200"
}

template {
  source      = "nginx-ca.tpl"
  destination = "../cert/ca.crt"
}

template {
  source      = "nginx-cert.tpl"
  destination = "../cert/nginx.crt"
}

template {
  source      = "nginx-key.tpl"
  destination = "../cert/nginx.key"
}
