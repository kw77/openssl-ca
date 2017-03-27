################################################################
## PLEASE REMEMBER TO CHANGE:
##   -- The 'O' (organisation) in the DN
##   -- The CA 'CN' (certificate authority) in the DN
##   -- The output path for the server PFX, key, cert, CSR files (etc) - /opt is used below
##   -- If you can:
##   -- -- Create the server keys on the respective servers in question
##   -- -- Transfer the CSR to the CA
##   -- -- Sign the CSR and create the certs on the CA
##   -- -- Transfer the Cert back to the machine with the key
##   -- -- (such that the key never leaves the machine its for)
##   -- -- (and always remeber to protect the keys as read only to their respective user only)

# All this needs to be done with sudo rights to sudo -i and get on with it
sudo -i

# Create and switch to a new directory in /etc/ssl called ‘ca’
mkdir /etc/ssl/ca
cd /etc/ssl/ca

# Create the necessary subdirectory structure and empty files
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > crlnumber

# Generate a private key (enter the pass phrase to protect this when prompted) and mark it read only
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

# Check the new private key is ok (as with any key)
openssl rsa -in private/ca.key.pem -check

# Use the new /etc/ssl/openssl.cnf file from the config file set

# Create a new CA cert with the key from above, 10yr life, password protected
openssl req -new -x509 -days 3650 -key private/ca.key.pem -sha256 -extensions v3_ca -out certs/ca.cert.pem -subj "/C=GB/ST=X/L=/O=whateverOrg/OU=/CN=whateverCA/emailAddress=/"

# Test the CA cert works ok (as with any cert)
openssl x509 -in certs/ca.cert.pem -text -noout | more

# Create a password file for auto-signing certs - OPTIONAL - HANDLE WITH CARE
# echo password > private/pass
# chmod 400 private/pass

# Create a template CRL file
openssl ca -keyfile private/ca.key.pem -cert certs/ca.cert.pem -gencrl -out crl/crl.pem

# Test the CRL is ok
openssl crl -in crl/crl.pem -text

# Create server key and CSR
openssl req -new -nodes -newkey rsa:2048 -keyout /opt/myserver.key -subj /C=GB/ST=X/L=/O=whateverOrg/OU=/CN=serverURL -out /opt/myserver.csr

# Sign the server CSR
openssl ca -extensions usr_cert -notext -md sha256 -in /opt/myserver.csr -out /opt/myserver.cert

# Create server PFX/P12 file (single password protected file that contains the CA root cert, server key and server cert)
openssl pkcs12 -export -out /opt/myserver.pfx -inkey /opt/myserver.key -in /opt/myserver.cert -certfile /etc/ssl/ca/certs/ca.cert.pem
# Remove the CSR, key and cert files as desired
#

# Exit sudo -i
exit





## ADDITIONAL SSL SETUP NOTES
# CREATE SELF SIGNED CERT
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout chronos.key -out chronos.crt 

# CREATE P12 FROM CERT+KEY
openssl pkcs12 -export -out chronos.p12 -inkey chronos.key -in chronos.crt 

# CHECK P12 FILE
openssl pkcs12 -info -in chronos.pfx 

# LOAD P12 INTO NSSDB
pk12util -d sql:$HOME/.pki/nssdb -i <PKCS12_file.p12>

# LIST NSSDB CERTS
certutil -d sql:$HOME/.pki/nssdb -L

# CA CERT MANAGEMENT
update-ca-certificates  is  a  program  that  updates   the   directory
/etc/ssl/certs to hold SSL certificates and generates certificates.crt,
a concatenated single-file list of certificates.

It reads the file /etc/ca-certificates.conf. Each line gives a pathname
of  a  CA  certificate  under /usr/share/ca-certificates that should be
trusted.  Lines that begin with "#" are comment lines and thus ignored.
Lines  that  begin with "!" are deselected, causing the deactivation of
the CA certificate in question.

Furthermore   all   certificates   found   below   /usr/local/share/ca-
certificates are also included as implicitly trusted.

# ADDING CA ROOT CERT
http://turboflash.wordpress.com/2009/06/23/curl-adding-installing-trusting-new-self-signed-certificate/

- Copy CRT file to: /usr/share/ca-certificates (or appropriate sub directory)
- Add path to: /etc/ca-certificates.conf
- Run the command: update-ca-certificates –fresh

# USING CURL WITHOUT INSTALLING A CA CERT
openssl s_client -connect xxxxx.com:443 | tee thisServerCert
curl --cacert thisServerCert <rest-of-curl-command-as-normal>

# GENERATE A STANDALONG KEY
openssl genrsa -out domain.key 2048

# GENERATE A CERT SIGNING REQUEST (CSR)
openssl req -new -nodes -key domain.key -out domain.csr

# CREATE SELF SIGNED CERT FROM CSR
openssl x509 -req -days 3650 -in domain.csr -signkey domain.key -out domain.crt









