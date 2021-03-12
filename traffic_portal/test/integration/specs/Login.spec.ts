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
import { browser } from 'protractor';
import { LoginPage } from '../PageObjects/LoginPage.po';
import  * as using  from "jasmine-data-provider";
import { readFileSync } from "fs"

const filename = 'Data/Login/TestCases.json';
const testData = JSON.parse(readFileSync(filename,'utf-8'));
const loginPage = new LoginPage();

describe("POC tests", function () {
    it("functionBind angular on deployed page", async function () {
        browser.get("https://shamrickus.github.io/d2runewords/");  
    });

    it('should ping', async function () {
        browser.waitForAngularEnabled(false);
        browser.get(browser.params.baseUrl + "/api/4.0/ping") ;
        browser.waitForAngularEnabled(true);
    });

    it('default dir', async function () {
        browser.waitForAngularEnabled(false);
        browser.get(browser.params.baseUrl);
        browser.getCurrentUrl().then(function (d){
            console.log(d);
        });
        
        browser.waitForAngularEnabled(true);
        browser.get(browser.params.baseUrl);
    });
})

using(testData.LoginTest, function(loginData){
    using(loginData.Login, function(login){
        describe('Traffic Portal - Login - '+ login.description, function(){
            it('can open login page', async function(){
                browser.get(browser.params.baseUrl);
            })
            it(login.description, async function(){
                expect(await loginPage.Login(login)).toBeTruthy();
            })
        })
    })
})
