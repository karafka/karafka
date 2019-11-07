mkdir -p dsa rsa;

# Download chain from https://support.sectigo.com/Com_KnowledgeDetailPage?Id=kA01N000000rfBO
curl -L "https://comodoca.my.salesforce.com/sfc/dist/version/download/?oid=00D1N000002Ljih&ids=0681N0000068m6O&d=%2Fa%2F1N0000000wpm%2Fkl3HntphwNDtm3bNN4i7BZ0QYKgC14ONQOi8Cq1XTQM&asPdf=false" > client.chain;
# Generate CA
echo "=> Generate CA"
openssl genrsa -out ca.key 2048;
openssl req -x509 -new -nodes -subj "/C=PL/ST=Lesser Poland/L=Cracow/O=Karafka" -key ca.key -days 365 -out ca.crt;
# Generate client RSA
echo "=> Generate client RSA"
openssl genrsa -out rsa/valid.key 2048;
openssl req -new -key rsa/valid.key -subj "/C=PL/ST=Lesser Poland/L=Cracow/O=Karafka" -out rsa/client.csr;
openssl x509 -req -in rsa/client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out rsa/client.crt -days 365;

# Generate client DSA
echo "=> Generate client DSA"
openssl dsaparam -out dsa/dsaparam.pem 2048;
openssl gendsa -out dsa/valid.key dsa/dsaparam.pem
openssl req -new -key dsa/valid.key -subj "/C=PL/ST=Lesser Poland/L=Cracow/O=Karafka" -out dsa/client.csr;
openssl x509 -req -in dsa/client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out dsa/client.crt -days 365;
