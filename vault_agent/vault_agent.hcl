pid_file = "pidfile"

auto_auth {
  method  {
    type = "approle"
    config = {
      role_id_file_path = "roleid"
      secret_id_file_path = "secretid"
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
  destination = "../cert/nginx/nginx-ca.crt"
}

template {
  source      = "nginx-cert.tpl"
  destination = "../cert/nginx/nginx.crt"
}

template {
  source      = "nginx-key.tpl"
  destination = "../cert/nginx/nginx.key"
}

template {
  source      = "service-key.tpl"
  destination = "../cert/service/go-app-service.key"
}
template {
  source      = "service-cert.tpl"
  destination = "../cert/service/go-app-service.crt"
}
