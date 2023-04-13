## Vault-mTLS-demo 
Vault를 이용한 mTLS 통신 자동화를 위한 데모입니다.

### Prerequistes
데모 테스트시 사용했던 환경입니다.

|Name|Version|
|---|---|
| Vault |Vault v1.12.2|
| Terraform |Terraform v1.3.6|
| go Lang |go1.19.5 darwin/amd64|
| nginx | nginx/1.23.4|
| mac OS | 13.0.1,  Intel Core i5|

### mTLS란 무언인가
간단히 말해 기존에 클라이언트가 서버의 인증서를 검사하여 보안을 유지하는 방식에서 서버사 클라이언트의 인증서도 검사하는 통신방식입니다.
mTLS 통신은 기관과 기관간의 통신에 주로 이용되고 client도 인증서를 통한 인증을 한번 받아야 통신을 할 수 있는 보안적인 장점이 있습니다.
다만 설정하는 과정에 서 추가적인 cpu리소스와 대역폭이 필요할 수도 있기에 고사양의 서버에서는 부담이 될 수 있고 사용 방식의 복잡겅 때문에 추가적인 설정과 관리가 필요해질 수 있습니다.


### 구성

#### 구성도
```sequence

Application -> Nginx
Nginx ->  Application
Nginx -> Vault
Vault -> Nginx


```
##### 구성파일 다운로드
```bash
git  clone https://github.com/kjjprivate/Vault-mTLS.git
```
#### 인증서 구성
hosts 파일을 수정하여 로컬호스트를를 사용할 수 있는 도메인을 만들어줍니다.
```bash
vi /etc/hosts
```
다음 내용을 hosts 파일에 추가합니다
```
127.0.0.1 example.test
```

##### vault 서버용 인증서 및 키 생성
vault 서버에서 사용할 인증서를 생성해줍니다. vault 서버의 경우 자체적인 서비스 제공을 위해 vault pki 엔진에서가 아닌 외부에서 가져온 인증서를 등록해주어야합니다.
```bash
cd VAult-mTLS/cert
openssl genrsa -out root.key 2048
openssl req -config ca.conf -extensions usr_cert -new -key root.key -out vault_server.csr            
openssl x509 -req -days 3650 -in vault_server.csr -signkey root.key -extfile ca.ext -out vault_server.crt
```

##### 서비스(nginx)용 인증서 및 키 생성
nginx(클라이언트)와 vault 서버와의 통신을 위해 클라이언트 및 서비스용 인증서를 만들어주어야합니다.  
```bash
openssl genrsa -out service.key 2048
openssl req -config ca.conf -extensions usr_cert -new -key service.key -out service.csr
openssl x509 -req -days 3650 -in service.csr -signkey service.key -extfile ca.ext -out service.crt
```
#### vault 서버 구성

