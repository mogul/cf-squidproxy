# cf-squidproxy

## Why this project

To meet the requirements of NIST control SC-7, outbound traffic from cloud.gov-hosted applications should be restricted by default, and allowed only by explicit exception.

By deploying a proxy in a `public-egress` space, and the client applications in a `restricted-egress` space, you can implement SC-7 on cloud.gov.

This repository deploys Squid as the proxy application on an internal route. The proxy can be used by other applications using the normal `http_proxy` and `https_proxy` methods.

## Instructions

### Deploy the proxy on Cloud Foundry

1. Customize the vars.yml-template to uniquely name your app and route:

    ```bash
    $ cp vars.yml-template vars.yml
    $ $EDITOR vars.yml
    ```

2. Push the app:

    ```bash
    $ cf push --vars-file vars.yml
    ```

### Test the proxy is operating correctly

1. Watch the logs for the app in another window (or the cloud.gov dashboard):

    ```bash
    $ cf logs squid-proxy-ID
    ```

2. SSH into the application

    ```bash
    $ cf ssh squid-proxy-ID
    $ /tmp/lifecycle/shell
    ```

5. Test that the proxy is filtering connections:

    ```bash
    $ export squid=squid-proxy-ID.apps.internal:8080
    $ wget -e use_proxy=yes -e http_proxy=$squid -e https_proxy=$squid https://www.yahoo.com --no-check-certificate
    # The request should be forbidden
    $ wget -e use_proxy=yes -e http_proxy=$squid -e https_proxy=$squid https://wiki.squid-cache.org --no-check-certificate
    # The request should succeed
    ```

## TODO

- The allow-list content is hard-coded; it should be overridden if there's an env var or user-provided service with alternative content
- The demo instructions should include using `cf add-network-policy` to permit client traffic from a client app
- We should document the regexes that are permitted for the allow-list (just point to where Squid documents the regex flavor it uses)
- Figure out auth... Right now any cloud.gov app can use the proxy just by adding a network policy; it should require client creds
- Figure out if SSL for client connections is even possible; it doesn't look like the proxy standard supports using TLS for https_proxy connections, only http!
  - I remember hearing that every CF app has a client-certificate; can we use that?
  - If the platform starts encrypting c2c traffic (eg using IPsec) then it's a non-issue.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for additional information.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
