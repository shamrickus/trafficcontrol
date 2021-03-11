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
#set -o errexit -o nounset -o pipefail

fqdn="http://localhost:4444/wd/hub/status"
if ! curl -Lvsk "${fqdn}" >/dev/null 2>&1; then
  echo "Selenium not started on ${fqdn}"
  exit 1
fi

DIVISION="adivision"
REGION="aregion"
PHYS="aloc"
COORD="acoord"
CDN="zcdn"
CG="acg"
export PGUSER="traffic_ops"
export PGPASSWORD="twelve"
export PGHOST="localhost"
export PGDATABASE="traffic_ops"
export PGPORT="5432"

<<QUERY psql
INSERT INTO tm_user (username, role, tenant_id, local_passwd)
  VALUES ('admin', 1, 1,
    'SCRYPT:16384:8:1:vVw4X6mhoEMQXVGB/ENaXJEcF4Hdq34t5N8lapIjDQEAS4hChfMJMzwwmHfXByqUtjmMemapOPsDQXG+BAX/hA==:vORiLhCm1EtEQJULvPFteKbAX2DgxanPhHdrYN8VzhZBNF81NRxxpo7ig720KcrjH1XFO6BUTDAYTSBGU9KO3Q=='
  );
INSERT INTO division(name) VALUES('${DIVISION}');
INSERT INTO region(name, division) VALUES('${REGION}', 1);
INSERT INTO phys_location(name, short_name, region, address, city, state, zip)
  VALUES('${PHYS}', '${PHYS}', 1, 'some place idk', 'Denver', 'CO', '88888');
INSERT INTO coordinate(name) VALUES('${COORD}');
INSERT INTO cdn(name, domain_name) VALUES('${CDN}', 'infra.ciab.test');

WITH TYPE AS (SELECT id FROM type WHERE name = 'TC_LOC')
INSERT INTO cachegroup(name, short_name, type, coordinate)
SELECT '${CG}', '${CG}', TYPE.id, 1
FROM TYPE;

WITH TYPE AS (SELECT id FROM type WHERE name = 'RIAK'),
PROFILE AS (SELECT id FROM profile WHERE name = 'RIAK_ALL'),
STATUS AS (SELECT id FROM status WHERE name = 'ONLINE'),
PHYS AS (SELECT id FROM phys_location WHERE name = '${PHYS}'),
CDN AS (SELECT id FROM cdn WHERE name = '${CDN}'),
CG AS (SELECT id from cachegroup WHERE name = '${CG}')
INSERT INTO server(host_name, domain_name, cachegroup, type, status, profile, phys_location, cdn_id)
SELECT 'trafficvault', 'infra.ciab.test', CG.ID, TYPE.id, STATUS.id, PROFILE.id, PHYS.id, CDN.id
FROM TYPE
JOIN STATUS ON 1=1
JOIN PROFILE ON 1=1
JOIN PHYS ON 1=1
JOIN CDN ON 1=1
JOIN CG ON 1=1;
QUERY

sudo useradd trafops

download_go() {
	. build/functions.sh
	if verify_and_set_go_version; then
		return
	fi
	go_version="$(cat "${GITHUB_WORKSPACE}/GO_VERSION")"
	wget -O go.tar.gz "https://dl.google.com/go/go${go_version}.linux-amd64.tar.gz" --no-verbose 
	echo "Extracting Go ${go_version}..."
	<<-'SUDO_COMMANDS' sudo sh
		set -o errexit
    go_dir="$(command -v go | xargs realpath | xargs dirname | xargs dirname)"
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
}
#start_traffic_vault &

sudo apt-get install -y --no-install-recommends gettext \
	ruby ruby-dev libc-dev curl \
	gcc musl-dev

sudo gem update --system && sudo gem install sass compass > /dev/null
sudo npm i -g forever bower grunt 

GOROOT=/usr/local/go
export PATH="${PATH}:${GOROOT}/bin"
download_go
export GOPATH="${HOME}/go"
readonly ORG_DIR="$GOPATH/src/github.com/apache"
readonly REPO_DIR="${ORG_DIR}/trafficcontrol"
if [[ ! -e "$REPO_DIR" ]]; then
	mkdir -p "$ORG_DIR"
	cd
	mv "${GITHUB_WORKSPACE}" "${REPO_DIR}/"
	ln -s "$REPO_DIR" "${GITHUB_WORKSPACE}"
