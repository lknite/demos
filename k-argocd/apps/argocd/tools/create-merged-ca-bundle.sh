# Start with onprem cert

CA=dc.home.net
ENCODED=`echo QUIT | openssl s_client -showcerts $CA:443 2>/dev/null </dev/null \
    | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' \
    | base64 -w 0`

echo $ENCODED | base64 -d > ca-bundle.crt

# Append local certs from default ca-bundle
cat /etc/ssl/certs/ca-bundle.crt >> ca-bundle.crt

# Create ca-bundle configmap, start with standard header
cat << EOF >> ./ca-bundle.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ca-bundle
data:
  ca-bundle.crt: |
EOF

# Append certs with indentation
cat ./ca-bundle.crt | sed 's/^/\ \ \ \ /g' >> ./ca-bundle.yaml

# Copy to templates
cp ./ca-bundle.yaml ../base/templates/

# Remove temp files
rm ./ca-bundle.crt
rm ./ca-bundle.yaml
