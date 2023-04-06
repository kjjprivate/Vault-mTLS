terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.0.0"
    }
  }
}

provider "vault" {
  # vault server 의 주소를 지정해줍니다.
  address = "https://example.test:8200"
  token   = "hvs.z9hfMmOV1rNamIcO3z5jUH64"
  # vault server에 인증을 위한 값을 넣어줍니다.
  client_auth {
    cert_file = "/Users/hiros/Documents/Git_kjjprivate/Vault-mTLS-demo/cert/client.crt"
    key_file = "/Users/hiros/Documents/Git_kjjprivate/Vault-mTLS-demo/cert/vault_server.key"
  }
  #auth_login {
  #path = "auth/approle/login"
  #parameters = {
  #  role_id   = var.login_approle_role_id
  #  secret_id = var.login_approle_secret_id
  #}
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
path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
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



/*
output "approle_role_id" {
  value = vault_approle_auth_backend_role.role1.role_id
}

output "approle_secret_id" {
  value = vault_approle_auth_backend_role_secret_id.role1.secret_id
}
*/


##vault pki engine 사용
resource "vault_mount" "pki" {
  path                      = "pki"
  type                      = "pki"
  default_lease_ttl_seconds = 360000
  max_lease_ttl_seconds     = 864000
}

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

resource "vault_pki_secret_backend_role" "role" {
  backend          = vault_mount.pki.path
  name             = "example-dot-com"
  ttl              = "72h"
  allowed_domains  = ["example.test"]
  allow_subdomains = true
}
