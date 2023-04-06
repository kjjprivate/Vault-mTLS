ui=true

license_path="./license/vault_ent_license(1year).hclic"

storage "raft" {
 path    = "./raft_storage"
}

listener "tcp" {
 address = "127.0.0.1:8200"
 
 tls_cert_file="../cert/vault_server.crt"
 tls_key_file="../cert/vault_server.key"

 tls_require_and_verify_client_cert = "true"
 tls_client_ca_file="../cert/client.crt"
}

api_addr="https://example.test:8200"
disable_mlock = true
cluster_addr = "https://example.test:8201"
