import {promise} from "selenium-webdriver";

export class Log {
    static Log(): any {
        var log4js = require('log4js');
        log4js.configure('./log4js.json');
        return log4js.getLogger('default');
    }
    
    static Debug(prepend: string,  dbg: promise.Promise<any>): void {
        let self = this;
        dbg.then(function (res) {
            self.Log().debug(prepend + res) 
        });
    }
}
