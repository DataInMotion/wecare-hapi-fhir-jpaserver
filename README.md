# Deployment  WeCaRe HAPI FHIR Keycloak OAuth 2.0

Getting started HAPI FHIR

https://github.com/hapifhir/hapi-fhir-jpaserver-starter?ref=rob-ferguson

## Ideas and base from HAPI FHIR AU from Rob Ferguson

Starting point [getting started](https://rob-ferguson.me/getting-started-with-hapi-fhir/) and [+ OAuth Part 1](https://rob-ferguson.me/add-authn-to-hapi-fhir-with-oauth2-proxy-nginx-and-keycloak-part-1/)

Github: 

* https://github.com/Robinyo/hapi-fhir-jpaserver-starter
* https://github.com/Robinyo/hapi-fhir-au/

* Rob Ferguson's blog: [Getting Started with HAPI FHIR](https://rob-ferguson.me/getting-started-with-hapi-fhir/)
* Rob Ferguson's blog: [HAPI FHIR and FHIR Implementation Guides](https://rob-ferguson.me/hapi-fhir-and-fhir-implementation-guides/) 
*  Rob Ferguson's blog: [HAPI FHIR and AU Core Test Data](https://rob-ferguson.me/hapi-fhir-and-au-core-test-data/)



## Docker Deployment

Parts:

* nginx 
* redis
* hapi-fhir
* postgres
* keycloak
* oauth2-proxy

build using Dockerfiles in ```services/<part>/Dockerfile``` 

### keycloak

Development realm data will be imported on startup from in ```development-realm.json```. To export realm changes:

```
docker compose stop
docker compose -f docker-compose-keycloak-realm-export.yml up -d
docker compose -f docker-compose-keycloak-realm-export.yml stop
docker compose -f docker-compose-keycloak-realm-export.yml down
docker compose up -d
```



## Adapting for WeCaRe

```/.env``` contains specific configurations 

Do update password and secrets. 

To update the OAuth CLIENT_SECRET you have to generate a new Client Secret in the oauth2-proxy Client in the hapi-fhir-dev realm:

![oauth2-proxy client](docs/oauth2-proxy.png)

To update the URLs consider: development-realm.json

## SSL Certificates 

For development  [mkcert](docs/developer/mkcert.md) 

For prod [Let's Encrypt](docs/developer/lets-encrypt.md) 

## Customization 

Customization for the web interface of the hapi server comes from ```custom-hapi-theme/```. The "wecare" keycloak theme comes from ```custom-keycloak-theme/``` it's a adapted copy of the "keycloak v2" theme with the WeCaRe logo in it.