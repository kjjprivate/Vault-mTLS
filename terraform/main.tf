terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.14.0"
    }
  }
}

provider "vault" {
  # vault server 의 주소를 지정해줍니다.
  address = "https://example.test:8200"
  # vault를 init한 후 생성된 root token을 넣어줍니다.
  token   = "hvs.Uv9Z0XCeHIhEfIuzGprvsRSy"
  # mTLS 사용을 위해 사전에 생성한 client 인증서에 대한 설정을 해줍니다.
  client_auth {
    cert_file = "../cert/service.crt"
    key_file = "../cert/service.key"
  }
}

# vault policy를 생성합니다.
resource "vault_policy" "pki-policy" {
  name = "pki-policy"
  # vault의 모든 경로에 대한 생성, 읽기, 업데이트, sudo, delete 권한을 부여합니다.
  policy = <<EOT
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# List enabled secrets engine
path "sys/mounts" {
  capabilities = [ "read", "list" ]
}

# Work with pki secrets engine
path "pki/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

path "secret/*" {
  capabilities = ["read"]
}
EOT
}

# vault approle인증 방식을 활성화 시킵니다.
resource "vault_auth_backend" "approle" {
  type = "approle"
}

# approle 인증에 사용할 역할을 만들어 줍니다.
resource "vault_approle_auth_backend_role" "role1" {
  backend        = vault_auth_backend.approle.path
  role_name      = "role1"
  token_policies = ["default", "pki-policy"]
}

##vault pki engine 사용하도록 enable설정을 해줍니다.
resource "vault_mount" "pki" {
  path                      = "pki"
  type                      = "pki"
  default_lease_ttl_seconds = 360000
  max_lease_ttl_seconds     = 864000
}

#vault pki 시크릿 엔진의 root 인증서에 대한 config를 설정해줍니다.
resource "vault_pki_secret_backend_root_cert" "test" {
  depends_on           = [vault_mount.pki]
  backend              = vault_mount.pki.path
  type                 = "internal"
  format               = "pem"
  key_type             = "rsa"
  exclude_cn_from_sans = true
  key_bits             = 2048
  #private_key_format   = "pem"
  #signature_bits       = 256
  country              = "KR"
  province             = "Seoul"
  locality             = "KR"
  organization         = "COMPANY"
  ou                   = "DEV"
  common_name          = "exmaple.test"
  ttl                  = 864000
}

resource "vault_pki_secret_backend_config_urls" "example" {
  backend                 = vault_mount.pki.path
  crl_distribution_points = [
    "http://127.0.0.1:8200/v1/pki/crl"
    ]

  issuing_certificates = [
    "http://127.0.0.1:8200/v1/pki/ca",
  ]
}

#backend role을 통해 example.test 도메인에 대한 인증서를 발급 받기위한 설정을 해줍니다.
resource "vault_pki_secret_backend_role" "role" {
  backend          = vault_mount.pki.path
  name             = "example-dot-com"
  allowed_domains  = ["example.test"]
  allow_subdomains = true
  enforce_hostnames = false
  ## 정규 도메인(.com,net 등)이 아닌 프라이빗한 도메인도 사용가능하도록 하는 설정입니다.
  allow_any_name = true
  allow_bare_domains = true
  
}


#go app에서 사용할 vault의 secret을 만들어줍니다.
#해당 부분에서는 kv엔진을 이용해 간단한 secret을 만들어주었습니다.
resource "vault_mount" "kvv2" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}
resource "time_sleep" "wait_3_seconds" {
  depends_on = [vault_mount.kvv2]
  create_duration = "3s"
}

resource "vault_kv_secret_v2" "example" {
  depends_on = [time_sleep.wait_3_seconds]
  mount                      = vault_mount.kvv2.path
  name                       = "secret"
  cas                        = 1
  delete_all_versions        = true
  data_json                  = jsonencode(
  {
    zip       = "zap",
    foo       = "bar"
  }
  )
  custom_metadata {
    max_versions = 5
    data = {
      foo = "vault@example.com",
      bar = "12345"
    }
  }
}