## USER CERT SETUP SCRIPT
# USER/KEY/CERT CREATION SCRIPT
user=$1
pass=$2
cacert=/etc/ssl/ca/certs/ca.cert.pem
caindex=/etc/ssl/ca/index.txt
cacertdir=/etc/ssl/ca/newcerts
cakeypassfile=/etc/ssl/ca/private/pass
canickname="whateverCA - whateverOrg"
pfxpassfile=/etc/ssl/ca/scripts/pfxpassfile
blankfile=/etc/ssl/ca/scripts/blank

# ENSURE INPUT VARIABLES ARE SET
if [ -z "$user" ]; then
    echo "ERROR: No username provided, command usage 'create.sh <username> <password>"
    exit 1
fi

if [ -z "$pass" ]; then
    echo "ERROR: No password provided, command usage 'create.sh <username> <password>"
    exit 1
fi

# ENSURE SCRIPT RUNNING AS ROOT
if [ "$(id -u)" != "0" ]; then
   echo "ERROR: This script must be run as root"
   exit 2
fi

# TEST IF USER ALREADY EXISTS
if [ ! -z `id -u $user 2> /dev/null` ]; then
    echo "ERROR: User already exists; $user"
    exit 3
fi

# TEST IF HOME DIR EXISTS (REMOVE IF SO)
if [ -e /home/$user/ ]; then
    echo "WARN: Orphaned home directory being removed; $user"
    rm -rf /home/$user || { echo "ERROR: Orphaned home directory deletion failure"; exit 4; }
fi

# TEST IF CERTIFICATE ALREADY EXISTS (REVOKE IF SO)
cert_exists_id=`cat $caindex | grep -P "^V.*CN=${user}$" | sed -r 's/\s+/ /g' | cut -d ' ' -f3`
if [ ! -z $cert_exists_id ]; then
    echo "WARN: Valid user cert already exists, revoking; $user"
    openssl ca -revoke $cacertdir/$cert_exists_id.pem -key `cat $cakeypassfile` || { echo "ERROR: Certificate revocation failed"; exit 5; }
    openssl ca -gencrl -out crl/crl.pem -key `cat $cakeypassfile` || { echo "ERROR: CRL regeneration failure"; exit 6; }
fi

# CREATE THE NEW USER + HOME AREA
sudo useradd --create-home $1 || { echo "ERROR: User account creation failed"; exit 7; }

# SET THE USER PASSWORD
echo -e "${pass}\n${pass}" | passwd $user || { echo "ERROR: User password error"; exit 8; }

# GENERATE A PRIVATE KEY + CSR
openssl req -new -nodes -newkey rsa:4096 -keyout /home/$user/.pki/$user.key.pem -subj "/C=GB/ST=X/L=/O=whateverOrg/OU=/CN=$user/emailAddress=/" -out /home/$user/.pki/$user.csr.pem || { echo "ERROR: Private key generation failed"; exit 9; }

# CREATE CA SIGNED CERT
openssl ca -extensions usr_cert -notext -md sha256 -in /home/$user/.pki/$user.csr.pem -out /home/$user/.pki/$user.cert.pem -key `cat $cakeypassfile` -batch || { echo "ERROR: Certificate signing failed"; exit 10; }

# CREATE A PKCS12 FILE FROM KEY+CERT+CA FILES
openssl pkcs12 -export -out /home/$user/.pki/$user.pfx -inkey /home/$user/.pki/$user.key.pem -in /home/$user/.pki/$user.cert.pem -certfile $cacert -password pass:`cat $pfxpassfile` || { echo "ERROR: PKCS12 file creation failed"; exit 11; }



# CREATE AN NSSDB DATABASE FOR THE USER (BLANK PASSWORD)
certutil -N -d sql:/home/$user/.pki/nssdb/ -f $blankfile || { echo "ERROR: NSSDB creation failed"; exit 12; }
# NB: this needs a file therein called 'blank' with a single caridge return (ie. blank)

# CHANGE OWNERSHIP ON THE NSSDB DATABASE TO THE USER IN QUESTION
chown $user:$user /home/$user/.pki/nssdb/* || { echo "ERROR: NSSDB ownership change failed"; exit 13; }

# IMPORT THE PKCS12 FILE INTO THIS NSSDB DATABASE
pk12util -d sql:/home/$user/.pki/nssdb -i /home/$user/.pki/$user.pfx -w $pfxpassfile

# CHANGE THE TRUST ATTRIBUTES OF THE IMPORTED ROOT CA
certutil -d sql:/home/$user/.pki/nssdb -M -t "CT,C,C" -n "$canickname" || { echo "ERROR: NSSDB certificate import failed"; exit 14; }

# REMOVE THE PEM / PFX FILES (LEAVING ONLY THE NSSDB LOCALLY)
rm /home/$user/.pki/*.pem || { echo "ERROR: Pem file removal failed"; exit 15; }
rm /home/$user/.pki/*.pfx || { echo "ERROR: PFX file removal failed"; exit 16; }

















