package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/hashicorp/vault-client-go"
	"github.com/hashicorp/vault-client-go/schema"
)

func main() {

	for {
		tls := vault.TLSConfiguration{}

		tls.ClientCertificate.FromFile = "../cert/service/go-app-service.crt"
		tls.ClientCertificateKey.FromFile = "../cert/service/go-app-service.key"

		client, err := vault.New(
			vault.WithAddress("https://example.test:8443"),
			vault.WithTLS(tls),
		)
		if err != nil {
			log.Fatal(err)
			break
		}
		/*
			resp, err := client.Auth.CertificatesLogin(ctx, schema.CertificatesLoginRequest{
				Name: "my-cert",
			})
		*/
		request := schema.AppRoleLoginRequest{
			RoleId:   os.Getenv("MY_APPROLE_ROLE_ID"),
			SecretId: os.Getenv("MY_APPROLE_SECRET_ID"),
		}
		AppRoleLogin, err := client.Auth.AppRoleLogin(
			context.Background(),
			request,
		)
		if err != nil {
			log.Fatal(err)
			break
		}
		if err := client.SetToken(AppRoleLogin.Auth.ClientToken); err != nil {
			log.Fatal(err)
			break
		}

		AuthData, err := json.MarshalIndent(AppRoleLogin.Auth, "", "   ")
		if err != nil {
			log.Fatal("err:", err)
		}
		ClientToken := AppRoleLogin.Auth.ClientToken
		rsp, err := client.Secrets.KVv2Read(
			context.Background(),
			"secret",
			vault.WithToken(ClientToken),
		)
		if err != nil {
			log.Fatal(err)
		}

		kvData, err := json.MarshalIndent(rsp.Data, "", "   ")

		if err != nil {
			log.Fatal(err)
		}

		log.Println("AuthData:", string(AuthData))
		log.Println("secretData:", string(kvData))
		
		time.Sleep(10 * time.Second)

	}
	restart()
}
func restart() {
	procAttr := new(os.ProcAttr)
	procAttr.Files = []*os.File{os.Stdin, os.Stdout, os.Stderr}
	os.StartProcess(os.Args[0], []string{"", "test"}, procAttr)
}
