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
import { browser, by, element} from 'protractor'
import { BasePage } from './BasePage.po'
import { config } from "../config";

interface LoginData {
    password: string;
    username: string;
    validationMessage: string;
}

export class LoginPage extends BasePage{
    private txtUserName;
    private txtPassword;
    private btnLogin;
    private lnkResetPassword;
    private lblUserName;
    private randomize;
    
    public LoginPage() {
        console.log("LoginPage ctor beg");
        this.txtUserName = element(by.id("loginUsername"))
        this.txtPassword = element(by.id("loginPass"))
        this.btnLogin = element(by.name("loginSubmit"))
        this.lnkResetPassword= element (by.xpath("//button[text()='Reset Password']"))
        this.lblUserName = element(by.xpath("//span[@id='headerUsername']"))
        this.randomize = config.randomize;
        console.log("LoginPage ctor end");
    }
    
    
    async Login(login:LoginData){
        let result = false;
        const basePage = new BasePage();
        if(login.username === 'admin'){
            await this.txtUserName.sendKeys(login.username)
            await this.txtPassword.sendKeys(login.password)
            await browser.actions().mouseMove(this.btnLogin).perform();
            await browser.actions().click(this.btnLogin).perform();    
        }else{
            await this.txtUserName.sendKeys(login.username+this.randomize)
            await this.txtPassword.sendKeys(login.password)
            await browser.actions().mouseMove(this.btnLogin).perform();
            await browser.actions().click(this.btnLogin).perform();    
        }
        if(await browser.getCurrentUrl() === browser.params.baseUrl + "#!/login"){
            result = await basePage.GetOutputMessage().then(value => value === login.validationMessage);
        }else{
            result = true;
        }
        return result;
    }
    ClickResetPassword(){
        this.lnkResetPassword.click()
    }
    async CheckUserName(login) {
        if(await this.lblUserName.getText() === 'admin' || await this.lblUserName.getText() === login.username+this.randomize){
            return true;
        }else{
            return false;   
        }
    }
};
