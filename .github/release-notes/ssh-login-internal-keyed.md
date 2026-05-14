Login with the private key matching the baked-in public key:

```bash
ssh -i <matching-private-key> -p 2222 medadmin@localhost
```

This release uses **internal-keyed** SSH mode: the admin public key was baked into the image at build time.
