## Vault-mTLS-demo 
Vault를 이용한 mTLS 통신 자동화를 위한 데모입니다.

### Prerequistes

|Name|Version|
|---|---|
|Vault|Vault v1.12.2|


### mTLS란 무언인가
간단히 말해 기존에 클라이언트가 서버의 인증서를 검사하여 보안을 유지하는 방식에서 서버사 클라이언트의 인증서도 검사하는 방식의 클라이언트 인증 절차이다.


### 구성

#### 구성도
```mermaid
sequenceDiagram
```
##### 구성파일 다운로드
- git  clone https://github.com/kjjprivate/Vault-mTLS.git

#### 인증서 구성
##### vault 서버용 인증서 및 키 생성
vault 서버에서 사용할 인증서를 생성해줍니다. vault 서버의 경우 자체적인 서비스 제공을 위해 vault pki 엔진에서가 아닌 외부에서 가져온 인증서를 등록해주어야합니다.
- cd VAult-mTLS/cert
- openssl genrsa -out root.key 2048
- openssl req -config ca.conf -extensions usr_cert -new -key service.key -out service.csr
- openssl req -config ca.conf -extensions usr_cert -new -key root.key -out vault_server.csr            
- openssl x509 -req -days 3650 -in vault_server.csr -signkey root.key -extfile ca.ext -out vault_server.crt

##### 서비스(nginx)용 인증서 및 키 생성
nginx(클라이언트)와 vault 서버와의 통신을 위해 클라이언트 및 서비스용 인증서를 만들어주어야합니다.  
- openssl genrsa -out service.key 2048
- openssl req -config ca.conf -extensions usr_cert -new -key service.key -out service.csr
- openssl x509 -req -days 3650 -in service.csr -signkey service.key -extfile ca.ext -out service.crt

#### vault 서버 실행

##### vault config 확인
- cd ../vault_config
- cat config.hcl

vault config 내용은 다음과 같습니다.
lintener "tcp" 블록 내부에 mTLS 설정을 하게 됩니다.
```
ui=true

#vault enterprise를 사용하고 있다면 해당 부분에 라이센스파일 경로를 넣어주면 됩니다.
#license_path="./license/vault_ent_license.hclic"

storage "raft" {
 path    = "./raft_storage"
}

listener "tcp" {
 address = "127.0.0.1:8200"
 
 tls_cert_file="../cert/vault_server.crt"
 tls_key_file="../cert/root.key"

 # mTLS를 사용하도록 설정해줍니다.
 tls_require_and_verify_client_cert = "true"
 #client가 제출할 ca 파일을 설정해줍니다.
 tls_client_ca_file="../cert/service.crt"
}

api_addr="https://example.test:8200"
disable_mlock = true
cluster_addr = "https://example.test:8201"
```

