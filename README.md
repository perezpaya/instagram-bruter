Yet another Instagram bruteforcer
--

```bash
docker build . -t instagram-bruter
docker run instagram-bruter -e TARGET_ACCOUNT=instagram -d
```

# Roadmap
- Docker based
- Tor circuit rotating
- Telegram control and messaging via Bot API
- Shared redis job queue to distribute jobs in different containers?

## Extra
- SecLists CLI