fi

cd "${REPO_DIR}/traffic_ops/traffic_ops_golang"
go mod vendor -v > /dev/null
go build . > /dev/null

openssl req -new -x509 -nodes -newkey rsa:4096 -out localhost.crt -keyout localhost.key -subj "/CN=tptests";

resources="$(dirname "$0")"
envsubst <"${resources}/cdn.json" >cdn.conf
cp "${resources}/database.json" database.conf

export $(<"${ciab_dir}/variables.env" sed '/^#/d') # defines TV_ADMIN_USER/PASSWORD
envsubst <"${resources}/riak.json" >riak.conf

truncate --size=0 warning.log error.log event.log # Removes output from previous API versions and makes sure files exist
./traffic_ops_golang --cfg ./cdn.conf --dbcfg ./database.conf -riakcfg riak.conf &
tail -f warning.log 2>&1 | color_and_prefix "${yellow_bg}" 'Traffic Ops' &
tail -f error.log 2>&1 | color_and_prefix "${red_bg}" 'Traffic Ops' &
tail -f event.log 2>&1 | color_and_prefix "${gray_bg}" 'Traffic Ops' &

cd "../../traffic_portal"
npm ci > /dev/null
bower install > /dev/null
grunt dist > /dev/null

cp "${resources}/config.js" ./conf/
touch tp.log access.log
sudo forever --minUptime 5000 --spinSleepTime 2000 -l ./tp.log start server.js

to_fqdn="https://localhost:6443"
tp_fqdn="https://localhost:8443"


while ! curl -Lvsk "${tp_fqdn}/api/4.0/ping" >/dev/null 2>&1; do
  echo "waiting for TP/TO server to start on '${tp_fqdn}'"
  sleep 10
done 

#timeout 30s bash <<WAIT
#  while ! curl -Lvsk "${tp_fqdn}" >/dev/null 2>&1; do
#    echo "waiting for TP/TO server to start on '${tp_fqdn}'"
#    sleep 10
#  done 
#WAIT
#if [ $? -ne 0 ]; then
#  exit 1
#fi
cd "test/integration"


CHROME_CONTAINER=$(docker ps | grep "selenium/node-chrome" | awk '{print $1}')
HUB_CONTAINER=$(docker ps | grep "selenium/hub" | awk '{print $1}')
CHROME_VER=$(docker exec "$CHROME_CONTAINER" google-chrome --version | sed -E 's/.* ([0-9.]+).*/\1/')

jq "del(.dependencies.chromedriver) | del(.dependencies.seleniumAddress)" package.json > package.json.tmp && mv package.json.tmp package.json
npm i --save-dev

PATH=$(pwd)/node_modules/.bin/:$PATH


#chromedriver_bin=$(./node_modules/.bin/chromedriver -v | awk '{print $2}')
#
#./node_modules/.bin/webdriver-manager update --gecko false --version $chromedriver_bin
#./node_modules/.bin/webdriver-manager start --detach
#while ! curl -Lvsk "${fqdn}/api/4.0/ping" >/dev/null 2>&1; do
#  echo "Selenium not started on ${fqdn}"
#  sleep 10
#done 

#remove
cp ${resources}/config.json .

    #\"--disable-gpu\",
jq " .capabilities.chromeOptions.args = [
    \"--headless\",
    \"--no-sandbox\",
    \"--ignore-certificate-errors\"
  ] | del(.capabilities.chromeOptions.prefs.download)" \
  config.json > config.json.tmp && mv config.json.tmp config.json

onFail() {
	docker logs "$trafficvault" 2>&1 |
		color_and_prefix "$gray_bg" 'Traffic Vault';
  cat tp.log | color_and_prefix "${gray_bg}" 'Forever'
  cat access.log | color_and_prefix "${gray_bg}" 'Traffic Portal'
  exit 1
}

netstat -lntup


tsc
protractor ./GeneratedCode/config.js --params.baseUrl="${tp_fqdn}" --params.apiUrl="${to_fqdn}/api/4.0" #|| onFail
c=$?

echo "Chrome logs"
docker logs $CHROME_CONTAINER

echo "Hub logs"
docker logs $HUB_CONTAINER

echo "TP site"
wget --no-check-certificate $tp_fqdn

echo "TP Log"
cat ../../tp.log 
echo "access Log"
cat ../../access.log

exit $c

