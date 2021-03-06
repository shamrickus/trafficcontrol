package cfgfile

/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

import (
	"errors"

	"github.com/apache/trafficcontrol/lib/go-atscfg"
	"github.com/apache/trafficcontrol/traffic_ops/ort/atstccfg/config"
	"github.com/apache/trafficcontrol/traffic_ops/ort/atstccfg/toreq"
)

func GetConfigFileProfileLogsXMLDotConfig(cfg config.TCCfg, profileNameOrID string) (string, error) {
	profileName, err := toreq.GetProfileNameFromProfileNameOrID(cfg, profileNameOrID)
	if err != nil {
		return "", errors.New("getting profile name from '" + profileNameOrID + "': " + err.Error())
	}

	profileParameters, err := toreq.GetProfileParameters(cfg, profileName)
	if err != nil {
		return "", errors.New("getting profile '" + profileName + "' parameters: " + err.Error())
	}
	if len(profileParameters) == 0 {
		// The TO endpoint behind toclient.GetParametersByProfileName returns an empty object with a 200, if the Profile doesn't exist.
		// So we act as though we got a 404 if there are no params (and there should always be volume.config params), to make ORT behave correctly.
		return "", config.ErrNotFound
	}

	toToolName, toURL, err := toreq.GetTOToolNameAndURLFromTO(cfg)
	if err != nil {
		return "", errors.New("getting global parameters: " + err.Error())
	}

	paramData := map[string]string{}
	// TODO add configFile query param to profile/parameters endpoint, to only get needed data
	for _, param := range profileParameters {
		if param.ConfigFile != atscfg.LogsXMLFileName {
			continue
		}
		if param.Name == "location" {
			continue
		}
		paramData[param.Name] = param.Value
	}

	return atscfg.MakeLogsXMLDotConfig(profileName, paramData, toToolName, toURL), nil
}