##### vault config 확인
```bash
cd ../vault_config
cat config.hcl
```
vault config 내용은 다음과 같습니다.
lintener "tcp" 블록 내부에서 mTLS 설정을 하게 됩니다.
```plaintext
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

##### vault 서버 실행
vault 서버를 실행해줍니다.
```bash
mkdir raft_storage
vault server -config=config.hcl
```
###### troubleshooting


```
Error initializing storage of type raft: open raft_storage/node-id: no such file or directory
```
vault가 storage로 사용할 디렉토리가 없다는 뜻 입니다. 'raft_storage'라는 이름의 디렉토리를 새로 생성해줍니다.


```
Error initializing core: error reading license
```
만약 vault enterprise를 사용하시는 경우 vault의 라이센스를 config 파일이나 환경변수로 등록해주어야합니다.
```bash
export VAULT_LICENSE="put license"
or
#아래 내용을 config 파일에 추가해줍니다.
license_path="./path to license/vault_ent_license.hclic"
```

- log 
정상적으로 실행되면 아래와 같이 로그가 나옵니다.
```
==> Vault server configuration:

             Api Address: https://example.test:8200
                     Cgo: disabled
         Cluster Address: https://example.test:8201
              Go Version: go1.19.3
              Listener 1: tcp (addr: "127.0.0.1:8200", cluster address: "127.0.0.1:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "enabled")
               Log Level: info
                   Mlock: supported: false, enabled: false
           Recovery Mode: false
                 Storage: raft (HA available)
                 Version: Vault v1.12.2+ent, built 2022-11-23T21:33:30Z
             Version Sha: 9559f30fa31f7ae9e421f500daa0d72939ed313e

==> Vault server started! Log data will stream in below:

2023-04-11T15:26:45.803+0900 [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2023-04-11T15:26:45.887+0900 [INFO]  core: using autoloaded license: license="{\"license_id\":\"7b4a93b7-1be6-975c-8725-be00d8162c16\",\"customer_id\":\"6842ab33-7859-847f-24b9-a9048397dfa6\",\"installation_id\":\"*\",\"issue_time\":\"2022-06-17T07:03:40.296612181Z\",\"start_time\":\"2022-06-17T00:00:00Z\",\"expiration_time\":\"2023-06-17T23:59:59.999Z\",\"termination_time\":\"2023-06-17T23:59:59.999Z\",\"flags\":{\"modules\":[\"multi-dc-scale\",\"governance-policy\",\"advanced-data-protection-key-management\",\"advanced-data-protection-transform\"]},\"features\":[\"HSM\",\"Performance Replication\",\"DR Replication\",\"MFA\",\"Sentinel\",\"Seal Wrapping\",\"Control Groups\",\"Performance Standby\",\"Namespaces\",\"KMIP\",\"Entropy Augmentation\",\"Transform Secrets Engine\",\"Lease Count Quotas\",\"Key Management Secrets Engine\",\"Automated Snapshots\",\"Key Management Transparent Data Encryption\"],\"performance_standby_count\":9999}"
2023-04-11T15:26:45.908+0900 [INFO]  replication.perf.logshipper: Initializing new log shipper: max_elements=16384 max_bytes=858993459
2023-04-11T15:26:45.913+0900 [INFO]  replication.dr.logshipper: Initializing new log shipper: max_elements=16384 max_bytes=858993459
2023-04-11T15:26:45.917+0900 [INFO]  core: Initializing version history cache for core
```

##### vault 서버 초기 구성
vault 서버에 명령어를 보내기 전에 해야할 몇가지 작업이 있습니다.
1. vault 서버용으로 만든 인증서를 pc에서 신뢰하는 설정을 해주어야합니다.
- 맥북의 경우 생성한 vault_server.crt인증서를 더블 클릭하여 '키체인 접근'으로 이동해 준 다음 인증서를 신뢰하는 작업을 해주면 됩니다.
 ![vault_server_cert](../screesshot/certificate_auth.png)
- 윈도우의 경우 아래 링크를 참조합니다.
[윈도우 인증서 신뢰](https://cert.crosscert.com/%EC%9C%88%EB%8F%84%EC%9A%B0windows-%EC%9A%B4%EC%98%81%EC%B2%B4%EC%A0%9C-pc%EC%97%90%EC%84%9C-%EB%A3%A8%ED%8A%B8%EC%9D%B8%EC%A6%9D%EC%84%9C-%EC%84%A4%EC%B9%98%EB%B0%A9%EB%B2%95/)

2. vault사용을 위해 vault 서버를 init 해줍니다.
```bash
export VAULT_ADDR="https://example.test:8200"
vault operator init -key-shares=1 -key-threshold=1 -client-cert=../cert/service.crt -client-key=../cert/service.key
```
::: info
mtls 설정이 되어있는 상태이기 때문에 client는 vault 서버에 client용 인증서를 제출해주어야합니다.
해당 인증서는 -client-cert, -client-key 플래그를 활용해여 해도되고 ' VAULT_CLIENT_CERT', ' VAULT_CLIENT_KEY' 환경변수를 통해서 설정해주어야합니다.

-key-shares : 해당 플래그는 unseal key를 몇개 만들지에 대한 설정 값입니다. 데모 버전이므로 1개만 생성해줍니다.
-key-threshold: 해당 플래그는 vault를 잠금 해제할 때 몇개의 unseal key를 입력해주어야하는지에 대한 
:::

- init하면 다음과 같은 결과가 나옵니다. unseal key와 Initial root token은 따로 저장해줍니다.
```
Unseal Key 1: c/nQAhHiVAlJLbzlVfkd89I/zdQUn9yMmgjS2DURz5E=

Initial Root Token: hvs.Uv9Z0XCeHIhEfIuzGprvsRSy

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```
3. vault의 초기 구성은 항상 봉인되어있는 상태입니다. 해당 봉인은 unseal key를 이용하여 풀어주어야합니다.
```
vault operator unseal -client-cert=../cert/service.crt -client-key=../cert/service.key
```
결과
```
Unseal Key (will be hidden): 해당부분에 unsealkey를 넣어줍니다
```

4. vault 상태 확인
```bash
vault status -client-cert=../cert/service.crt -client-key=../cert/service.key
```

- 결과
```
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.12.2+ent
Build Date              2022-11-23T21:33:30Z
Storage Type            raft
Cluster Name            vault-cluster-004b4a3f
Cluster ID              61869346-03a1-b2ff-c39a-ffc461ef3e8c
HA Enabled              true
HA Cluster              https://example.test:8201
HA Mode                 active
Active Since            2023-04-12T01:17:18.881559Z
Raft Committed Index    417
Raft Applied Index      417
Last WAL                27
```
HA Mode가 active인 경우 정상적으로 작동하는 것을 의미합니다.

#### vault approle 인증방식 과 pki engine, kv engine 설정
해당 부분은 테라폼으로 진행됩니다.
approle 인증 방식의 경우 vault agent와 application이 vault에 인증하는데 사용됩니다. 자세한 설명은 하단 링크를 참조합니다.
[vault approle](https://developer.hashicorp.com/vault/docs/auth/approle)
pki secret engine은 vault에서 x.509의 인증서를 동적으로 생성합니다. 해당 기능과 vault agent를 이용하여 application간의 tls 통신을 위한 인증서를 자동으로 교체해줄 수 있습니다.
kv secret engine은 key/value 형식으로 암호나 파일 데이터를 저장할 수 있는 vault의 기능 중 하나입니다. 이후 진행할 application에서 vault에서 가져올 데이터 값으로 쓰입니다.

approle,pki,kv 3가지 기능들은 terraform 코드를 통해 자동으로 만들 수 있습니다. 해당 부분의 수동 작업이 궁금하신 경우 아래 명령어들을 참조하여 진행하시면 됩니다. 테라폼으로 진행하시는 경우 넘어가셔도 무방합니다.
- 수동 작업시 명령어 모음
```bash
$ export VAULT_ADDR=https://example.test:8200
$ export VAULT_CLIENT_CERT=../cert/service.crt
$ export VAULT_CLIENT_KEY=../cert/service.key
$ vault login [init 출력에 나온 root token]

$ vault secrets enable pki

$ vault secrets tune -max-lease-ttl=87600h pki

$ vault write pki/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

$ vault write pki/roles/example-dot-com \
    allowed_domains=example.test \
    allow_subdomains=true \
    max_ttl=72h \
    allow_any_name = true \
    allow_bare_domains = true 

$ vault policy write pki pki_policy.hcl

$ vault auth enable approle
$ vault write auth/approle/role/pki-agent \
    secret_id_ttl=120m \
    token_ttl=60m \
    token_max_tll=120m \
    policies="pki"

$ vault secrets enable -version=2 -path=secret kv
$ vault kv put -mount=secret my-secret zip=zap foo=bar
```


- 테라폼 사용
1. 테라폼 디렉토리로 이동해줍니다.
```bash
cd ../terraform
```
2. 테라폼 config를 수정해줍니다.
```bash
vi main.tf
```
테라폼 code안에서 vault provider 블록 내부를 수정해줍니다.
token값으로 사전에 저장해둔 Initial root token을 설정해주시면 됩니다.
provider 블록 내부에 client_auth 블록에서 클라이언트 인증서로 제출할 service.crt 와 service.key를 설정해줍니다.
```
provider "vault" {
  # vault server 의 주소를 지정해줍니다.
  address = "https://example.test:8200"
  # vault를 init한 후 생성된 root token을 넣어줍니다.
  token   = "root token"
  # mTLS 사용을 위해 사전에 생성한 client 인증서에 대한 설정을 해줍니다.
  client_auth {
    cert_file = "../cert/service.crt"
    key_file = "../cert/service.key"
  }
}

```
설정을 완료하시면 저장하고 나갑니다.

3. 테라폼 init 및 apply
테라폼의 provider를 설치해주기 위해 init 작업을 실행해줍니다.
```bash
terraform init
```
- 결과
```plaintext
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/vault versions matching "3.0.0"...
- Installing hashicorp/vault v3.0.0...
- Installed hashicorp/vault v3.0.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

apply 명령어를 통해 terraform으로 vault에 환경을 구성해줍니다.
```bash
terraform apply
```
yes를 입력해 계속해서 진행해줍니다.
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

##### vault agent 활성화
vault agent는 vault에서 비밀정보들을 자동으로 가져오거나 자동으로 인증하는 등의 역할을 해주는 소프트웨어 프로그램입니다.
[vault agent](https://developer.hashicorp.com/vault/docs/agent)

1. 디렉토리 이동
```bash
cd ../vault_agent
```
2. vault_agent template 확인, tpl 확장자를 가진 템플릿들에 의해 특정 파일로 vault에서 받은 ca,인증서,key들을 랜더링 할 수 있습니다.
```bash
cat nginx-ca.tpl
```
- ca 템플릿
```plaintext
{{- /* ca-a.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=example.test" "ttl=10h" }}
{{ .Data.issuing_ca }}{{ end }}
```
3. vault agent 실행을 위해 테라폼으로 구성한 approle로부터 roleid와 secretid를 받아옵니다.

```bash
#vault에 로그인해줍니다.
export VAULT_ADDR=https://example.test:8200
vault login -client-cert=../cert/service.crt -client-key=../cert/service.key [Initial root token] 

#vault agent가 인증받기 위한 roleid와 secretid를 생성해줍니다
vault read -field=role_id -client-cert=../cert/service.crt -client-key=../cert/service.key auth/approle/role/role1/role-id > roleid
vault write -client-cert=../cert/service.crt -client-key=../cert/service.key -f -field=secret_id auth/approle/role/role1/secret-id > secretid
```
roleid와 secretid를 통해 agent가 vault에 인증하고 pki engine으로부터 ca,인증서,key들을 주기적으로 받아옵니다.

4. vault agent 실행

vault_agent 파일의 내용에 따라 다음과 같은 위치에 템플릿으로 받은 파일들을 전달합니다.
```plaintext

# nginx가 사용할 인증서의 위치를 '../cert/nginx/'로 설정합니다.
template {
  source      = "nginx-ca.tpl"
  destination = "../cert/nginx/nginx-ca.crt"
}

...

# application이 사용할 인증서의 위치를 '../cert/service/'로 설정합니다.
template {
  source      = "service-cert.tpl"
  destination = "../cert/service/go-app-service.crt"
}
```

- vault agent 실행
```bash
vault agent -client-cert=../cert/service.crt -client-key=../cert/service.key -config=vault_agent.hcl -log-level=debug
```
- 성공하면 다음과 같은 로그가 출력됩니다.
```
2023-04-12T14:14:31.319+0900 [DEBUG] (runner) all templates rendered
```

#### nginx 설정 
application이 접근할 수 있도록 로드밸런서 목적의 nginx를 설정해줍니다.

1. nginx conf 확인
```bash
cat ../nginx/nginx.conf
```

- nginx conf
server 설정의 ssl_cetificate,key,client_certificate 는 현재 vault agent가 랜더링하고 있는 nginx 파일들을 넣어줍니다.
해당 부분은 client,application이 nginx와 mTLS통신을 하기위한 설정입니다. client_certificate는 ca파일로 들어가고 client는 해당 ca로 만들어진 인증서를 통해 mTLS 통신을 유지합니다.

location 블록 의 proxy_ssl_certificate 설정을 통해 인증서와 키를 넣어줍니다. 해당 location 부분은 nginx port로 들어오는 부분을 vault로 전달해주는 역할을 합니다.
vault와 nginx의 mtls 통신을 위해 처음에 수동으로 만들어줬던 vault_server 인증서와 service 인증서를 넣어주어야합니다.
```plaintext
server {
      listen                  8443 ssl;

#      access_log /path/to/access.log;
#      error_log /path/to/error.log;


      #nginx가 mTLS를 설정할 떄 사용할 인증서와 키를 설정합니다.
      ssl_certificate         /path/to/cert/nginx/nginx.crt;
      ssl_certificate_key     /path/to/cert/nginx/nginx.key;
      ssl_protocols           TLSv1.2 TLSv1.3;
      
      #mTLS 서비스를 사용할 때 사용하는 client 인증서의  ca 파일을 넣어줍니다.
      ssl_client_certificate  /path/to/cert/nginx/nginx-ca.crt;
      ssl_verify_client       on;
      ssl_verify_depth        2;

    location / {
        if ($ssl_client_verify != SUCCESS) { return 403; }
        
        ##구성##
        #8200 port는 vault를 대상으로합니다.
        proxy_pass https://example.test:8200;

        #ssl설정을 킵니다.
        proxy_ssl_verify on;
        
        #nginx가 vault 서버에 제출할 client인증서와 키를 설정해줍니다.
        proxy_ssl_certificate /path/to/cert/service.crt;
	    proxy_ssl_certificate_key /path/to/cert/service.key;
	    proxy_ssl_protocols TLSv1.2 TLSv1.3;

        #vault서버의 ca인증서를 신뢰해주는 설정입니다.
	    proxy_ssl_trusted_certificate /path/to/cert/vault_server.crt;
        proxy_ssl_verify_depth        2;
      }
   }
```

2. nginx 실행
```
brew services start
```
:::info
현재 환경은 맥 amd64환경에서 진행하고 있습니다. 만약 ubnutu나 window의 경우 다른 방식으로 nginx 서비스를 restart해주어야합니다.
:::

#### application 실행
1. vault agent가 만든 nginx ca 인증서 신뢰하기
./cert/nginx/ 경로의 nginx-ca.crt 인증서를 각 os 맞는 방식으로 신뢰해주어야합니다.
이전 단계의 vault server 인증서를 신뢰해주었던 방식대로 인증서롤 키체인에 등록해줍니다.

2. application 내용 확인
``` bash
cat go_app.go
```

application 또한 nginx와의 mtls를 위해 client application을 설정해주어야합니다. 
아래 설정된 인증서는 vault-agent가 랜더링해온 client용 인증서입니다. 해당 인증서를 제출함으로써 nginx와의 통신이 가능해집니다.
```go
tls.ClientCertificate.FromFile = "../cert/service/go-app-service.crt"
tls.ClientCertificateKey.FromFile = "../cert/service/go-app-service.key"
```

MY_APPROLE_ROLE_ID 와 MY_APPROLE_SECRET_ID를 환경변수 값으로 각각 approle의 roleid와 secretid를 설정해줍니다.
```go
request := schema.AppRoleLoginRequest{
			RoleId:   os.Getenv("MY_APPROLE_ROLE_ID"),
			SecretId: os.Getenv("MY_APPROLE_SECRET_ID"),
		}
```

등록된 roleid와 secretid를 통해 application은 approle 방식으로 vault에 로그인하고 토큰을 발급해줍니다.
```go
	AppRoleLogin, err := client.Auth.AppRoleLogin(
			context.Background(),
			request,
		)
```

approle 인증을 통해 발급 받은 토큰으로 vault에 인증하여 테라폼으로 구성해놨던 kv secret engine의 데이터들을 가져옵니다.
```go
ClientToken := AppRoleLogin.Auth.ClientToken
		rsp, err := client.Secrets.KVv2Read(
			context.Background(),
			"secret",
			vault.WithToken(ClientToken),
		)
```

로그로 approle 방식의 인증 데이터들과 kv secret engine으로부터의 데이터들을 출력해줍니다
```go
		log.Println("AuthData:", string(AuthData))
		log.Println("secretData:", string(kvData))
```

- log
log는 approle인증을 통해 나온 AuthData와 kv engine에 접근하여 얻는 secretData를 계속해서 출력해줍니다.

```
2023/04/12 16:05:56 AuthData: {
   "client_token": "hvs.CAESILjRj6cf7-7YGKQq3RgVu0JtxNxsPvOKmHQRJR59VxoaGiEKHGh2cy5tdlppUHE0VmdLT2J1ZGpkNlJqYkJtUHYQ-QM",
   "accessor": "lR8zBARgxkCXfASUrzugR8tT",
   "policies": [
      "default",
      "pki-policy"
   ],
   "token_policies": [
      "default",
      "pki-policy"
   ],
   "identity_policies": null,
   "metadata": {
      "role_name": "role1"
   },
   "orphan": true,
   "entity_id": "952d3268-4e9d-0cb3-90a7-8cb892b24e12",
   "lease_duration": 2764800,
   "renewable": true
}
2023/04/12 16:05:56 secretData: {
   "data": {
      "foo": "bar",
      "zip": "zap"
   },
   "metadata": {
      "created_time": "2023-04-12T04:38:26.943972Z",
      "custom_metadata": {
         "bar": "12345",
         "foo": "vault@example.com"
      },
      "deletion_time": "",
      "destroyed": false,
      "version": 1
   }
}
```


## TroubleShooting



- application 인증서 만료 error 메시지 
계속해서 application을 실행하면 5분정도 application을 실행하다보면 중간에 인증서가 만료되었다는 메세지가 나옵니다. 해당 메세지는 nginx가 사용하고 있던 인증서가 중간에 만료되고 vault agent가 만든 새로운 인증서가 대체되었기 때문에 발생한 에러 메시지 입니다. 이럴 경우 nginx를 재시작해주고 application을 다시 실행해주면 문제가 해결됩니다.
```
2023/04/12 16:06:10 Post "https://example.test:8443/v1/auth/approle/login": x509: certificate has expired or is not yet valid: “example.test” certificate is expired
```
:::info
 아직은 nginx가 인증서 파일이 교체 되었을 때 자동으로 재시작하는 방법을 찾지 못했습니다. 만약 해당 에러를 근본적으로 해결하지 못할 경우 pyhton flask 같은 로드밸런서를 직접 구축해야하는 방법을 찾아야할 것 같습니다.
:::
