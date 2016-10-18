#
# Redirect only root domain
# no other subdomains.
#
if ($host = 'mysite.com') {
    return 301 $scheme://www.mysite.com$request_uri;
}