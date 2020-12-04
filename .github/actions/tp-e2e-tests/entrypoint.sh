#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#set -e

download_go() {
	. build/functions.sh
	if verify_and_set_go_version; then
		return
	fi
	go_version="$(cat "${GITHUB_WORKSPACE}/GO_VERSION")"
	wget -O go.tar.gz "https://dl.google.com/go/go${go_version}.linux-amd64.tar.gz"
	echo "Extracting Go ${go_version}..."
	<<-'SUDO_COMMANDS' sudo sh
		set -o errexit
		go_dir="$(
			dirname "$(
				dirname "$(
					realpath "$(
						which go
						)")")")"
		mv "$go_dir" "${go_dir}.unused"
		tar -C /usr/local -xzf go.tar.gz
	SUDO_COMMANDS
	rm go.tar.gz
	go version
}

gray_bg="$(printf '%s%s' $'\x1B' '[100m')";
red_bg="$(printf '%s%s' $'\x1B' '[41m')";
yellow_bg="$(printf '%s%s' $'\x1B' '[43m')";
black_fg="$(printf '%s%s' $'\x1B' '[30m')";
color_and_prefix() {
	color="$1";
	shift;
	prefix="$1";
	normal_bg="$(printf '%s%s' $'\x1B' '[49m')";
	normal_fg="$(printf '%s%s' $'\x1B' '[39m')";
	sed "s/^/${color}${black_fg}${prefix}: /" | sed "s/$/${normal_bg}${normal_fg}/";
}

