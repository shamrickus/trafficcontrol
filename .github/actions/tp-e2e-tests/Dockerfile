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

FROM golang:1.14.2-alpine
RUN apk add --update --no-cache gettext git nodejs npm ruby ruby-dev build-base \
	libc-dev linux-headers curl openjdk11 openssl-dev postgresql-dev libxml2-dev \
	libxslt-dev iproute2 chromium chromium-chromedriver python3 python3-dev postgresql-client \
	gcc musl-dev

RUN npm i -g protractor@^7.0.0 forever bower grunt selenium-webdriver jasmine
RUN npm i -g webdriver-manager --force
RUN gem update --system && gem install sass compass
RUN go get -v bitbucket.org/liamstask/goose/cmd/goose
RUN webdriver-manager update

COPY entrypoint.sh database.json cdn.json conf.json config.js dbconf.yml /
RUN chmod a+x /entrypoint.sh

EXPOSE 8443 6443 8880 4444

ENTRYPOINT /entrypoint.sh
