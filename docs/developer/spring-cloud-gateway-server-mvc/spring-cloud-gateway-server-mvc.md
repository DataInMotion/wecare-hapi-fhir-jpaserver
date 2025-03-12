<h1 align="center">Spring Cloud Gateway Server MVC</h1>

## Build Management

### Set up the Development Environment

You need to set up your development environment before you can do anything.

What you need:

* git
* JDK 21 or later
* Maven 3.9.9 or later

For example:

```
brew install jenv
brew install openjdk@21
```

Add the following lines to your shell startup file (~/.bash_profile, ~/.zshrc, etc.):

```
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
```

To set your JDK:

```
jenv global 21.0
```

### Development

The build supports the following Maven project profiles: dev and test.

To build the application:

```
# In the project's /backend/modules/spring-cloud-gateway-server-mvc directory

mvn clean install spring-boot:repackage

# or

mvn clean install -DskipTests=true spring-boot:repackage

# or

mvn clean install -Pdev spring-boot:repackage
mvn clean install -Ptest spring-boot:repackage
```

**Note:** `dev` is the active by default profile.

To run the application:

```
./mvnw spring-boot:run
```

Check the Spring Boot Actuator health endpoint:

```
curl http://localhost:4180/actuator/health
```

You should receive a JSON-formatted message saying {"status":"UP"} which indicates that everything is working fine.

To check the Gateway routes:

```
curl http://localhost:4180/actuator/gateway/routes
```

You should receive a JSON-formatted message:

```
[
    {
        "predicate": "Paths: [/fhir/**, /**], match trailing slash: true",
        "route_id": "hapi-fhir",
        "filters": [],
        "uri": "http://localhost:8080",
        "order": 0
    }
]
```

To stop the server (Ctrl+c).

## ❯ References

* okta Developer blog: [Secure Legacy Apps with Spring Cloud Gateway](https://developer.okta.com/blog/2020/01/08/secure-legacy-spring-cloud-gateway)
* okta Developer blog: [OAuth 2.0 Patterns with Spring Cloud Gateway](https://developer.okta.com/blog/2020/08/14/spring-gateway-patterns)
* Eyal Sofer - AT&T Israel Tech blog: [Spring Cloud Gateway MVC — Migration from Reactive one](https://medium.com/att-israel/spring-cloud-gateway-mvc-migration-from-reactive-one-ed2025efc165)