ciab_dir="${GITHUB_WORKSPACE}/infrastructure/cdn-in-a-box";
trafficvault=trafficvault;
start_traffic_vault() {
	<<-'/ETC/HOSTS' sudo tee --append /etc/hosts
		172.17.0.1    trafficvault.infra.ciab.test
	/ETC/HOSTS

	<<-'BASH_LINES' cat >infrastructure/cdn-in-a-box/traffic_vault/prestart.d/00-0-standalone-config.sh;
		TV_FQDN="${TV_HOST}.${INFRA_SUBDOMAIN}.${TLD_DOMAIN}" # Also used in 02-add-search-schema.sh
		certs_dir=/etc/ssl/certs;
		X509_INFRA_CERT_FILE="${certs_dir}/trafficvault.crt";
		X509_INFRA_KEY_FILE="${certs_dir}/trafficvault.key";

		# Generate x509 certificate
		openssl req -new -x509 -nodes -newkey rsa:4096 -out "$X509_INFRA_CERT_FILE" -keyout "$X509_INFRA_KEY_FILE" -subj "/CN=${TV_FQDN}";

		# Do not wait for CDN in a Box to generate SSL keys
		sed -i '0,/^update-ca-certificates/d' /etc/riak/prestart.d/00-config.sh;

		# Do not try to source to-access.sh
		sed -i '/to-access\.sh\|^to-enroll/d' /etc/riak/{prestart.d,poststart.d}/*
	BASH_LINES

	DOCKER_BUILDKIT=1 docker build "$ciab_dir" -f "${ciab_dir}/traffic_vault/Dockerfile" -t "$trafficvault" 2>&1 |
		color_and_prefix "$gray_bg" "building Traffic Vault";
	echo 'Starting Traffic Vault...';
	docker run \
		--detach \
		--env-file="${ciab_dir}/variables.env" \
		--hostname="${trafficvault}.infra.ciab.test" \
		--name="$trafficvault" \
		--publish=8087:8087 \
		--rm \
		"$trafficvault" \
		/usr/lib/riak/riak-cluster.sh;
	docker logs -f "$trafficvault" 2>&1 |
		color_and_prefix "$gray_bg" 'Traffic Vault';
}
start_traffic_vault &

lsb_release
sudo apt-get install -y --no-install-recommends gettext \
	ruby ruby-dev \
	libc-dev curl openjdk-11-jdk-headless \
	chromium-browser chromium-chromedriver \
	postgresql-client \
	gcc musl-dev

sudo npm i -g protractor@^7.0.0 forever bower grunt selenium-webdriver
sudo npm i -g webdriver-manager --force
sudo gem update --system && sudo gem install sass compass
sudo webdriver-manager update

GOROOT=/usr/local/go
export GOPATH PATH="${PATH}:${GOROOT}/bin"
download_go
export GOPATH="$(mktemp -d)"
SRCDIR="$GOPATH/src/github.com/apache"
mkdir -p "$SRCDIR"
ln -s "$PWD" "$SRCDIR/trafficcontrol"

cd "$SRCDIR/trafficcontrol/traffic_ops/traffic_ops_golang"

/usr/local/go/bin/go get -v golang.org/x/net/publicsuffix\
	golang.org/x/crypto/ed25519 \
	golang.org/x/crypto/scrypt \
	golang.org/x/net/idna \
	golang.org/x/net/ipv4 \
	golang.org/x/net/ipv6 \
	golang.org/x/sys/unix \
	golang.org/x/text/secure/bidirule > /dev/null
/usr/local/go/bin/go build . > /dev/null

echo "
-----BEGIN CERTIFICATE-----
MIIDtTCCAp2gAwIBAgIJAJgQuE9T48+gMA0GCSqGSIb3DQEBBQUAMEUxCzAJBgNV
BAYTAkFVMRMwEQYDVQQIEwpTb21lLVN0YXRlMSEwHwYDVQQKExhJbnRlcm5ldCBX
aWRnaXRzIFB0eSBMdGQwHhcNMTcwNTA5MDIyNTI0WhcNMTgwNTA5MDIyNTI0WjBF
MQswCQYDVQQGEwJBVTETMBEGA1UECBMKU29tZS1TdGF0ZTEhMB8GA1UEChMYSW50
ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
CgKCAQEA1OsuQ71qaSZ4ivGnh4YryeQEHMn5wZLX7kWYB637ssyOJnkU1ZGs93JM
XJADzsjmssP6icSDhV2JPgDDYzx1eBJt6y3vHI7L3AdGfQJj+4FFABKR8moqpc1J
WIMGnPzO6DeEc8irf0qxSh+yvuFX0j6oS8oCqiRxz5+HL2wEGWmrgr37JY4/bs7o
4CMY19Ru1dP2Fr292HEIqCEnLTOuaHSWAEWx1Tm93kT9sXbw/SG2JTLQSX80biFL
7foJeoGWLls2reTCYTprzWFaMu3x9I8HLtf4VIN44rtvo5N20KYgjGqvPjFGPljL
yrgB8rXSCpH3M4AbazxD8fZKbdORawIDAQABo4GnMIGkMB0GA1UdDgQWBBT6zEpf
DYbYCI3Bu82+Q5SmI+/7ojB1BgNVHSMEbjBsgBT6zEpfDYbYCI3Bu82+Q5SmI+/7
oqFJpEcwRTELMAkGA1UEBhMCQVUxEzARBgNVBAgTClNvbWUtU3RhdGUxITAfBgNV
BAoTGEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZIIJAJgQuE9T48+gMAwGA1UdEwQF
MAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAGLs1NcYNtUgN6FuMb6/UskEWLTKwfno
NBtNdIbcZP3HmJHwruLWCeqj6HIWJC87EqmPTIYPdem3SAN1L20fWpzm7AB7av+2
wTCAPVP0punF/IouSb6fyo8fdG1a104Mge4iy/Sf2uf09NEv08sfVdB4P0tKRRlg
5KChhmspdPP7fmPXyghm4IC0Seknmh6IlVOnALXLU5OoCLHTie5Hjv4Tm8Xu0oBA
dIH/cPu2/w5SAIVq9CtcsdglS0ZsCAv4W2YieuSLPf5xuI0q/5lFZGNoDpIWJldx
Y2IpnoNCrHEAxijP5ctPawsxkSt2PmQ5uNNL7TbMudc3hZzOpTPkGoo=
-----END CERTIFICATE-----
" > localhost.crt

echo "-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEA1OsuQ71qaSZ4ivGnh4YryeQEHMn5wZLX7kWYB637ssyOJnkU
1ZGs93JMXJADzsjmssP6icSDhV2JPgDDYzx1eBJt6y3vHI7L3AdGfQJj+4FFABKR
8moqpc1JWIMGnPzO6DeEc8irf0qxSh+yvuFX0j6oS8oCqiRxz5+HL2wEGWmrgr37
JY4/bs7o4CMY19Ru1dP2Fr292HEIqCEnLTOuaHSWAEWx1Tm93kT9sXbw/SG2JTLQ
SX80biFL7foJeoGWLls2reTCYTprzWFaMu3x9I8HLtf4VIN44rtvo5N20KYgjGqv
PjFGPljLyrgB8rXSCpH3M4AbazxD8fZKbdORawIDAQABAoIBAQCYOINc/qCDCHQJ
sfa511ya/B9MjcG3eMpTmQG2C9b033WJX+tbPMjSJ68cRgHS5qK4j5AgypPU1yh1
YYpO+jxpWZOoHbDjU9u/NJxaZ0kf2C2CfcRF8U0IOJoFY7doqP0r2/Uf6glh+f6C
JeNewDBPKWictpHtHh0X+M9nQew0VZ7slXnV+IwUxiWYEtiIjwMyzSmfDEnN3ix5
fuVQLvVaq+bbqXj2rMpJWFj7zMsG5HRePQl2kQGtMYLCIalnJIQs5jQn2YsliNyy
fQiwWnU0wkrLlmkhlivlISRDtP35WQgF8ObsoQ3LZXRflB0C7U7zEl7Dj3Vi7WXr
jsRZC4dxAoGBAPwuPdtc9gSNKjn8RnqfEJjdSo1qdLbGvRcSJNy4/kEEFECJXkeO
mV/aklCi39cxAaIjVdTQ1XN67RMxgdekCI2Eg8h4RdvwgB/tAO+C3ExzMSOA1IcZ
tWuwIA2YnaFF9Sla9iJqxgtoGlaqm4VTUM/IdZqlzsP08pfNq7bXPsr9AoGBANgk
tkovf1Y0O4lBHX3eVLnHXForxEZh8bGHwuJJWWzb0ZFcXrrSd8FSycZrR28v4sdQ
WSSVPz3Op95HoTVXVL9EJcZ+MTnHaoCHbYBkrGTlGviu5Fl2V5EbrN7R7CdxJeem
HOU4shTy1acMPgf8sT17ykkXhVeUhSK2Jg6fZn6HAoGAI4/51SeE4htuKwMyhTRN
SOFcFBlBIE1ieRBr9lx4Ln7+xCMbEog/hM7z9z8gxd35Vv4YqoxQrZpWOHCw2NIf
CqX3V5vubhe6WcY4bY5MttM/yLvwPKUZeng57PDqucV9zzkuoKfiCdXCcRpaGDEp
okOooghj4ip204WDg6NTDZkCgYEAwZTfzsGLgmF1kRBIoZqmt1zeUcQxHfhKx32Y
BaM7/EtD/rSEAz7NEtBa9uLOL77rlSdZL3KcGXck0efFckitFkCqtIQBAoaf1E12
vS9tV0/6QBAjZByhgM0Qnt/Uad7k2/vilUmZ9TkoMVy9kdm3xCFCowP14OKb+uK4
YxBQc7ECgYEAm7eVtNlPHYmC54FU2bLucryNMLmu9I8O6zvbK5sxiMdtlh7OjaUB
RQS5iVc0iTacDZTGh7eqNzgGplj76pWGHeZUy0xIj/ZIRu2qOy0v+ffqfX1wCz7p
A22D22wvfs7CE3cUz/8UnvLM3kbTTu1WbbBbrHjAV47sAHjW/ckTqeo=
-----END RSA PRIVATE KEY-----
" > localhost.key

resources="$(dirname "$0")"
envsubst <"${resources}/cdn.json" >cdn.conf
cp "${resources}/database.json" database.conf

export $(<"${ciab_dir}/variables.env" sed '/^#/d') # defines TV_ADMIN_USER/PASSWORD
envsubst <"${resources}/riak.json" >riak.conf

truncate --size=0 warning.log error.log # Removes output from previous API versions and makes sure files exist
./traffic_ops_golang --cfg ./cdn.conf --dbcfg ./database.conf -riakcfg riak.conf &
tail -f warning.log 2>&1 | color_and_prefix "${yellow_bg}" 'Traffic Ops' &
tail -f error.log 2>&1 | color_and_prefix "${red_bg}" 'Traffic Ops' &

cd "../../traffic_portal"
sudo npm i --save-dev
sudo bower install --allow-root
sudo grunt dist

sudo webdriver-manager start &

fqdn="http://localhost:4444/wd/hub/status"
while ! curl -Lvsk "${fqdn}" >/dev/null 2>&1; do
  echo "waiting for selemnium server to start on '${fqdn}'"
  sleep 10
done

cp "${resources}/config.js" ./conf/
touch tp.log
touch access.log
sudo forever --minUptime 5000 --spinSleepTime 2000 -l ./tp.log start server.js &
tail -f tp.log &
tail -f access.log &

fqdn="https://localhost:8443/"
while ! curl -Lvsk "${fqdn}api/3.0/ping" >/dev/null 2>&1; do
  echo "waiting for TP/TO server to start on '${fqdn}'"
  sleep 10
done

psql --version
echo "insert into db"
psql -d postgresql://traffic_ops:twelve@postgres:5432/traffic_ops -c "INSERT INTO tm_user (username, local_passwd, role, tenant_id) VALUES ('admin', 'SCRYPT:16384:8:1:vVw4X6mhoEMQXVGB/ENaXJEcF4Hdq34t5N8lapIjDQEAS4hChfMJMzwwmHfXByqUtjmMemapOPsDQXG+BAX/hA==:vORiLhCm1EtEQJULvPFteKbAX2DgxanPhHdrYN8VzhZBNF81NRxxpo7ig720KcrjH1XFO6BUTDAYTSBGU9KO3Q==', 1, 1)"

sudo webdriver-manager update
cd "test/end_to_end"
cp "${resources}/conf.json" .
echo "starting tests"
protractor ./conf.js

exit $?
