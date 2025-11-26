import base64
secret = b'INSERT THE Base64URL OF ACCESS TOKEN SECRET HERE'
encoded = base64.urlsafe_b64encode(secret).decode('utf-8').rstrip('=')
print(encoded)


# or use  
# echo -n "YOUR_SECRET_STRING_HERE" \
# | base64 \
# | tr '+/' '-_' \
# | tr -d '='
